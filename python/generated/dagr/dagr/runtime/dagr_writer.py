"""Dagr reflective wire runtime — writer (pure Python, Phase 2).

The **encode** side of the wire primitives + the full **backward-growing Builder** — a
faithful port of the TS `dagr_writer.ts` / Swift `DataArenaBuilder` reference. Every
``store*`` appends a chunk and returns the cursor (total bytes stored so far);
``make_data`` concatenates the chunks in REVERSE order (each chunk's internal byte order
preserved), because the reference builder writes from the far end of the buffer downward.
A "buffer offset" is the cursor value at store time; the forward distance between two
stored things in the final buffer is ``cursor_now - offset``.

Chunks are ``bytearray`` (mutable) so cycle late-bindings can patch a placeholder in
place. Shared/cyclic node dedup keys on ``id(node)`` (Python object identity — globally
unique, so unlike the Mojo port there is no type-namespacing caveat).

Gate: ``serialize(restore(fixture))`` must equal the fixture byte-for-byte (Phase 2).
"""

import struct as _struct


# ── LEB128 / ZigZag ──────────────────────────────────────────────────────────

def encode_leb(value):
    """Unsigned LEB128 → ``bytes``. ``value`` must be >= 0."""
    if value < 0:
        raise ValueError("encode_leb requires a non-negative value")
    out = bytearray()
    while True:
        b = value & 0x7F
        value >>= 7
        if value:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def leb_length(value):
    """LEB byte length of a non-negative value (value <= 0 → 1)."""
    if value <= 0:
        return 1
    n = 0
    while value > 0:
        n += 1
        value >>= 7
    return n


def zigzag_encode(n):
    """Signed → ZigZag (width-agnostic; exact for arbitrary Python ints)."""
    return (n << 1) if n >= 0 else (((~n) << 1) | 1)


def encode_zigzag_leb(n):
    """Signed LEB128 (ZigZag)."""
    return encode_leb(zigzag_encode(n))


def neg_zigzag(v):
    """"Negative" zig-zag used for the vtable size marker: v==0 ? 0 : (v-1)<<1|1."""
    return 0 if v == 0 else (((v - 1) << 1) | 1)


# ── V62 bidirectional pointer ────────────────────────────────────────────────

def encode_v62(value):
    """V62 pointer → ``bytes`` (the minimal width that fits). Low 2 bits encode the
    width (0→1B, 1→2B, 2→4B, 3→8B); the payload is ``value`` shifted up by 2."""
    if value < 0:
        raise ValueError("encode_v62 requires a non-negative value")
    if (value << 2) <= 0xFF:
        return bytes([(value << 2) & 0xFF])
    if ((value << 2) | 1) <= 0xFFFF:
        return ((value << 2) | 1).to_bytes(2, "little")
    if ((value << 2) | 2) <= 0xFFFFFFFF:
        return ((value << 2) | 2).to_bytes(4, "little")
    return ((value << 2) | 3).to_bytes(8, "little")


def encode_zigzag_v62(n):
    """Signed (ZigZag) V62 pointer."""
    return encode_v62(zigzag_encode(n))


# ── Float bit helpers ────────────────────────────────────────────────────────

def f32_bits(v):
    """f32 bit pattern of a Python float."""
    return _struct.unpack("<I", _struct.pack("<f", v))[0]


def f64_bits(v):
    return _struct.unpack("<Q", _struct.pack("<d", v))[0]


def f32_to_bf16_bits(v):
    """f32 → bf16 bits: round-to-nearest-even on the top 16 bits."""
    bits = f32_bits(v)
    lsb = (bits >> 16) & 1
    return ((bits + 0x7FFF + lsb) >> 16) & 0xFFFF


def f32_to_f16_bits(v):
    """f32 → f16 bits: IEEE-754 round-to-nearest-even with subnormals."""
    import math
    if math.isnan(v):
        return 0x7E00
    bits = f32_bits(v)
    sign = (bits >> 16) & 0x8000
    exp32 = (bits >> 23) & 0xFF
    mant32 = bits & 0x7FFFFF
    if exp32 == 0xFF:
        return sign | 0x7C00                       # infinity (NaN handled)
    if (bits & 0x7FFFFFFF) == 0:
        return sign                                # +/-0
    exp16 = exp32 - 127 + 15
    if exp16 >= 0x1F:
        return sign | 0x7C00
    if exp16 <= 0:
        if exp16 < -10:
            return sign
        m = mant32 | 0x800000
        shift = 14 - exp16
        low = m & ((1 << shift) - 1)
        half = 1 << (shift - 1)
        r = m >> shift
        if low > half or (low == half and (r & 1) == 1):
            r += 1
        return (sign | r) & 0xFFFF
    half16 = (exp16 << 10) | (mant32 >> 13)
    round_ = (mant32 >> 12) & 1
    sticky = (mant32 & 0xFFF) != 0
    if round_ == 1 and (sticky or (half16 & 1) == 1):
        half16 += 1
    return (sign | half16) & 0xFFFF


def f32_to_f16_bits_exact(v):
    """f32 → f16 bits ONLY if exactly representable (else None)."""
    bits = f32_bits(v)
    sign = bits >> 31
    exp32 = (bits >> 23) & 0xFF
    mant32 = bits & 0x7FFFFF
    if exp32 == 0xFF:
        return None                                # nan/inf
    if exp32 == 0:
        return (sign << 15) if mant32 == 0 else None   # ±0 / subnormal
    exp16 = exp32 - 112
    if exp16 < 1 or exp16 > 30:
        return None                                # out of f16 range
    if (mant32 & 0x1FFF) != 0:
        return None                                # precision loss
    return ((sign << 15) | (exp16 << 10) | (mant32 >> 13)) & 0xFFFF


def _fround(v):
    """JS Math.fround: round a double to the nearest f32 value. Beyond f32's range that
    is ±infinity (as in JS, Swift, Rust and Go) — `struct.pack` raises instead, which
    crashed the packed f64 writer on any |v| > ~3.4e38 before this."""
    try:
        return _struct.unpack("<f", _struct.pack("<f", v))[0]
    except OverflowError:
        return float("inf") if v > 0 else float("-inf")


def _is_pos_zero(v):
    import math
    return v == 0.0 and math.copysign(1.0, v) == 1.0


def _is_neg_zero(v):
    import math
    return v == 0.0 and math.copysign(1.0, v) == -1.0


# ── Fixed-width scalar encoders (native LE) — standalone helpers ──────────────

_FIXED = {
    "u8": "<B", "u16": "<H", "u32": "<I", "u64": "<Q",
    "i8": "<b", "i16": "<h", "i32": "<i", "i64": "<q",
    "f32": "<f", "f64": "<d", "f16": "<e",
}


def encode_fixed(kind, value):
    """Encode a fixed-width native-LE scalar (`u8`..`u64`, `i8`..`i64`, `f16/f32/f64`)."""
    if kind == "bf16":
        return f32_to_bf16_bits(value).to_bytes(2, "little")
    if kind == "bool":
        return bytes([1 if value else 0])
    return _struct.pack(_FIXED[kind], value)


# ── Node-store ref (mirrors the TS { off } / { pending } union) ───────────────
#
# A resolved store → {"off": n}; an in-flight ancestor (a cycle) → {"pending": id}.

def node_offset(r):
    """Unwrap a resolved offset; raise if still pending (a context with no late-binding)."""
    if "off" not in r:
        raise ValueError("cyclic reference in a context without late-binding support")
    return r["off"]


class Builder:
    """Backward-growing builder — a faithful port of `dagr_writer.ts`'s `Builder`."""

    def __init__(self, max_size=2 * 1024 * 1024):
        # Reserved bidir-pointer / cyclic-array-element placeholder width, derived from the max
        # buffer size EXACTLY like Rust/Swift (`with_max_size`): bits = bitlen(max_size)+3;
        # width = nextPow2(ceil(bits/8)). maxSize 2 MiB → 4 B (V62 code 2); maxSize 1024 → 2 B (code 1).
        _bits = max_size.bit_length() + 3
        _nbytes = (_bits >> 3) + (1 if _bits & 7 else 0)
        self.reserve_field_pointer_size = 1 << (_nbytes - 1).bit_length()
        self.chunks = []              # list[bytearray], concatenated in REVERSE at the end
        self.cursor = 0
        self._vt_lookup = {}          # norm-vector key → header offset (vtable dedup)
        self._string_lookup = {}      # string → content offset (utf8 dedup)
        self.struct_lookup = {}       # id(node) → offset (shared/cyclic node dedup)
        self._in_progress = set()     # id(node) currently being stored (cycle detect)
        self._late_bindings = {}      # id(node) → list of pending patch records

    # ── core ─────────────────────────────────────────────────────────────────
    def _push(self, data):
        chunk = data if isinstance(data, bytearray) else bytearray(data)
        self.chunks.append(chunk)
        self.cursor += len(chunk)
        return self.cursor

    def store_bytes(self, data):
        """Inline raw bytes, forward order."""
        return self._push(data)

    def store_u8(self, v):
        return self._push([v & 0xFF])

    def store_u16(self, v):
        return self._push((v & 0xFFFF).to_bytes(2, "little"))

    def store_u32(self, v):
        return self._push((v & 0xFFFFFFFF).to_bytes(4, "little"))

    def store_u64(self, v):
        return self._push((v & 0xFFFFFFFFFFFFFFFF).to_bytes(8, "little"))

    def store_i8(self, v):
        return self.store_u8(v & 0xFF)

    def store_i16(self, v):
        return self.store_u16(v & 0xFFFF)

    def store_i32(self, v):
        return self.store_u32(v & 0xFFFFFFFF)

    def store_i64(self, v):
        return self.store_u64(v & 0xFFFFFFFFFFFFFFFF)

    def store_f32(self, v):
        return self._push(_struct.pack("<f", v))

    def store_f64(self, v):
        return self._push(_struct.pack("<d", v))

    def store_f16(self, v):
        return self.store_u16(f32_to_f16_bits(v))

    def store_bf16(self, v):
        return self.store_u16(f32_to_bf16_bits(v))

    def store_leb(self, value):
        """LEB128, low 7 bits first (value <= 0 → single 0x00)."""
        if value <= 0:
            return self._push([0])
        out = bytearray()
        while value > 0:
            b = value & 0x7F
            value >>= 7
            out.append(b | 0x80 if value > 0 else b)
        return self._push(out)

    def store_v62(self, value, min_code=0):
        """V62 fixed-width pointer: value<<2 | widthCode, width by magnitude."""
        if value < (1 << 6) and min_code == 0:
            return self.store_u8((value << 2) | 0)
        if value < (1 << 14) and min_code <= 1:
            return self.store_u16((value << 2) | max(1, min_code))
        if value < (1 << 30) and min_code <= 2:
            return self.store_u32((value << 2) | max(2, min_code))
        if value < (1 << 62):
            return self.store_u64((value << 2) | max(3, min_code))
        raise ValueError(f"cantStoreValueAsV62({value})")

    def store_forward_pointer(self, offset):
        """Forward pointer to a previously stored offset: V62(cursor - offset)."""
        return self.store_v62(self.cursor - offset)

    # ── width-code helpers ────────────────────────────────────────────────────
    @staticmethod
    def _offset_width_code(v):
        if v <= 0xFF:
            return 0
        if v <= 0xFFFF:
            return 1
        if v <= 0xFFFFFFFF:
            return 2
        return 3

    @staticmethod
    def _signed_width_code(d):
        if -128 <= d <= 127:
            return 0
        if -32768 <= d <= 32767:
            return 1
        if -2147483648 <= d <= 2147483647:
            return 2
        return 3

    def _store_uint_wc(self, v, wc):
        return (self.store_u8, self.store_u16, self.store_u32, self.store_u64)[wc](v)

    def _store_int_wc(self, v, wc):
        return (self.store_i8, self.store_i16, self.store_i32, self.store_i64)[wc](v)

    # ── packed self-describing floats (sub-tag scheme) ────────────────────────
    def store_packed_float32(self, v, elem):
        """Returns True iff the RAW fallback was used (packed-scalar field/enc bit)."""
        import math
        if _is_pos_zero(v):
            self.store_u8(0x00); return False
        if _is_neg_zero(v):
            self.store_u8(0x01); return False
        if math.isnan(v):
            self.store_u8(0x04); return False
        if not math.isfinite(v):
            self.store_u8(0x03 if v < 0 else 0x02); return False
        if v == int(v) and abs(v) < (1 << 21):
            zz = zigzag_encode(int(v))
            if leb_length(zz) <= 3:
                self.store_leb(zz); self.store_u8(0x05); return False
        f16 = f32_to_f16_bits_exact(v)
        if f16 is not None:
            self.store_u16(f16); self.store_u8(0x06); return False
        self.store_f32(v)
        if elem:
            self.store_u8(0x07)
        return True

    def store_packed_float64(self, v, elem):
        import math
        if _is_pos_zero(v):
            self.store_u8(0x00); return False
        if _is_neg_zero(v):
            self.store_u8(0x01); return False
        if math.isnan(v):
            self.store_u8(0x04); return False
        if not math.isfinite(v):
            self.store_u8(0x03 if v < 0 else 0x02); return False
        if v == int(v) and abs(v) < 2 ** 48:
            zz = zigzag_encode(int(v))
            if leb_length(zz) <= 7:
                self.store_leb(zz); self.store_u8(0x05); return False
        f32 = _fround(v)
        if f32 == v:
            f16 = f32_to_f16_bits_exact(f32)
            if f16 is not None:
                self.store_u16(f16); self.store_u8(0x06); return False
            self.store_f32(f32); self.store_u8(0x07); return False
        self.store_f64(v)
        if elem:
            self.store_u8(0x08)
        return True

    def store_packed_f16_scalar(self, v, is_bf16):
        """Packed f16/bf16 scalar: special → 1-byte tag (False), else raw 2-byte (True)."""
        import math
        if _is_pos_zero(v):
            self.store_u8(0x00); return False
        if _is_neg_zero(v):
            self.store_u8(0x01); return False
        if math.isnan(v):
            self.store_u8(0x04); return False
        if not math.isfinite(v):
            self.store_u8(0x03 if v < 0 else 0x02); return False
        self.store_u16(f32_to_bf16_bits(v) if is_bf16 else f32_to_f16_bits(v))
        return True

    # ── utf8 / data content ───────────────────────────────────────────────────
    def store_utf8(self, s, dedup):
        """Length-prefixed utf8 content: [LEB byteCount][utf8 bytes]. Returns the
        content offset (the count-LEB position)."""
        if dedup:
            hit = self._string_lookup.get(s)
            if hit is not None:
                return hit
        b = s.encode("utf-8")
        self.store_bytes(b)
        off = self.store_leb(len(b))
        if dedup:
            self._string_lookup[s] = off
        return off

    def store_data(self, b):
        """Length-prefixed data: [LEB count][bytes]. No dedup."""
        self.store_bytes(b)
        return self.store_leb(len(b))

    # ── vtable (regular nodes) ────────────────────────────────────────────────
    def store_vtable(self, entries):
        """Store a vtable. ``entries`` are field value offsets in FORWARD index order
        (None = absent). Returns the node offset (the vtable-pointer LEB). Dedups."""
        norm = [0 if off is None else self.cursor - off + 1 for off in entries]
        over = next((n for n in norm if n > 0xFFFF), None)
        if over is not None:
            raise ValueError(
                f"vtable entry overflow: field slot {over} bytes before the node header "
                f"exceeds the UInt16 wire limit (65535).")
        is16 = any(n > 0xFF for n in norm)
        key = ("w:" if is16 else "") + ",".join(str(n) for n in norm)
        hit = self._vt_lookup.get(key)
        if hit is not None:
            # Dedup: fresh vtable stores ODD marker; forward-ref stores EVEN ((dist)<<1).
            return self.store_leb((self.cursor - hit) << 1)
        if is16:
            cnt = (len(entries) << 1) | 1
            sz = leb_length(cnt) + len(entries) * 2
            result = self.store_leb(neg_zigzag(sz))
            for n in reversed(norm):
                self.store_u16(n)
            self._vt_lookup[key] = self.store_leb(cnt)
        else:
            cnt = len(entries) << 1
            sz = 0 if cnt == 0 else leb_length(cnt) + len(entries)
            result = self.store_leb(0 if sz == 0 else neg_zigzag(sz))
            for n in reversed(norm):
                self.store_u8(n)
            self._vt_lookup[key] = self.store_leb(cnt)
        return result

    # ── cycle late-binding (mirrors Rust in_progress / late_bindings) ─────────
    def begin_storing(self, node):
        """Begin storing a node (keyed on id). Returns a resolved ref (cached offset
        or a {pending} marker for an in-flight ancestor), or None to store fresh."""
        key = id(node)
        off = self.struct_lookup.get(key)
        if off is not None:
            return {"off": off}
        if key in self._in_progress:
            return {"pending": key}
        self._in_progress.add(key)
        return None

    def finish_storing(self, node, offset):
        """Finish storing a node: patch every placeholder recorded against it, then
        cache the offset."""
        key = id(node)
        self._in_progress.discard(key)
        binds = self._late_bindings.pop(key, None)
        if binds:
            for bd in binds:
                chunk, es = bd["chunk"], bd["es"]
                if bd["array_end"] >= 0:
                    rel = bd["array_end"] - offset + 1     # raw fixed-width signed dist
                    x = rel & ((1 << (es * 8)) - 1)
                    for i in range(es):
                        chunk[i] = x & 0xFF
                        x >>= 8
                else:
                    encoded = zigzag_encode(bd["base"] - offset)
                    wc = es.bit_length() - 1            # es bytes → V62 width code (4→2, 2→1)
                    v = (encoded << 2) | wc
                    for i in range(es):
                        chunk[i] = v & 0xFF
                        v >>= 8
        self.struct_lookup[key] = offset

    def _add_late_binding(self, key, bind):
        self._late_bindings.setdefault(key, []).append(bind)

    def store_bidirectional_pointer(self, ref):
        """Bidir (signed) pointer to a node ref. Resolved → V62(zigzag(cursor-off)).
        Pending → reserve a 4-byte placeholder, patched in finish_storing."""
        if "off" in ref:
            return self.store_v62(zigzag_encode(self.cursor - ref["off"]))
        base = self.cursor
        chunk = bytearray(self.reserve_field_pointer_size)
        self._push(chunk)
        self._add_late_binding(ref["pending"], {
            "chunk": chunk, "base": base, "array_end": -1,
            "es": self.reserve_field_pointer_size})
        return self.cursor

    # ── regular/frozen arrays (forward-pointer blocks) ───────────────────────
    @staticmethod
    def _nil_bits(elems):
        """Nil bitset indexed by element i (bit set = absent)."""
        bs = bytearray((len(elems) + 7) // 8)
        for i, e in enumerate(elems):
            if e is None:
                bs[i >> 3] |= 1 << (i & 7)
        return bs

    def store_fixed_array(self, elems, each):
        """[LEB count][elem0..N-1] LE. Elements stored reversed (backward builder)."""
        for v in reversed(elems):
            each(self, v)
        return self.store_leb(len(elems))

    def store_opt_fixed_array(self, elems, width, each):
        """Numeric awo (uncompacted): [LEB count][nil bitset][N fixed slots] — absent
        elements store `width` zero bytes, nil bit set."""
        for v in reversed(elems):
            if v is None:
                self.store_bytes(bytes(width))
            else:
                each(self, v)
        self.store_bytes(self._nil_bits(elems))
        return self.store_leb(len(elems))

    def store_bool_array(self, elems):
        """[LEB count][bitset], bit i = elem i."""
        bs = bytearray((len(elems) + 7) // 8)
        for i, v in enumerate(elems):
            if v:
                bs[i >> 3] |= 1 << (i & 7)
        self.store_bytes(bs)
        return self.store_leb(len(elems))

    def store_opt_bool_array(self, elems):
        """Bool awo (uncompacted): [LEB count][nil bitset][value bitset], both by i."""
        nb = (len(elems) + 7) // 8
        val = bytearray(nb)
        nil = bytearray(nb)
        for i, v in enumerate(elems):
            if v is None:
                nil[i >> 3] |= 1 << (i & 7)
            elif v:
                val[i >> 3] |= 1 << (i & 7)
        self.store_bytes(val)
        self.store_bytes(nil)
        return self.store_leb(len(elems))

    def store_enum_bit_array(self, elems, bits):
        """Sub-byte enum array: [LEB count][packed bits], `bits` (1/2/4) per element."""
        per = 8 // bits
        mask = (1 << bits) - 1
        bs = bytearray((len(elems) * bits + 7) // 8)
        for i, v in enumerate(elems):
            bs[i // per] |= (v & mask) << ((i % per) * bits)
        self.store_bytes(bs)
        return self.store_leb(len(elems))

    def store_opt_enum_bit_array(self, elems, bits):
        """Sub-byte enum awo (uncompacted): [LEB count][nil bitset][value bitset]."""
        per = 8 // bits
        mask = (1 << bits) - 1
        nil = bytearray((len(elems) + 7) // 8)
        val = bytearray((len(elems) * bits + 7) // 8)
        for i, v in enumerate(elems):
            if v is None:
                nil[i >> 3] |= 1 << (i & 7)
            else:
                val[i // per] |= (v & mask) << ((i % per) * bits)
        self.store_bytes(val)
        self.store_bytes(nil)
        return self.store_leb(len(elems))

    def store_ptr_table_array(self, elems, store_elem, signed):
        """Pointer-table array (utf8/data/node-ref): store each element's content
        (reversed), then a [count×es] slot table (slot = dist cur-off+1, 0 = nil), then
        header (count<<2)|widthCode. `signed` → two's-complement slots (node refs)."""
        offs = [None if v is None else store_elem(self, v) for v in reversed(elems)]
        cur = self.cursor
        wc = 0
        for off in offs:
            if off is not None:
                d = cur - off + 1
                wc = max(wc, self._signed_width_code(d) if signed else self._offset_width_code(d))
        for off in offs:
            d = 0 if off is None else cur - off + 1
            if signed:
                self._store_int_wc(d, wc)
            else:
                self._store_uint_wc(d, wc)
        return self.store_leb((len(elems) << 2) | wc)

    def store_node_ref_array(self, elems, store_ref):
        """Node-ref array (signed two's-complement slots): store each element node
        (reversed), then a [count×es] slot table (0 = nil). A pending (cyclic) element
        gets a zero placeholder patched by finish_storing; any pending forces wc >= 2."""
        refs = [None if v is None else store_ref(self, v) for v in reversed(elems)]
        cur = self.cursor
        wc = 0
        has_pending = False
        for r in refs:
            if r is None:
                continue
            if "off" in r:
                wc = max(wc, self._signed_width_code(cur - r["off"] + 1))
            else:
                has_pending = True
        reserve_wc = self.reserve_field_pointer_size.bit_length() - 1   # 4B→code 2, 2B→code 1
        if has_pending and wc < reserve_wc:
            wc = reserve_wc
        es = (1, 2, 4, 8)[wc]
        for r in refs:
            if r is None:
                self._store_int_wc(0, wc)
            elif "off" in r:
                self._store_int_wc(cur - r["off"] + 1, wc)
            else:
                chunk = bytearray(es)
                self._push(chunk)
                self._add_late_binding(r["pending"], {
                    "chunk": chunk, "base": 0, "array_end": cur, "es": es})
        return self.store_leb((len(elems) << 2) | wc)

    # ── packed-node array bodies: [blockLen][count-tag][elems] (self-sizing) ──
    def store_packed_int_array(self, elems, width, to_leb, store_raw, raw=False):
        """Packed int array (width >= 2): count-tag (count<<2)|tag, tag 0 all-LEB /
        1 all-raw / 2 mixed (enc bitset). Per element LEB if smaller than raw, else raw.
        `raw=True` (a `>> raw` field, spec/39): no probe, every element W bytes, tag 1."""
        before = self.cursor
        if raw:
            for i in range(len(elems) - 1, -1, -1):
                store_raw(self, elems[i])
            self.store_leb((len(elems) << 2) | 1)
            return self.store_leb(self.cursor - before)
        enc = bytearray((len(elems) + 7) // 8)
        raw_count = 0
        for i in range(len(elems) - 1, -1, -1):
            lv = to_leb(elems[i])
            if leb_length(lv) < width:
                self.store_leb(lv)
            else:
                store_raw(self, elems[i])
                enc[i >> 3] |= 1 << (i & 7)
                raw_count += 1
        tag = 0
        if raw_count == len(elems) and len(elems) > 0:
            tag = 1
        elif raw_count > 0:
            tag = 2
            self.store_bytes(enc)
        self.store_leb((len(elems) << 2) | tag)
        return self.store_leb(self.cursor - before)

    def store_packed_byte_array(self, elems, store_raw):
        """Packed u8/i8 array: plain [count][raw bytes] (no count-tag)."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            store_raw(self, elems[i])
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_bool_array(self, elems):
        """Packed bool array: [count][bitset], wrapped in blockLen."""
        before = self.cursor
        bs = bytearray((len(elems) + 7) // 8)
        for i, v in enumerate(elems):
            if v:
                bs[i >> 3] |= 1 << (i & 7)
        self.store_bytes(bs)
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_enum_bit_array(self, elems, bits):
        """Packed sub-byte enum array: [blockLen][count][bitset]."""
        before = self.cursor
        per = 8 // bits
        mask = (1 << bits) - 1
        bs = bytearray((len(elems) * bits + 7) // 8)
        for i, v in enumerate(elems):
            bs[i // per] |= (v & mask) << ((i % per) * bits)
        self.store_bytes(bs)
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_enum_raw_array(self, elems):
        """Packed byte-aligned enum array: [blockLen][count][LEB(rawValue) per element]."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            self.store_leb(elems[i])
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_f16_array(self, elems, is_bf16):
        """Packed f16/bf16 array: [blockLen][count][enc bitset][elems]; enc bit 1 = raw
        2-byte, 0 = special-value tag."""
        before = self.cursor
        enc = bytearray((len(elems) + 7) // 8)
        for i in range(len(elems) - 1, -1, -1):
            if self.store_packed_f16_scalar(elems[i], is_bf16):
                enc[i >> 3] |= 1 << (i & 7)
        self.store_bytes(enc)
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_float_array(self, elems, is_f64, raw=False):
        """Packed float array: [blockLen][(count<<2)|mode][elems] — mode 0 self-describing,
        mode 1 (`>> raw` fields) raw native-LE."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if raw:
                self.store_f64(elems[i]) if is_f64 else self.store_f32(elems[i])
            elif is_f64:
                self.store_packed_float64(elems[i], True)
            else:
                self.store_packed_float32(elems[i], True)
        self.store_leb((len(elems) << 2) | (1 if raw else 0))
        return self.store_leb(self.cursor - before)

    def store_packed_node_array(self, elems, store_child, opt):
        """Packed node-ref element array: [count][opt nil bs][(blockLen+child block) per
        present]. Each child stored via `store_child` (its own inline packed block)."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if opt and elems[i] is None:
                continue
            store_child(self, elems[i])
        if opt:
            self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_complex_array(self, elems, store_elem, opt):
        """Packed utf8/data element array: plain [count][(LEB len+bytes) per element];
        awo [count][nil bs][present elems]."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if opt and elems[i] is None:
                continue
            store_elem(self, elems[i])
        if opt:
            self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    # ── packed arrayWithOptionals bodies (compacted: present-only payload) ────
    def store_packed_int_opt_array(self, elems, width, to_leb, store_raw, raw=False):
        """Packed int awo (width >= 2): [(count<<2)|tag][nil bs][enc bs if tag2][present].
        `raw=True` (spec/39): no probe, present elements W bytes each, tag 1."""
        before = self.cursor
        count = len(elems)
        if raw:
            for i in range(count - 1, -1, -1):
                if elems[i] is not None:
                    store_raw(self, elems[i])
            self.store_bytes(self._nil_bits(elems))
            self.store_leb((count << 2) | 1)
            return self.store_leb(self.cursor - before)
        enc = bytearray((count + 7) // 8)
        raw_count = 0
        present = 0
        for i in range(count - 1, -1, -1):
            if elems[i] is None:
                continue
            present += 1
            lv = to_leb(elems[i])
            if leb_length(lv) < width:
                self.store_leb(lv)
            else:
                store_raw(self, elems[i])
                enc[i >> 3] |= 1 << (i & 7)
                raw_count += 1
        tag = 0
        if raw_count == present and present > 0:
            tag = 1
        elif raw_count > 0:
            tag = 2
            self.store_bytes(enc)
        self.store_bytes(self._nil_bits(elems))
        self.store_leb((count << 2) | tag)
        return self.store_leb(self.cursor - before)

    def store_packed_byte_opt_array(self, elems, store_raw):
        """Packed u8/i8 awo: [count][nil bs][present raw bytes]."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if elems[i] is not None:
                store_raw(self, elems[i])
        self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_bool_opt_array(self, elems):
        """Packed bool awo: [count][nil bs][present value bitset] (compacted, ci-indexed)."""
        before = self.cursor
        present = sum(1 for e in elems if e is not None)
        val = bytearray((present + 7) // 8)
        ci = 0
        for e in elems:
            if e is None:
                continue
            if e:
                val[ci >> 3] |= 1 << (ci & 7)
            ci += 1
        self.store_bytes(val)
        self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_f16_opt_array(self, elems, is_bf16):
        """Packed f16/bf16 awo: [count][nil bs][present raw 2-byte]."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if elems[i] is not None:
                self.store_u16(f32_to_bf16_bits(elems[i]) if is_bf16 else f32_to_f16_bits(elems[i]))
        self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_float_opt_array(self, elems, is_f64, raw=False):
        """Packed f32/f64 awo: [(count<<2)|mode][nil bs][present elems]."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if elems[i] is None:
                continue
            if raw:
                self.store_f64(elems[i]) if is_f64 else self.store_f32(elems[i])
            elif is_f64:
                self.store_packed_float64(elems[i], True)
            else:
                self.store_packed_float32(elems[i], True)
        self.store_bytes(self._nil_bits(elems))
        self.store_leb((len(elems) << 2) | (1 if raw else 0))
        return self.store_leb(self.cursor - before)

    def store_packed_enum_bit_opt_array(self, elems, bits):
        """Packed sub-byte enum awo: [count][nil bs][present value bitset] (compacted)."""
        before = self.cursor
        present = sum(1 for e in elems if e is not None)
        per = 8 // bits
        mask = (1 << bits) - 1
        val = bytearray((present * bits + 7) // 8)
        ci = 0
        for e in elems:
            if e is None:
                continue
            val[ci // per] |= (e & mask) << ((ci % per) * bits)
            ci += 1
        self.store_bytes(val)
        self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    def store_packed_enum_raw_opt_array(self, elems):
        """Packed byte-aligned enum awo: [count][nil bs][present LEB rawValues]."""
        before = self.cursor
        for i in range(len(elems) - 1, -1, -1):
            if elems[i] is not None:
                self.store_leb(elems[i])
        self.store_bytes(self._nil_bits(elems))
        self.store_leb(len(elems))
        return self.store_leb(self.cursor - before)

    # ── aligned array/blob fields (§11) ───────────────────────────────────────
    def store_aligned_array(self, elems, width, n, each):
        """Aligned fixed-width numeric array: pre-pad, reversed W-byte elements, LEB count."""
        pad = (-(self.cursor + len(elems) * width)) & (n - 1)
        if pad:
            self.store_bytes(bytes(pad))
        for i in range(len(elems) - 1, -1, -1):
            each(self, elems[i])
        return self.store_leb(len(elems))

    def store_aligned_bytes(self, data, n):
        """Aligned byte blob (utf8/data, W=1): pre-pad, reversed bytes, LEB byte-count."""
        b = bytes(data)
        pad = (-(self.cursor + len(b))) & (n - 1)
        if pad:
            self.store_bytes(bytes(pad))
        for i in range(len(b) - 1, -1, -1):
            self.store_u8(b[i])
        return self.store_leb(len(b))

    def store_aligned_utf8(self, s, n):
        """Aligned utf8: the UTF-8 bytes, N-aligned (no dedup — position-dependent)."""
        return self.store_aligned_bytes(s.encode("utf-8"), n)

    # ── regular/frozen union array (SoA §4.9) ─────────────────────────────────
    def store_union_array(self, count, applied, bp, opt):
        """Content already stored (phase 1). ``applied`` is in REVERSED element order;
        each is ``{'kind':'v'|'p'|'b','val','tid'}`` or None (nil element). Stores
        [slot table][nil bitset (opt)][typeId section][header]. Slot = value bit-pattern
        (v) / distance base→content (p) / distance<<1 (b node). ``bp`` = typeId bits per
        element (sub-byte packed, or a byte each when bp==8)."""
        content_end = self.cursor
        wc = 0
        slots = []
        for a in applied:
            if a is None:
                slots.append(0)
                continue
            if a["kind"] == "v":
                v = a["val"]
            elif a["kind"] == "p":
                v = content_end - a["val"]
            else:
                v = (content_end - a["val"]) << 1
            wc = max(wc, 0 if v <= 0xFF else 1 if v <= 0xFFFF else 2 if v <= 0xFFFFFFFF else 3)
            slots.append(v)
        for v in slots:
            self._store_uint_wc(v, wc)
        if opt:
            nil = bytearray((count + 7) // 8)
            for j in range(count):
                idx = count - 1 - j
                if applied[j] is None:
                    nil[idx >> 3] |= 1 << (idx & 7)
            self.store_bytes(nil)
        if bp < 8:                                 # sub-byte typeId bitset
            per = 8 // bp
            mask = (1 << bp) - 1
            bs = bytearray((count * bp + 7) // 8)
            for j in range(count):
                idx = count - 1 - j
                tid = applied[j]["tid"] if applied[j] is not None else 0
                bs[idx // per] |= (tid & mask) << ((idx % per) * bp)
            self.store_bytes(bs)
        else:                                      # one byte per typeId
            for a in applied:
                self.store_u8(a["tid"] if a is not None else 0)
        return self.store_leb((count << 2) | wc)

    # ── union field slot (regular/frozen) ─────────────────────────────────────
    def store_union_slot(self, applied):
        """Run ``applied['emit'](self)`` (store the value / pointer — content already
        stored by apply), then the tag LEB ``(typeId<<2)|widthCode``."""
        before = self.cursor
        applied["emit"](self)
        n = self.cursor - before
        wc = 0 if n == 1 else 1 if n == 2 else 2 if n == 4 else 3
        return self.store_leb((applied["id"] << 2) | wc)

    def store_nested_union_slot(self, applied):
        """Nested-union value slot: tag LEB is ``id<<2`` (width code fixed at 0)."""
        applied["emit"](self)
        return self.store_leb(applied["id"] << 2)

    # ── finish alignment padding (§11) ────────────────────────────────────────
    def store_finish_alignment_padding(self, root_offset, max_n):
        if max_n <= 1:
            return
        for p in range(max_n):
            after_pad = self.cursor + p
            framing_len = leb_length((after_pad - root_offset) << 2)
            if (after_pad + framing_len) % max_n == 0:
                if p:
                    self.store_bytes(bytes(p))
                return

    # ── the finished buffer ───────────────────────────────────────────────────
    def make_data(self):
        """Chunks concatenated in reverse store order."""
        out = bytearray()
        for chunk in reversed(self.chunks):
            out += chunk
        return bytes(out)
