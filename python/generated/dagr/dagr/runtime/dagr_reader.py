"""Dagr reflective wire runtime — reader primitives (pure Python, Phase 0).

Ported from the reference runtimes (`targets/typescript/src/dagr_reader.ts`,
`targets/mojo/src/dagr_reader.mojo`) — themselves ported byte-for-byte from the
Swift/Rust generated `DagrRuntime`. Position-passing free functions over a
`memoryview`, mirroring the Swift/Rust getters 1:1 (the biggest bug-reducer for a
fixture-gated port).

Python simplifications vs. the other targets (plan §8.1):
  * **One `read_leb` for every width** — Python `int` is arbitrary-precision, so the
    JS number/BigInt (and Swift/Rust 32/64) split collapses to a single path.
  * **`f16` is native** via `struct.unpack('<e', …)` — no hand-rolled bit-twiddling
    (the TS plan spent two phases on those); only `bf16` needs a manual widen.
  * Fixed-width scalars via `struct.unpack_from` on the same `memoryview` (zero-copy).

Convention: readers take `(mv, pos)` and — for the variable-width primitives — return
`(value, new_pos)`, threading the cursor. Fixed-width readers take `(mv, pos)` and
return just the value (their width is implied by the call site, as in every target).
"""
import struct


class DagrError(Exception):
    """Wire-decode failure (out-of-bounds read, malformed varint, …)."""


# ── LEB128 / ZigZag ──────────────────────────────────────────────────────────

def read_leb(mv, pos):
    """Unsigned LEB128 varint → ``(value, new_pos)``. A single path for all widths
    (Python ints are unbounded, so no 32/64 split)."""
    if pos < 0:
        raise DagrError("outsideOfBuffer")
    result = 0
    shift = 0
    n = len(mv)
    while True:
        if pos >= n:
            raise DagrError("outsideOfBuffer")
        b = mv[pos]
        result |= (b & 0x7F) << shift
        shift += 7
        pos += 1
        if b >> 7 == 0:
            break
    return result, pos


def zigzag_decode(n):
    """ZigZag → signed. ``(n >> 1) ^ -(n & 1)`` (Python's ``>>`` is arithmetic, and
    ``int`` is unbounded, so this is exact for i64 and beyond)."""
    return (n >> 1) ^ -(n & 1)


def read_zigzag_leb(mv, pos):
    """Signed LEB128 (ZigZag) → ``(value, new_pos)``."""
    raw, p = read_leb(mv, pos)
    return zigzag_decode(raw), p


# ── V62 bidirectional pointer ────────────────────────────────────────────────

def read_v62(mv, pos):
    """V62 pointer → ``(value, new_pos)``. Low 2 bits select width
    (0→1B, 1→2B, 2→4B, 3→8B); value = raw >> 2."""
    if pos < 0 or pos >= len(mv):
        raise DagrError("outsideOfBuffer")
    code = mv[pos] & 3
    if code == 0:
        return mv[pos] >> 2, pos + 1
    if code == 1:
        return struct.unpack_from("<H", mv, pos)[0] >> 2, pos + 2
    if code == 2:
        return struct.unpack_from("<I", mv, pos)[0] >> 2, pos + 4
    return struct.unpack_from("<Q", mv, pos)[0] >> 2, pos + 8


def read_zigzag_v62(mv, pos):
    """Signed (ZigZag) V62 pointer → ``(value, new_pos)``."""
    raw, p = read_v62(mv, pos)
    return zigzag_decode(raw), p


# ── Framing word (graph header) ──────────────────────────────────────────────

def read_framing(mv):
    """Decode the framing word at buffer position 0.

    Returns ``(root_start, kind, has_header)`` where ``kind`` is 0 for a DataGraph
    and 1 for a DataSink, and ``has_header`` is 1 when a customizable header block
    (spec 15) follows. Layout (authoritative, per the explain generators):
    ``framing`` is a LEB; ``root_off = framing >> 2``; ``kind = (framing >> 1) & 1``;
    ``header = framing & 1``; ``root_start = leb_len + root_off`` (no custom header).
    """
    framing, p = read_leb(mv, 0)
    root_off = framing >> 2
    kind = (framing >> 1) & 1
    has_header = framing & 1
    return p + root_off, kind, has_header


# ── Regular-node vtable ──────────────────────────────────────────────────────

def restore_vtable(mv, start):
    """Parse a regular (vtable) node header at ``start``.

    Returns a list of per-field **absolute** buffer positions (``None`` = field
    absent). Mirrors ``restoreRTypeVTable`` in the runtime:
      * the LEB at ``start`` is the ZigZag pointer to the vtable; even → a
        deduplicated forward-ref (apply the ``+b1`` off-by-one), odd → fresh vtable;
      * the vtable header LEB is ``(fieldCount << 1) | wideFlag`` (wide → 16-bit
        entries);
      * each entry: 0 → absent, else ``start + (stored - 1) + b1``.
    """
    off_val, p = read_leb(mv, start)
    b1 = p - start
    adj = b1 if (off_val & 1) == 0 else 0
    vt_start = start + zigzag_decode(off_val) + adj
    vt_size, cursor = read_leb(mv, vt_start)
    count = vt_size >> 1
    wide = (vt_size & 1) != 0
    fields = []
    for _ in range(count):
        if wide:
            v = struct.unpack_from("<H", mv, cursor)[0]
            cursor += 2
        else:
            v = mv[cursor]
            cursor += 1
        fields.append(None if v == 0 else start + (v - 1) + b1)
    return fields


# ── Fixed-width scalar reads (regular/frozen node `restore` path — native LE) ──
# In a regular (vtable) or frozen node, scalars are stored native little-endian at a
# fixed width (packed nodes LEB-encode via a separate path — a Phase 1 fork). These
# mirror the UIntN/IntN `restore(from:at:)` extensions.

def read_u8(mv, p):
    return mv[p]


def read_u16(mv, p):
    return struct.unpack_from("<H", mv, p)[0]


def read_u32(mv, p):
    return struct.unpack_from("<I", mv, p)[0]


def read_u64(mv, p):
    return struct.unpack_from("<Q", mv, p)[0]


def read_i8(mv, p):
    return struct.unpack_from("<b", mv, p)[0]


def read_i16(mv, p):
    return struct.unpack_from("<h", mv, p)[0]


def read_i32(mv, p):
    return struct.unpack_from("<i", mv, p)[0]


def read_i64(mv, p):
    return struct.unpack_from("<q", mv, p)[0]


def read_f32(mv, p):
    return struct.unpack_from("<f", mv, p)[0]


def read_f64(mv, p):
    return struct.unpack_from("<d", mv, p)[0]


def read_f16(mv, p):
    # Native IEEE half — a Python win (`<e` exists since 3.6).
    return struct.unpack_from("<e", mv, p)[0]


def read_bf16(mv, p):
    # bf16 is the high 16 bits of an f32: zero-extend and reinterpret.
    bits = struct.unpack_from("<H", mv, p)[0]
    return struct.unpack("<f", struct.pack("<I", bits << 16))[0]


def read_bool(mv, p):
    return mv[p] != 0


# ── Packed-float decode (self-describing sub-tag scheme) ─────────────────────
# Sub-tags: 00 +0, 01 -0, 02 +inf, 03 -inf, 04 NaN, 05 zigzag-LEB int,
#   06 f16 bits (2B), 07 f32 (4B), 08 f64 (8B, f64 only). Returns (value, bytes).

_INF = float("inf")
_NAN = float("nan")


def decode_packed_float32(mv, at):
    if at < 0 or at >= len(mv):
        raise DagrError("outsideOfBuffer")
    tag = mv[at]
    if tag == 0x00:
        return 0.0, 1
    if tag == 0x01:
        return -0.0, 1
    if tag == 0x02:
        return _INF, 1
    if tag == 0x03:
        return -_INF, 1
    if tag == 0x04:
        return _NAN, 1
    if tag == 0x05:
        zz, b = read_leb(mv, at + 1)
        return float(zigzag_decode(zz)), 1 + (b - (at + 1))
    if tag == 0x06:
        return read_f16(mv, at + 1), 3
    if tag == 0x07:
        return read_f32(mv, at + 1), 5
    return 0.0, 1


def decode_packed_float64(mv, at):
    if at < 0 or at >= len(mv):
        raise DagrError("outsideOfBuffer")
    tag = mv[at]
    if tag == 0x05:
        zz, b = read_leb(mv, at + 1)
        return float(zigzag_decode(zz)), 1 + (b - (at + 1))
    if tag == 0x08:
        return read_f64(mv, at + 1), 9
    return decode_packed_float32(mv, at)   # tags 0..4, 6, 7 identical (f32 widens to f64)


def decode_packed_f16(mv, at):
    """Packed f16/bf16: only the special-value sub-tags (1 byte); normal values are
    stored raw (the writer sets the raw flag), never through this path."""
    if at < 0 or at >= len(mv):
        raise DagrError("outsideOfBuffer")
    tag = mv[at]
    if tag == 0x01:
        return -0.0, 1
    if tag == 0x02:
        return _INF, 1
    if tag == 0x03:
        return -_INF, 1
    if tag == 0x04:
        return _NAN, 1
    return 0.0, 1


def read_utf8(mv, pos):
    """A length-prefixed UTF-8 string: ``[LEB len][bytes]`` → ``(str, new_pos)``."""
    n, p = read_leb(mv, pos)
    return bytes(mv[p:p + n]).decode("utf-8"), p + n


def read_data(mv, pos):
    """A length-prefixed blob: ``[LEB len][bytes]`` → ``(bytes, new_pos)``."""
    n, p = read_leb(mv, pos)
    return bytes(mv[p:p + n]), p + n
