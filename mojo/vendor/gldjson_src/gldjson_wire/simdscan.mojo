from std.bit import count_trailing_zeros
from std.collections import Span
from std.memory.unsafe import pack_bits


comptime SCAN_W = 16


def _first_set(bits: Int) -> Int:
    """EmberJson / simdjson: ctz, not a 16-step scalar walk."""
    if bits == 0:
        return SCAN_W
    return Int(count_trailing_zeros(UInt32(bits)))


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


def scan_plain_string[
    origin: ImmOrigin
](data: Span[Byte, origin], start: Int, mut ascii: Bool) -> Int:
    """Quote/escape/control index. Sets `ascii` False on any byte >= 128.

    SIMD first when 16 bytes remain (mid-object always does). Scalar-first-16
    was slower on the official strings suite.
    """
    ascii = True
    var n = len(data)
    var i = start
    var ptr = data.unsafe_ptr()
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


def needs_escape_bytes[origin: ImmOrigin](data: Span[Byte, origin]) -> Bool:
    var n = len(data)
    var i = 0
    var ptr = data.unsafe_ptr()
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
