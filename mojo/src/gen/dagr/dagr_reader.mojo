# Dagr lazy-read runtime primitives (Mojo) — Phase 0 spike.
#
# Hand-ported from the TS/Swift/Rust generated runtime
# (targets/typescript/src/dagr_reader.ts, targets/swift/Sources/DagrExample/DagrRuntime.swift).
# This is the "spec/28-mojo-codegen-plan.md" §7 Phase 0 surface: just enough of the
# wire primitives to lazily read a regular (vtable) node of required scalars.
#
# Reader model (plan §8.2): a single borrowed `Span[UInt8, origin]`; Mojo reads
# fixed-width scalars off the Span directly (native LE) — no DataView split as in
# TS. Access is via position-passing free functions, mirroring the Swift/Rust
# getters 1:1. Free functions unbind the origin (`Span[UInt8, _]`) so any borrow
# is accepted; the accessor struct pins a concrete `Self.o` for node-ref chaining.
from std.bit import count_trailing_zeros
from std.sys import CompilationTarget
from std.sys.intrinsics import llvm_intrinsic, inlined_assembly
from std.memory import unsafe_memcpy


# LEB128 unsigned varint. Returns (value, bytesConsumed).
# Mirrors readLEB in dagr_reader.ts. (`raises` before `->`, plan §8.8g.)
def read_leb(buf: Span[UInt8, _], at: Int) raises -> Tuple[UInt64, Int]:
    if at < 0:
        raise Error("outsideOfBuffer")
    # ── x86-BMI2 branch-free path (comptime-gated) ─────────────────────────────
    # One bounds-checked u64 load; `cttz(~raw & 0x80..80)` gives the length; PEXT
    # gathers the 7-bit groups in one instruction. Handles values ≤ 8 LEB bytes
    # wholly in-bounds; the buffer tail (<8 bytes left) and 9–10-byte values fall
    # through to the portable loop. ONLY compiled on x86-with-BMI2
    # (PEXT is slow on AMD pre-Zen3 — measure and keep-or-revert on such parts).
    # PEXT is emitted as inline asm rather than `llvm.x86.bmi.pext.64`: current LLVM no
    # longer exposes that intrinsic by name, and the mnemonic is stable across toolchains.
    comptime if CompilationTarget.is_x86() and CompilationTarget._has_feature["bmi2"]():
        if at + 8 <= len(buf):
            var raw = (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[UInt64]().unsafe_load[alignment=1]()
            var clear = (~raw) & UInt64(0x8080808080808080)
            if clear != 0:                       # terminator within these 8 bytes
                var n = (Int(count_trailing_zeros(clear)) >> 3) + 1
                var pmask = UInt64(0x7f7f7f7f7f7f7f7f) & (
                    (~UInt64(0)) >> UInt64(64 - 8 * n))
                var value = inlined_assembly[
                    "pextq $2, $1, $0", UInt64, constraints="=r,r,r",
                    has_side_effect=False](raw, pmask)
                return (value, n)
    # ── single-byte fast prefix (the dominant case) ────────────────────────────
    # Most LEBs in practice are one byte (small tags / values < 128). A dedicated
    # well-predicted check returns them without the loop's shift/pos bookkeeping.
    # Multi-byte values fall through to the loop below. (A full SWAR/PEXT-less
    # 8-group fold was tried on ARM and REGRESSED ~15% — the branchless fold is more
    # instructions per call than the tight loop when values are mostly 1–2 bytes.)
    # Index through the raw pointer, not `buf[...]`: the explicit `< len(buf)` /
    # `>= len(buf)` guards below already bound every access, so `Span.__getitem__`'s
    # own bounds check (a non-inlined call, per byte) is pure redundancy — it was the
    # #1 decode cost in a `sample` profile. Rust elides the equivalent in `--release`.
    var p = buf.unsafe_ptr()
    var n = len(buf)
    if at < n:
        var b0 = p[unsafe_offset=at]
        if b0 < 0x80:
            return (UInt64(b0), 1)
    # ── portable loop (x86 tail / ≥ 9-byte fallback; and multi-byte on ARM) ─────
    var pos = at
    var result: UInt64 = 0
    var shift: UInt64 = 0
    while True:
        if pos >= n:
            raise Error("outsideOfBuffer")
        var b = p[unsafe_offset=pos]
        result += UInt64(b & 0x7F) << shift
        shift += 7
        pos += 1
        if (b >> 7) == 0:
            break
    return (result, pos - at)


# ZigZag decode. -(n & 1) wraps to all-ones on the odd path, flipping the bits of
# (n >> 1) — the standard branchless form. Mirrors `.fromZigZag` in the runtime.
def zigzag_decode(n: UInt64) -> Int64:
    return Int64(n >> 1) ^ -Int64(n & 1)


# ── Fixed-width scalar reads (regular-node `restore` path — NOT LEB) ──────────
# In a regular (vtable) node, scalars are stored native little-endian at a fixed
# width at the vtable field offset. bitcast+load[alignment=1] does the unaligned
# native-LE read (plan §8.8g). Signed types bitcast to the signed dtype directly;
# f16/bf16 are NATIVE Mojo dtypes — no bit-twiddling (the TS win, plan §8.1).

def _bounds(buf: Span[UInt8, _], at: Int, width: Int) raises:
    if at < 0 or at + width > len(buf):
        raise Error("outsideOfBuffer")


def read_u8(buf: Span[UInt8, _], at: Int) raises -> UInt8:
    _bounds(buf, at, 1)
    return buf.unsafe_ptr()[unsafe_offset=at]   # `_bounds` already raised on OOB; skip Span's recheck


def read_u16(buf: Span[UInt8, _], at: Int) raises -> UInt16:
    _bounds(buf, at, 2)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[UInt16]().unsafe_load[alignment=1]()


def read_u32(buf: Span[UInt8, _], at: Int) raises -> UInt32:
    _bounds(buf, at, 4)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[UInt32]().unsafe_load[alignment=1]()


def read_u64(buf: Span[UInt8, _], at: Int) raises -> UInt64:
    _bounds(buf, at, 8)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[UInt64]().unsafe_load[alignment=1]()


def read_i8(buf: Span[UInt8, _], at: Int) raises -> Int8:
    _bounds(buf, at, 1)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Int8]().unsafe_load[alignment=1]()


def read_i16(buf: Span[UInt8, _], at: Int) raises -> Int16:
    _bounds(buf, at, 2)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Int16]().unsafe_load[alignment=1]()


def read_i32(buf: Span[UInt8, _], at: Int) raises -> Int32:
    _bounds(buf, at, 4)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Int32]().unsafe_load[alignment=1]()


def read_i64(buf: Span[UInt8, _], at: Int) raises -> Int64:
    _bounds(buf, at, 8)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Int64]().unsafe_load[alignment=1]()


def read_f32(buf: Span[UInt8, _], at: Int) raises -> Float32:
    _bounds(buf, at, 4)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Float32]().unsafe_load[alignment=1]()


def read_f64(buf: Span[UInt8, _], at: Int) raises -> Float64:
    _bounds(buf, at, 8)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Float64]().unsafe_load[alignment=1]()


def read_f16(buf: Span[UInt8, _], at: Int) raises -> Float16:
    _bounds(buf, at, 2)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[Float16]().unsafe_load[alignment=1]()


def read_bf16(buf: Span[UInt8, _], at: Int) raises -> BFloat16:
    _bounds(buf, at, 2)
    return (buf.unsafe_ptr().unsafe_offset(at)).unsafe_bitcast[BFloat16]().unsafe_load[alignment=1]()


def read_bool(buf: Span[UInt8, _], at: Int) raises -> Bool:
    _bounds(buf, at, 1)
    return buf.unsafe_ptr()[unsafe_offset=at] != 0


# V62 bidirectional pointer. Low 2 bits select width (0→1B, 1→2B, 2→4B, 3→8B),
# value = raw >> 2. Returns (value, bytesConsumed). Mirrors readV62 in the runtime.
# Used UNSIGNED for utf8/data/array forward pointers; wrap in read_zigzag_v62 for
# node-ref (bidirectional, may point backward to a shared/cyclic node).
def read_v62(buf: Span[UInt8, _], at: Int) raises -> Tuple[UInt64, Int]:
    if at < 0 or at >= len(buf):
        raise Error("outsideOfBuffer")
    var b = buf.unsafe_ptr()[unsafe_offset=at]           # bounds checked just above
    var code = Int(b & 3)
    if code == 0:
        return (UInt64(b) >> 2, 1)
    elif code == 1:
        return (UInt64(read_u16(buf, at)) >> 2, 2)
    elif code == 2:
        return (UInt64(read_u32(buf, at)) >> 2, 4)
    else:
        return (read_u64(buf, at) >> 2, 8)


# Read an `nbytes` little-endian bitset into a UInt64 (bit i = field/optional i).
# Used by the frozen presence bitset and frozen-packed nil/enc bitsets.
def read_bitset(buf: Span[UInt8, _], at: Int, nbytes: Int) raises -> UInt64:
    _bounds(buf, at, nbytes)               # guard the whole region once, then load unchecked
    var p = buf.unsafe_ptr()
    var b: UInt64 = 0
    for k in range(nbytes):
        b += UInt64(p[unsafe_offset=at + k]) << UInt64(8 * k)
    return b


# ── Packed-node primitives (spec/07-packed-nodes.md) ──────────────────────────────
from std.math import inf, nan

# Signed packed ints are ZigZag-LEB. Returns (value, bytesConsumed).
def read_zigzag_leb(buf: Span[UInt8, _], at: Int) raises -> Tuple[Int64, Int]:
    var r = read_leb(buf, at)
    return (zigzag_decode(r[0]), r[1])


# Packed float compression (§12): a sub-tag byte selects the encoding.
#   00 +0 · 01 -0 · 02 +inf · 03 -inf · 04 NaN · 05 zigzag-LEB int
#   06 f16 bits (2B) · 07 f32 (4B) · 08 f64 (8B, f64 only)
# Returns (value, bytesConsumed).
#
# Branch order matters: Mojo lowers this to a linear `if`-chain (unlike Rust's `match`
# jump table), so the COMMON case is checked first. Real data is dominated by the
# multi-byte raw/compressed tags (5–8) — incompressible floats hit the raw tag (f32=7,
# f64=8), integer-valued columns hit 5; the ±0/±inf/NaN special values (0–4) are rare, so
# they go in a cold trailing branch. This is O(1)–ish for the hot path (2 compares for a
# raw float) instead of the 8-compare cascade the natural 0…8 order would run.
def decode_packed_f32(buf: Span[UInt8, _], at: Int) raises -> Tuple[Float32, Int]:
    _bounds(buf, at, 1)
    var tag = buf.unsafe_ptr()[unsafe_offset=at]
    if tag >= 6:                                    # raw: f16 (6) / f32 (7) — common
        if tag == 7:
            return (read_f32(buf, at + 1), 5)
        return (read_f16(buf, at + 1).cast[DType.float32](), 3)   # tag 6
    if tag == 5:                                    # zigzag-LEB int
        var z = read_zigzag_leb(buf, at + 1)
        return (Float32(z[0]), 1 + z[1])
    if tag == 0:                                    # rare special values 0–4
        return (Float32(0.0), 1)
    if tag == 1:
        return (-Float32(0.0), 1)
    if tag == 2:
        return (inf[DType.float32](), 1)
    if tag == 3:
        return (-inf[DType.float32](), 1)
    return (nan[DType.float32](), 1)                # tag 4


def decode_packed_f64(buf: Span[UInt8, _], at: Int) raises -> Tuple[Float64, Int]:
    _bounds(buf, at, 1)
    var tag = buf.unsafe_ptr()[unsafe_offset=at]
    if tag >= 6:                                    # raw: f16 (6) / f32 (7) / f64 (8) — common
        if tag == 8:
            return (read_f64(buf, at + 1), 9)
        if tag == 7:
            return (read_f32(buf, at + 1).cast[DType.float64](), 5)
        return (read_f16(buf, at + 1).cast[DType.float64](), 3)   # tag 6
    if tag == 5:                                    # zigzag-LEB int
        var z = read_zigzag_leb(buf, at + 1)
        return (Float64(z[0]), 1 + z[1])
    if tag == 0:                                    # rare special values 0–4
        return (Float64(0.0), 1)
    if tag == 1:
        return (-Float64(0.0), 1)
    if tag == 2:
        return (inf[DType.float64](), 1)
    if tag == 3:
        return (-inf[DType.float64](), 1)
    return (nan[DType.float64](), 1)                # tag 4


# Packed f16/bf16 encoded path: special values only (1 byte). Non-special uses raw
# 2-byte native form (isRaw=1), handled by the caller. Returns (value, bytes).
def decode_packed_f16(buf: Span[UInt8, _], at: Int) raises -> Tuple[Float16, Int]:
    _bounds(buf, at, 1)
    var tag = buf.unsafe_ptr()[unsafe_offset=at]
    if tag == 1:
        return (-Float16(0.0), 1)
    if tag == 2:
        return (inf[DType.float16](), 1)
    if tag == 3:
        return (-inf[DType.float16](), 1)
    if tag == 4:
        return (nan[DType.float16](), 1)
    return (Float16(0.0), 1)  # tag 0 (+0)


def decode_packed_bf16(buf: Span[UInt8, _], at: Int) raises -> Tuple[BFloat16, Int]:
    _bounds(buf, at, 1)
    var tag = buf.unsafe_ptr()[unsafe_offset=at]
    if tag == 1:
        return (-BFloat16(0.0), 1)
    if tag == 2:
        return (inf[DType.bfloat16](), 1)
    if tag == 3:
        return (-inf[DType.bfloat16](), 1)
    if tag == 4:
        return (nan[DType.bfloat16](), 1)
    return (BFloat16(0.0), 1)  # tag 0 (+0)


# ── Packed arrays (materialized) — 07 §5 ────────────────────────────────────
# Packed array elements are variable-width (LEB / packed-float / mixed), so unlike
# the regular fixed-width arrays these are decoded eagerly into an owned wrapper
# with the same `len()` / `get(i)` API. `OwnedArray[T]` holds a `List[T]`.
@fieldwise_init
struct OwnedArray[T: Copyable & Deinitable](Copyable, Movable, Sized):
    var items: List[Self.T]

    def __len__(self) -> Int:
        return len(self.items)

    def get(self, i: Int) raises -> Self.T:
        if i < 0 or i >= len(self.items):
            raise Error("array index out of range")
        return self.items[i].copy()

    # Consume the array and hand its backing List straight to the caller — lets the
    # restore path MOVE an already-decoded packed value array into the arena field
    # instead of re-copying it element-by-element (the packed double-materialization).
    def into_list(deinit self) -> List[Self.T]:
        return self.items^


# Lazy view over a packed FLOAT value array. Unlike the eager `OwnedArray` (which
# decodes every element up front), this reads only the header at construction, so
# `len()` is O(1). Two on-wire formats, comptime-selected by `dt`:
#   • f32/f64  → `[LEB (count<<2 | mode)][elems]`, one array-wide mode (1 = raw
#     native-LE fixed width, 0 = self-describing packed). `[i]` is O(1) raw / O(i) packed.
#   • f16/bf16 → `[LEB count][per-element enc-bitset][elems]` (bit set = raw 2-byte, clear
#     = self-describing packed half). `[i]` is O(i) (variable-width walk).
# `into_list()` materialises the whole array (used by eager restore) — the element walk
# is byte-identical to `decode_packed_f{32,64}_array` / `decode_packed_half_array`.
@fieldwise_init
struct PackedFloatArray[o: ImmOrigin, dt: DType, width: Int](
    Copyable, Movable, ImplicitlyCopyable, Sized
):
    var buf: Span[UInt8, Self.o]
    var _base: Int       # first element (past the header LEB + enc-bitset for half)
    var _count: Int
    var _enc: Int        # half: enc-bitset start; f32/f64: -1 (array-wide `_raw`)
    var _raw: Bool       # f32/f64: mode == 1 (native-LE fixed width)

    def __init__(out self, buf: Span[UInt8, Self.o], at: Int) raises:
        self.buf = buf
        var c = read_leb(buf, at)
        comptime if Self.dt == DType.float16 or Self.dt == DType.bfloat16:
            self._count = Int(c[0])                       # plain count, no mode bits
            self._enc = at + c[1]
            self._base = self._enc + (self._count + 7) // 8
            self._raw = False
        else:
            self._count = Int(c[0]) >> 2                  # low 2 bits = array-wide mode
            self._raw = (Int(c[0]) & 3) == 1
            self._enc = -1
            self._base = at + c[1]

    def __len__(self) -> Int:
        return self._count

    # Element `i` at byte position `p` → (value, byte-width-consumed). `i` selects the
    # per-element enc-bitset bit for the half formats (unused for f32/f64).
    def _read(self, p: Int, i: Int) raises -> Tuple[Scalar[Self.dt], Int]:
        comptime if Self.dt == DType.float16:
            if (self.buf[self._enc + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
                _bounds(self.buf, p, 2)
                return ((self.buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[Self.dt]]().unsafe_load[alignment=1](), 2)
            var v = decode_packed_f16(self.buf, p)
            return (rebind[Scalar[Self.dt]](v[0]), v[1])
        elif Self.dt == DType.bfloat16:
            if (self.buf[self._enc + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
                _bounds(self.buf, p, 2)
                return ((self.buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[Self.dt]]().unsafe_load[alignment=1](), 2)
            var v = decode_packed_bf16(self.buf, p)
            return (rebind[Scalar[Self.dt]](v[0]), v[1])
        elif Self.dt == DType.float32:
            if self._raw:
                _bounds(self.buf, p, 4)
                return ((self.buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[Self.dt]]().unsafe_load[alignment=1](), 4)
            var v = decode_packed_f32(self.buf, p)
            return (rebind[Scalar[Self.dt]](v[0]), v[1])
        else:
            if self._raw:
                _bounds(self.buf, p, 8)
                return ((self.buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[Self.dt]]().unsafe_load[alignment=1](), 8)
            var v = decode_packed_f64(self.buf, p)
            return (rebind[Scalar[Self.dt]](v[0]), v[1])

    def __getitem__(self, i: Int) raises -> Scalar[Self.dt]:
        comptime if Self.dt == DType.float32 or Self.dt == DType.float64:
            if self._raw:                              # O(1) fixed-width index
                return self._read(self._base + i * Self.width, i)[0]
        var p = self._base                             # packed / half: O(i) walk
        for j in range(i):
            p += self._read(p, j)[1]
        return self._read(p, i)[0]

    def get(self, i: Int) raises -> Scalar[Self.dt]:   # OwnedArray-compatible accessor
        return self[i]

    def into_list(self) raises -> List[Scalar[Self.dt]]:
        var out = List[Scalar[Self.dt]](capacity=self._count)
        var p = self._base
        comptime if Self.dt == DType.float32 or Self.dt == DType.float64:
            if self._raw:                              # fixed-width fast path
                for i in range(self._count):
                    out.append(self._read(p, i)[0]); p += Self.width
                return out^
        for i in range(self._count):                   # packed / half: variable-width walk
            var v = self._read(p, i)
            out.append(v[0]); p += v[1]
        return out^


# Packed int array `[LEB (count<<2)|tag][elems]` (width ≥ 2): tag 0 = all-LEB,
# 1 = all-raw (fixed width), 2 = mixed (leading enc-bitset, bit set = raw). Signed
# elements are ZigZag-LEB when encoded. Returns an owned List[Scalar[dt]].
def decode_packed_int_array[dt: DType, width: Int, signed: Bool](buf: Span[UInt8, _], at: Int) raises -> List[Scalar[dt]]:
    var c = read_leb(buf, at)
    var count = Int(c[0]) >> 2
    var tag = Int(c[0]) & 3
    var enc_start = at + c[1]
    var p = enc_start + ((count + 7) // 8 if tag == 2 else 0)
    if tag == 2:
        _bounds(buf, enc_start, (count + 7) // 8)   # guard the enc-bitset region once
    var bp = buf.unsafe_ptr()
    var out = List[Scalar[dt]]()
    for i in range(count):
        var is_raw = tag == 1
        if tag == 2:
            is_raw = (bp[unsafe_offset=enc_start + (i >> 3)] >> UInt8(i & 7)) & 1 == 1
        if is_raw:
            out.append((buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[dt]]().unsafe_load[alignment=1]())
            p += width
        else:
            comptime if signed:
                var z = read_zigzag_leb(buf, p)
                out.append(Scalar[dt](z[0]))
                p += z[1]
            else:
                var v = read_leb(buf, p)
                out.append(Scalar[dt](v[0]))
                p += v[1]
    return out^


# Packed u8/i8 array: plain `[LEB count][raw bytes]` (single-path, no count-tag).
def decode_byte_array[dt: DType](buf: Span[UInt8, _], at: Int) raises -> List[Scalar[dt]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var p = at + c[1]
    var out = List[Scalar[dt]]()
    for i in range(count):
        out.append((buf.unsafe_ptr().unsafe_offset(p + i)).unsafe_bitcast[Scalar[dt]]().unsafe_load[alignment=1]())
    return out^


# Packed float array `[LEB (count<<2)|mode][elems]`: mode 0 = self-describing packed
# float, mode 1 = raw native-LE. `dec` decodes one packed-float element.
def decode_packed_f32_array(buf: Span[UInt8, _], at: Int) raises -> List[Float32]:
    var c = read_leb(buf, at)
    var count = Int(c[0]) >> 2
    var mode = Int(c[0]) & 3
    var p = at + c[1]
    var out = List[Float32]()
    for _ in range(count):
        if mode == 1:
            out.append(read_f32(buf, p)); p += 4
        else:
            var v = decode_packed_f32(buf, p); out.append(v[0]); p += v[1]
    return out^


def decode_packed_f64_array(buf: Span[UInt8, _], at: Int) raises -> List[Float64]:
    var c = read_leb(buf, at)
    var count = Int(c[0]) >> 2
    var mode = Int(c[0]) & 3
    var p = at + c[1]
    var out = List[Float64]()
    for _ in range(count):
        if mode == 1:
            out.append(read_f64(buf, p)); p += 8
        else:
            var v = decode_packed_f64(buf, p); out.append(v[0]); p += v[1]
    return out^


# Packed bool array `[LEB count][bitset]` → owned List[Bool].
def decode_bool_list(buf: Span[UInt8, _], at: Int) raises -> List[Bool]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var bs = at + c[1]
    _bounds(buf, bs, (count + 7) // 8)          # guard the bitset region once
    var bp = buf.unsafe_ptr()
    var out = List[Bool]()
    for i in range(count):
        out.append((bp[unsafe_offset=bs + (i >> 3)] >> UInt8(i & 7)) & 1 != 0)
    return out^


# Packed sub-byte enum array `[LEB count][packed bits]` → owned List[UInt8].
def decode_enum_bit_list[bits: Int](buf: Span[UInt8, _], at: Int) raises -> List[UInt8]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var base = at + c[1]
    var per_byte = 8 // bits
    var mask = UInt8((1 << bits) - 1)
    _bounds(buf, base, (count + per_byte - 1) // per_byte)   # guard the packed-bits region once
    var bp = buf.unsafe_ptr()
    var out = List[UInt8]()
    for i in range(count):
        var byte = bp[unsafe_offset=base + i // per_byte]
        out.append((byte >> UInt8((i % per_byte) * bits)) & mask)
    return out^


# Packed byte-aligned enum array `[LEB count][LEB rawValue per elem]` → List[Scalar[dt]].
def decode_packed_enum_raw_list[dt: DType](buf: Span[UInt8, _], at: Int) raises -> List[Scalar[dt]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var p = at + c[1]
    var out = List[Scalar[dt]]()
    for _ in range(count):
        var v = read_leb(buf, p)
        out.append(Scalar[dt](v[0]))
        p += v[1]
    return out^


# Packed f16/bf16 array `[LEB count][enc bitset][elems]`: bit i set → raw 2-byte
# native, unset → self-describing packed-f16 special (1 byte). `dt` = float16/bfloat16.
def decode_packed_half_array[dt: DType, is_bf: Bool](buf: Span[UInt8, _], at: Int) raises -> List[Scalar[dt]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var enc = at + c[1]
    var p = enc + (count + 7) // 8
    var out = List[Scalar[dt]]()
    for i in range(count):
        if (buf[enc + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:  # raw
            out.append((buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[dt]]().unsafe_load[alignment=1]())
            p += 2
        else:  # self-describing special (rebind through the concrete dtype decoder)
            comptime if is_bf:
                var v = decode_packed_bf16(buf, p)
                out.append(rebind[Scalar[dt]](v[0])); p += v[1]
            else:
                var v = decode_packed_f16(buf, p)
                out.append(rebind[Scalar[dt]](v[0])); p += v[1]
    return out^


# Packed complex array `[LEB count][ per elem [LEB len][bytes] ]` (utf8/data).
def decode_utf8_list(buf: Span[UInt8, _], at: Int) raises -> List[String]:
    var c = read_leb(buf, at)
    var p = at + c[1]
    var out = List[String]()
    for _ in range(Int(c[0])):
        var s = read_utf8(buf, p)
        out.append(String(s[0])); p += s[1]
    return out^


def decode_data_list(buf: Span[UInt8, _], at: Int) raises -> List[List[UInt8]]:
    var c = read_leb(buf, at)
    var p = at + c[1]
    var count = Int(c[0])
    var out = List[List[UInt8]](); out.reserve(count)
    for _ in range(count):
        var d = read_data(buf, p)
        # reserve once + memcpy from the zero-copy `read_data` Span, not a per-byte
        # append loop (which regrows each List → malloc churn per element).
        var one = List[UInt8](unsafe_uninit_length=len(d[0]))
        if len(d[0]) > 0:
            unsafe_memcpy(dest=one.unsafe_ptr(), src=d[0].unsafe_ptr(), count=len(d[0]))
        out.append(one^); p += d[1]
    return out^


# ── Packed arrayWithOptionals (AWO) — compacted, `List[Optional[T]]` ─────────
# nil bit i set → element i is None; present elements are stored COMPACTED.
def decode_packed_int_opt_array[dt: DType, width: Int, signed: Bool](buf: Span[UInt8, _], at: Int) raises -> List[Optional[Scalar[dt]]]:
    var c = read_leb(buf, at)
    var count = Int(c[0]) >> 2
    var tag = Int(c[0]) & 3
    var nil_s = at + c[1]
    var bs = (count + 7) // 8
    var enc_s = nil_s + bs
    var p = enc_s + (bs if tag == 2 else 0)
    _bounds(buf, nil_s, p - nil_s)
    var bp = buf.unsafe_ptr()
    var out = List[Optional[Scalar[dt]]]()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        var is_raw = tag == 1
        if tag == 2:
            is_raw = (bp[unsafe_offset=enc_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1
        if is_raw:
            out.append((buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[dt]]().unsafe_load[alignment=1]()); p += width
        else:
            comptime if signed:
                var z = read_zigzag_leb(buf, p); out.append(Scalar[dt](z[0])); p += z[1]
            else:
                var v = read_leb(buf, p); out.append(Scalar[dt](v[0])); p += v[1]
    return out^


# Packed u8/i8 AWO: `[LEB count][nil bitset][present raw bytes]` (plain count).
def decode_packed_byte_opt_array[dt: DType](buf: Span[UInt8, _], at: Int) raises -> List[Optional[Scalar[dt]]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    var out = List[Optional[Scalar[dt]]]()
    _bounds(buf, nil_s, p - nil_s)
    var bp = buf.unsafe_ptr()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        out.append((buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[dt]]().unsafe_load[alignment=1]()); p += 1
    return out^


# Packed float AWO `[LEB (count<<2)|mode][nil bitset][present]` (mode 0 self-desc/1 raw).
def decode_packed_f32_opt_array(buf: Span[UInt8, _], at: Int) raises -> List[Optional[Float32]]:
    var c = read_leb(buf, at)
    var count = Int(c[0]) >> 2
    var mode = Int(c[0]) & 3
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    var out = List[Optional[Float32]]()
    _bounds(buf, nil_s, p - nil_s)
    var bp = buf.unsafe_ptr()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        if mode == 1:
            out.append(read_f32(buf, p)); p += 4
        else:
            var v = decode_packed_f32(buf, p); out.append(v[0]); p += v[1]
    return out^


def decode_packed_f64_opt_array(buf: Span[UInt8, _], at: Int) raises -> List[Optional[Float64]]:
    var c = read_leb(buf, at)
    var count = Int(c[0]) >> 2
    var mode = Int(c[0]) & 3
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    var out = List[Optional[Float64]]()
    _bounds(buf, nil_s, p - nil_s)
    var bp = buf.unsafe_ptr()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        if mode == 1:
            out.append(read_f64(buf, p)); p += 8
        else:
            var v = decode_packed_f64(buf, p); out.append(v[0]); p += v[1]
    return out^


# Packed f16/bf16 AWO `[LEB count][nil bitset][present raw 2-byte]` (no enc bitset).
def decode_packed_half_opt_array[dt: DType](buf: Span[UInt8, _], at: Int) raises -> List[Optional[Scalar[dt]]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    var out = List[Optional[Scalar[dt]]]()
    _bounds(buf, nil_s, p - nil_s)
    var bp = buf.unsafe_ptr()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        out.append((buf.unsafe_ptr().unsafe_offset(p)).unsafe_bitcast[Scalar[dt]]().unsafe_load[alignment=1]()); p += 2
    return out^


# Packed bool AWO `[LEB count][nil bitset][compacted value bitset]`.
def decode_packed_bool_opt_list(buf: Span[UInt8, _], at: Int) raises -> List[Optional[Bool]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var bs = (count + 7) // 8
    var val_s = nil_s + bs
    var out = List[Optional[Bool]]()
    var ci = 0
    _bounds(buf, nil_s, bs)                 # guard only the nil bitset (always present);
    var bp = buf.unsafe_ptr()               # the COMPACTED value bitset (size ≤ bs, may end
    for i in range(count):                  # the buffer) stays checked via `buf[...]` below
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        out.append((buf[val_s + (ci >> 3)] >> UInt8(ci & 7)) & 1 != 0); ci += 1
    return out^


# Packed sub-byte enum AWO `[LEB count][nil bitset][compacted value bits]`.
def decode_enum_bit_opt_list[bits: Int](buf: Span[UInt8, _], at: Int) raises -> List[Optional[UInt8]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var val_s = nil_s + (count + 7) // 8
    var per_byte = 8 // bits
    var mask = UInt8((1 << bits) - 1)
    var out = List[Optional[UInt8]]()
    var ci = 0
    _bounds(buf, nil_s, (count + 7) // 8)   # nil bitset only; compacted value bits stay checked
    var bp = buf.unsafe_ptr()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        var byte = buf[val_s + ci // per_byte]
        out.append((byte >> UInt8((ci % per_byte) * bits)) & mask); ci += 1
    return out^


# Packed byte-aligned enum AWO `[LEB count][nil bitset][present LEB rawValues]`.
def decode_packed_enum_raw_opt_list[dt: DType](buf: Span[UInt8, _], at: Int) raises -> List[Optional[Scalar[dt]]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    var out = List[Optional[Scalar[dt]]]()
    _bounds(buf, nil_s, p - nil_s)
    var bp = buf.unsafe_ptr()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        var v = read_leb(buf, p); out.append(Scalar[dt](v[0])); p += v[1]
    return out^


# Packed complex AWO `[LEB count][nil bitset][present [len][bytes]]` (utf8/data).
def decode_utf8_opt_list(buf: Span[UInt8, _], at: Int) raises -> List[Optional[String]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    _bounds(buf, nil_s, p - nil_s)          # nil bitset (present elements read via read_utf8)
    var bp = buf.unsafe_ptr()
    var out = List[Optional[String]]()
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        var s = read_utf8(buf, p); out.append(String(s[0])); p += s[1]
    return out^


def decode_data_opt_list(buf: Span[UInt8, _], at: Int) raises -> List[Optional[List[UInt8]]]:
    var c = read_leb(buf, at)
    var count = Int(c[0])
    var nil_s = at + c[1]
    var p = nil_s + (count + 7) // 8
    _bounds(buf, nil_s, p - nil_s)          # nil bitset (present elements read via read_data)
    var bp = buf.unsafe_ptr()
    var out = List[Optional[List[UInt8]]](); out.reserve(count)
    for i in range(count):
        if (bp[unsafe_offset=nil_s + (i >> 3)] >> UInt8(i & 7)) & 1 == 1:
            out.append(None); continue
        var d = read_data(buf, p)
        var one = List[UInt8](unsafe_uninit_length=len(d[0]))
        if len(d[0]) > 0:
            unsafe_memcpy(dest=one.unsafe_ptr(), src=d[0].unsafe_ptr(), count=len(d[0]))
        out.append(one^); p += d[1]
    return out^


# Packed union header `[LEB (typeId<<3)|code][payload]` (07 §8). Returns
# (payload_pos, tag, code): tag = raw>>3, code = raw&7 (payload size class:
# 0 LEB · 1/2/3/4 = 1/2/4/8 raw bytes · 5 packed-float · 6 len-prefixed block).
def packed_union_header(buf: Span[UInt8, _], at: Int) raises -> Tuple[Int, UInt8, UInt8]:
    var r = read_leb(buf, at)
    return (at + r[1], UInt8((r[0] >> 3) & 0xFF), UInt8(r[0] & 7))


# Byte size of a packed-union payload after its header, from the 3-bit `code`.
# Lets a packed scan advance past a union field. Mirrors packedUnionPayloadBytes.
def packed_union_payload_bytes(buf: Span[UInt8, _], ep: Int, code: Int) raises -> Int:
    if code == 0:
        return read_leb(buf, ep)[1]
    if code == 1:
        return 1
    if code == 2:
        return 2
    if code == 3:
        return 4
    if code == 4:
        return 8
    if code == 5:
        return decode_packed_f64(buf, ep)[1]  # self-describing packed float
    var r = read_leb(buf, ep)  # code 6: len-prefixed / inline block
    return r[1] + Int(r[0])


# Raw embedded-graph leaf (18 §4): a `raw` node-ref inline entry
# `[LEB payloadLen][pad?][standalone .dagr blob]`. `pos` = payloadLen LEB start;
# `has_pad` = the embedded graph is alignment-bearing (a leading pad byte precedes
# the blob framing). Returns the absolute root-node position inside the blob (opened
# with the target's OWN-format accessor). Mirrors rawEmbeddedRoot.
def raw_embedded_root(buf: Span[UInt8, _], pos: Int, has_pad: Bool) raises -> Int:
    var pl = read_leb(buf, pos)                          # payloadLen (skip)
    var bs = pos + pl[1] + (1 if has_pad else 0)         # blob framing byte
    var fr = read_leb(buf, bs)
    return bs + fr[1] + Int(fr[0] >> 2)


# Union field slot header: `[LEB (typeId<<2)|wc][payload]`. Returns
# (payload_pos, tag) — tag = raw >> 2; the low 2 bits (`wc`, payload width class)
# are only needed by the frozen forward-walk, not the reader (each variant reader
# self-describes its payload width). Used by a `{Union}View` and by nested-union
# variant getters. Mirrors the header decode in read{Union}At (dagr_reader.ts).
def union_header(buf: Span[UInt8, _], pos: Int) raises -> Tuple[Int, UInt8]:
    var r = read_leb(buf, pos)
    return (pos + r[1], UInt8(r[0] >> 2))


# Signed (ZigZag) V62 pointer. Mirrors readZigZagV62 in the runtime.
def read_zigzag_v62(buf: Span[UInt8, _], at: Int) raises -> Tuple[Int64, Int]:
    var r = read_v62(buf, at)
    return (zigzag_decode(r[0]), r[1])


# Total byte size of a union field slot `[LEB (typeId<<2)|wc][payload]`, payload =
# 1<<wc bytes. Lets a frozen forward-walk skip a union field. Mirrors unionSlotBytes.
def union_slot_bytes(buf: Span[UInt8, _], at: Int) raises -> Int:
    var r = read_leb(buf, at)
    return r[1] + (1 << Int(r[0] & 3))


# Length-prefixed utf8 / data ([LEB count][bytes]). ALLOCATION-FREE: both return a
# BORROWED view over the buffer (plan §8.8b) — `StringSlice[o]` / `Span[UInt8, o]` —
# plus the byte count so inline callers can advance (forward-pointer callers ignore
# it). Owning is opt-in at the call site: `String(slice)` / a `List` copy — that is
# where a heap allocation is paid, never here. The origin `o` is threaded so the
# view's lifetime is tied to the input buffer.
def read_utf8[o: ImmOrigin](buf: Span[UInt8, o], at: Int) raises -> Tuple[StringSlice[o], Int]:
    var r = read_leb(buf, at)
    var length = Int(r[0])
    var start = at + r[1]
    if start + length > len(buf):
        raise Error("outsideOfBuffer")
    return (StringSlice(unsafe_from_utf8=buf[start : start + length]), r[1] + length)


def read_data[o: ImmOrigin](buf: Span[UInt8, o], at: Int) raises -> Tuple[Span[UInt8, o], Int]:
    var r = read_leb(buf, at)
    var length = Int(r[0])
    var start = at + r[1]
    if start + length > len(buf):
        raise Error("outsideOfBuffer")
    return (buf[start : start + length], r[1] + length)


# Parse a regular-node vtable, returning per-field offsets relative to the node
# start (-1 = field absent). Field position = node_start + offset.
# Mirrors restoreRTypeVTable in dagr_reader.ts:
#  - LEB at node_start is the (ZigZag) pointer to the vtable; even = dedup
#    forward-ref (+b1 off-by-one), odd = fresh vtable.
#  - vtable header LEB: `(fieldCount << 1) | wideFlag` (wide → 16-bit entries).
#  - each entry: 0 = absent, else storedValue - 1 + b1 = field offset.
def restore_rtype_vtable(buf: Span[UInt8, _], start: Int) raises -> List[Int]:
    var r0 = read_leb(buf, start)
    var offset_value = r0[0]
    var b1 = r0[1]
    var adj = b1 if (offset_value & 1) == 0 else 0
    var vt_start = start + Int(zigzag_decode(offset_value)) + adj
    var r1 = read_leb(buf, vt_start)
    var vt_size = r1[0]
    var b2 = r1[1]
    var count = Int(vt_size >> 1)
    var wide = (vt_size & 1) != 0
    var cursor = vt_start + b2
    var result = List[Int]()
    for _ in range(count):
        var v: Int
        if wide:
            v = Int(read_u16(buf, cursor))
            cursor += 2
        else:
            v = Int(buf[cursor])
            cursor += 1
        if v == 0:
            result.append(-1)
        else:
            result.append(v - 1 + b1)
    return result^


# Single-entry, ALLOCATION-FREE vtable lookup: return the relative offset of field
# `idx` (add to the node start to get its position), or -1 if the field is absent
# or beyond the stored vtable length. Equivalent to `restore_rtype_vtable(...)[idx]`
# with the `idx >= len` guard folded in, but it reads only entry `idx` and builds no
# List — the form the lazy getters use on the hot path (they touch one field at a
# time, so materializing the whole offset list per access is pure waste).
def rtype_vtable_slot(buf: Span[UInt8, _], start: Int, idx: Int) raises -> Int:
    var r0 = read_leb(buf, start)
    var offset_value = r0[0]
    var b1 = r0[1]
    var adj = b1 if (offset_value & 1) == 0 else 0
    var vt_start = start + Int(zigzag_decode(offset_value)) + adj
    var r1 = read_leb(buf, vt_start)
    var vt_size = r1[0]
    var b2 = r1[1]
    var count = Int(vt_size >> 1)
    if idx >= count:
        return -1
    var wide = (vt_size & 1) != 0
    var cursor = vt_start + b2 + (idx * 2 if wide else idx)
    var v = Int(read_u16(buf, cursor)) if wide else Int(buf[cursor])
    if v == 0:
        return -1
    return v - 1 + b1


# ── Zero-alloc array accessors ───────────────────────────────────────────────
# In a regular/frozen node an array field slot holds a V62 forward pointer to the
# payload `[LEB count][elements]`. These accessors borrow the buffer and decode
# elements on demand — no `List` materialization (plan §8.8a). `base` = the first
# element position (past the LEB count); `count` = the element count.

# Fixed-width native-LE numeric array (u8..i64, f16/bf16/f32/f64). `dt` is the
# element DType, `width` its byte size (both comptime, supplied by codegen).
@fieldwise_init
struct NumArray[o: ImmOrigin, dt: DType, width: Int](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var base: Int
    var count: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> Scalar[Self.dt]:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        return (
            self.buf.unsafe_ptr().unsafe_offset(self.base + i * Self.width)
        ).unsafe_bitcast[Scalar[Self.dt]]().unsafe_load[alignment=1]()


# Bool array: `[LEB count][bitset ceil(count/8)]` — bit i = element i. `base` = the
# bitset start. Sub-byte read stays in UInt8 (plan §8.8f: shift amount as UInt8).
@fieldwise_init
struct BoolArray[o: ImmOrigin](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var base: Int
    var count: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> Bool:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        return ((self.buf.unsafe_ptr()[unsafe_offset=self.base + (i >> 3)] >> UInt8(i & 7)) & 1) != 0


# Sub-byte enum array: `[LEB count][packed bits]` — element i's raw value occupies
# `bits` bits (1/2/4) at bit `(i % perByte) * bits` of byte `base + i // perByte`.
# `base` = the packed-bits start. Byte-aligned enum arrays (bits = None) reuse
# NumArray with the backing-int DType instead. Sub-byte raw values fit in a UInt8.
@fieldwise_init
struct EnumBitArray[o: ImmOrigin, bits: Int](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var base: Int
    var count: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> UInt8:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        var per_byte = 8 // Self.bits
        var byte = self.buf.unsafe_ptr()[unsafe_offset=self.base + i // per_byte]
        var shift = UInt8((i % per_byte) * Self.bits)
        var mask = UInt8((1 << Self.bits) - 1)
        return (byte >> shift) & mask


# ── arrayWithOptionals (AWO) accessors — element-`Optional`, UNCOMPACTED ──────
# In a regular/frozen node an AWO field is a V62 forward pointer to a payload that
# leads with a nil bitset (bit i set → element i is nil). For numeric/bool/enum the
# element slots are all present (nil ones zero-/unset-filled), indexed by i — no
# compaction (that is a packed-node concern). utf8/data/node-ref use a pointer-table
# whose slot 0 encodes nil. All `get(i)` return `Optional[T]`.

# Numeric AWO: `[LEB count][nil bitset ceil(count/8)][count fixed-width slots]`.
@fieldwise_init
struct NumOptArray[o: ImmOrigin, dt: DType, width: Int](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var base_nil: Int   # nil bitset start
    var base_data: Int  # element data start (= base_nil + ceil(count/8))
    var count: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> Optional[Scalar[Self.dt]]:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        if (self.buf.unsafe_ptr()[unsafe_offset=self.base_nil + (i >> 3)] >> UInt8(i & 7)) & 1:
            return None
        return (
            self.buf.unsafe_ptr().unsafe_offset(self.base_data + i * Self.width)
        ).unsafe_bitcast[Scalar[Self.dt]]().unsafe_load[alignment=1]()


# Bool AWO: `[LEB count][nil bitset][value bitset]` — value bitset indexed by i.
@fieldwise_init
struct BoolOptArray[o: ImmOrigin](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var base_nil: Int
    var base_val: Int   # value bitset start (= base_nil + ceil(count/8))
    var count: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> Optional[Bool]:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        if (self.buf.unsafe_ptr()[unsafe_offset=self.base_nil + (i >> 3)] >> UInt8(i & 7)) & 1:
            return None
        return ((self.buf.unsafe_ptr()[unsafe_offset=self.base_val + (i >> 3)] >> UInt8(i & 7)) & 1) != 0


# Sub-byte enum AWO: `[LEB count][nil bitset][value bitset]`, value bits indexed by
# i (UNCOMPACTED — regular/frozen). `bits` = 1/2/4.
@fieldwise_init
struct EnumBitOptArray[o: ImmOrigin, bits: Int](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var base_nil: Int
    var base_val: Int   # value payload start (= base_nil + ceil(count/8))
    var count: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> Optional[UInt8]:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        if (self.buf.unsafe_ptr()[unsafe_offset=self.base_nil + (i >> 3)] >> UInt8(i & 7)) & 1:
            return None
        var per_byte = 8 // Self.bits
        var byte = self.buf.unsafe_ptr()[unsafe_offset=self.base_val + i // per_byte]
        var shift = UInt8((i % per_byte) * Self.bits)
        var mask = UInt8((1 << Self.bits) - 1)
        return (byte >> shift) & mask


# Unsigned `es`-byte little-endian slot read (pointer-table array slots). utf8/data
# slots are unsigned (value offset); node-ref slots are signed (may point backward).
def read_rel_offset_u(buf: Span[UInt8, _], at: Int, es: Int) raises -> Int:
    var v: UInt64 = 0
    for k in range(es):
        v += UInt64(buf[at + k]) << UInt64(8 * k)
    return Int(v)


# Signed `es`-byte little-endian slot read — node-ref array slots are two's-
# complement so a slot can point backward to a shared/cyclic node. es ≤ 4 in
# practice (small graphs); the sign-extend guards bits < 64.
def read_rel_offset_s(buf: Span[UInt8, _], at: Int, es: Int) raises -> Int:
    var v = read_rel_offset_u(buf, at, es)
    var bits = 8 * es
    if bits < 64 and (v & (1 << (bits - 1))) != 0:
        v -= 1 << bits
    return v


# Pointer-table utf8 array (regular/frozen): `[LEB (count<<2)|wc][count × es-byte
# unsigned slots][element data]`, es = 1<<wc; element i at `base + slot[i] - 1`
# (slot 0 = nil, only in arrayWithOptionals). `table_base` = slot table start,
# `base` = element-data start. Zero-alloc: `get_slice` borrows, `get` owns.
@fieldwise_init
struct Utf8Array[o: ImmOrigin](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var table_base: Int
    var base: Int
    var count: Int
    var es: Int

    def __len__(self) -> Int:
        return self.count

    def _elem_pos(self, i: Int) raises -> Int:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        var ro = read_rel_offset_u(self.buf, self.table_base + i * self.es, self.es)
        return self.base + ro - 1  # required array: slot is never 0

    def get_slice(self, i: Int) raises -> StringSlice[Self.o]:
        return read_utf8(self.buf, self._elem_pos(i))[0]

    def get(self, i: Int) raises -> String:
        return String(self.get_slice(i))


# AWO pointer-table utf8 array: same geometry as Utf8Array but `slot[i] == 0`
# encodes a nil element → `get` returns `Optional`.
@fieldwise_init
struct Utf8OptArray[o: ImmOrigin](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var table_base: Int
    var base: Int
    var count: Int
    var es: Int

    def __len__(self) -> Int:
        return self.count

    def get_slice(self, i: Int) raises -> Optional[StringSlice[Self.o]]:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        var ro = read_rel_offset_u(self.buf, self.table_base + i * self.es, self.es)
        if ro == 0:
            return None
        return read_utf8(self.buf, self.base + ro - 1)[0]

    def get(self, i: Int) raises -> Optional[String]:
        var s = self.get_slice(i)
        if not s:
            return None
        return String(s.value())


# Pointer-table data array — same geometry as Utf8Array, `Span`/`List` elements.
@fieldwise_init
struct DataArray[o: ImmOrigin](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var table_base: Int
    var base: Int
    var count: Int
    var es: Int

    def __len__(self) -> Int:
        return self.count

    def _elem_pos(self, i: Int) raises -> Int:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        var ro = read_rel_offset_u(self.buf, self.table_base + i * self.es, self.es)
        return self.base + ro - 1

    def get_bytes(self, i: Int) raises -> Span[UInt8, Self.o]:
        return read_data(self.buf, self._elem_pos(i))[0]

    def get(self, i: Int) raises -> List[UInt8]:
        # Bulk-copy the element's bytes in one shot: `get_bytes` is a zero-copy Span
        # over contiguous storage, so reserve once + memcpy instead of a per-byte
        # append loop (which regrows the List → malloc churn per element).
        var b = self.get_bytes(i)
        var out = List[UInt8](unsafe_uninit_length=len(b))
        if len(b) > 0:
            unsafe_memcpy(dest=out.unsafe_ptr(), src=b.unsafe_ptr(), count=len(b))
        return out^


# AWO pointer-table data array: `slot[i] == 0` → nil element.
@fieldwise_init
struct DataOptArray[o: ImmOrigin](Copyable, Movable, ImplicitlyCopyable, Sized):
    var buf: Span[UInt8, Self.o]
    var table_base: Int
    var base: Int
    var count: Int
    var es: Int

    def __len__(self) -> Int:
        return self.count

    def get(self, i: Int) raises -> Optional[List[UInt8]]:
        if i < 0 or i >= self.count:
            raise Error("array index out of range")
        var ro = read_rel_offset_u(self.buf, self.table_base + i * self.es, self.es)
        if ro == 0:
            return None
        var b = read_data(self.buf, self.base + ro - 1)[0]
        var out = List[UInt8](unsafe_uninit_length=len(b))
        if len(b) > 0:
            unsafe_memcpy(dest=out.unsafe_ptr(), src=b.unsafe_ptr(), count=len(b))
        return out^


# Derive the root node's absolute offset from the framing word.
# framing LEB; bit 0 = custom-header flag (must be 0 for the spike),
# root = hdrBytes + (framing >> 2). Mirrors rootOffset in dagr_reader.ts.
def root_offset(buf: Span[UInt8, _]) raises -> Int:
    var r = read_leb(buf, 0)
    var framing = r[0]
    var hdr_bytes = r[1]
    if (framing & 1) != 0:
        raise Error("missingHeader")
    return hdr_bytes + Int(framing >> 2)
