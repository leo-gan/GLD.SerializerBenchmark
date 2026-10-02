from std.bit import count_trailing_zeros
from std.collections import Span
from std.memory.unsafe import pack_bits
from std.sys import simd_width_of


comptime SCAN_W = simd_width_of[DType.uint8]()


@always_inline
def _first_set(bits: Int) -> Int:
    """EmberJson / simdjson: ctz, not a 16-step scalar walk."""
    if bits == 0:
        return SCAN_W
    return Int(count_trailing_zeros(UInt64(bits)))


@always_inline
def skip_ws_span[origin: ImmOrigin](data: Span[Byte, origin], mut pos: Int):
    """Advance `pos` over space / tab / LF / CR. Compact JSON returns in one load."""
    var n = len(data)
    if pos >= n:
        return
    var c0 = Int(data[pos])
    if c0 != 32 and c0 != 9 and c0 != 10 and c0 != 13:
        return
    var ptr = data.unsafe_ptr()
    while pos + SCAN_W <= n:
        var chunk = ptr.unsafe_load[width=SCAN_W](pos)
        var non = (
            chunk.ne(SIMD[DType.uint8, SCAN_W](32))
            .__and__(chunk.ne(SIMD[DType.uint8, SCAN_W](9)))
            .__and__(chunk.ne(SIMD[DType.uint8, SCAN_W](10)))
            .__and__(chunk.ne(SIMD[DType.uint8, SCAN_W](13)))
        )
        var bits = Int(pack_bits(non))
        if bits == 0:
            pos += SCAN_W
            continue
        pos += _first_set(bits)
        return
    while pos < n:
        var c = Int(data[pos])
        if c != 32 and c != 9 and c != 10 and c != 13:
            return
        pos += 1


def first_escape_or_quote[origin: ImmOrigin](data: Span[Byte, origin], start: Int) -> Int:
    """Index of the first `"`, `\\`, or control byte at or after `start`.
    Returns `len(data)` if none (caller treats that as EOF)."""
    var ascii = True
    return scan_plain_string(data, start, ascii)


@always_inline
def _special_mask_8(w: UInt64) -> UInt64:
    """High bit per byte that is `"`, `\\`, or < 32. simdjson haszero / hasless."""
    var q = w ^ UInt64(0x2222222222222222)
    var qz = (q - UInt64(0x0101010101010101)) & ~q & UInt64(0x8080808080808080)
    var b = w ^ UInt64(0x5C5C5C5C5C5C5C5C)
    var bz = (b - UInt64(0x0101010101010101)) & ~b & UInt64(0x8080808080808080)
    var hl = (w - UInt64(0x2020202020202020)) & ~w & UInt64(0x8080808080808080)
    return qz | bz | hl


@always_inline
def scan_plain_string[
    origin: ImmOrigin
](data: Span[Byte, origin], start: Int, mut ascii: Bool) -> Int:
    """Quote/escape/control index. Sets `ascii` False on any byte >= 128.

    An 8-byte probe runs first so a short string does not pay for a full SIMD
    chunk when the closing quote is inside those eight bytes. A miss falls
    through to the SIMD scan.
    """
    ascii = True
    var n = len(data)
    var i = start
    var ptr = data.unsafe_ptr()
    if i + 8 <= n:
        var w = ptr.unsafe_offset(i).unsafe_bitcast[UInt64]()[]
        var special = _special_mask_8(w)
        var nonascii = w & UInt64(0x8080808080808080)
        if special != 0:
            var rel = Int(count_trailing_zeros(special)) // 8
            var content = (UInt64(1) << UInt64(rel * 8)) - UInt64(1)
            if (nonascii & content) != 0:
                ascii = False
            return i + rel
        if nonascii != 0:
            ascii = False
        i += 8
    var q = SIMD[DType.uint8, SCAN_W](34)
    var sl = SIMD[DType.uint8, SCAN_W](92)
    var thirty_two = SIMD[DType.uint8, SCAN_W](32)
    var high = SIMD[DType.uint8, SCAN_W](128)
    while i + SCAN_W <= n:
        var chunk = ptr.unsafe_load[width=SCAN_W](i)
        if Int(pack_bits(chunk.ge(high))) != 0:
            ascii = False
        var hit = chunk.eq(q).__or__(chunk.eq(sl)).__or__(chunk.lt(thirty_two))
        var bits = Int(pack_bits(hit))
        if bits != 0:
            return i + _first_set(bits)
        i += SCAN_W
    while i < n:
        var c = Int(data[i])
        if c >= 128:
            ascii = False
        if c == 34 or c == 92 or c < 32:
            return i
        i += 1
    return n


@always_inline
def needs_escape_bytes[origin: ImmOrigin](data: Span[Byte, origin]) -> Bool:
    var n = len(data)
    var i = 0
    var ptr = data.unsafe_ptr()
    if n < SCAN_W:
        while i < n:
            var c = Int(ptr.unsafe_offset(i)[])
            if c < 32 or c == 34 or c == 92:
                return True
            i += 1
        return False
    var q = SIMD[DType.uint8, SCAN_W](34)
    var sl = SIMD[DType.uint8, SCAN_W](92)
    var thirty_two = SIMD[DType.uint8, SCAN_W](32)
    while i + SCAN_W <= n:
        var chunk = ptr.unsafe_load[width=SCAN_W](i)
        var hit = chunk.eq(q).__or__(chunk.eq(sl)).__or__(chunk.lt(thirty_two))
        if Int(pack_bits(hit)) != 0:
            return True
        i += SCAN_W
    while i < n:
        var c = Int(data[i])
        if c < 32 or c == 34 or c == 92:
            return True
        i += 1
    return False
