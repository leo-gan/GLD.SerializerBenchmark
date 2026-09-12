from std.bit import count_trailing_zeros
from std.collections import Span
from std.memory.unsafe import pack_bits
from std.sys import simd_width_of


comptime SCAN_W = simd_width_of[DType.uint8]()


@always_inline
def _first_set(bits: Int) -> Int:
    if bits == 0:
        return SCAN_W
    return Int(count_trailing_zeros(UInt64(bits)))


@always_inline
def scan_until[
    origin: ImmOrigin
](data: Span[Byte, origin], start: Int, a: Int, b: Int, c: Int) -> Int:
    """First index at or after `start` equal to `a`, `b`, or `c`. Else `len`."""
    var n = len(data)
    var i = start
    var ptr = data.unsafe_ptr()
    var va = SIMD[DType.uint8, SCAN_W](UInt8(a))
    var vb = SIMD[DType.uint8, SCAN_W](UInt8(b))
    var vc = SIMD[DType.uint8, SCAN_W](UInt8(c))
    while i + SCAN_W <= n:
        var chunk = ptr.unsafe_load[width=SCAN_W](i)
        var hit = chunk.eq(va).__or__(chunk.eq(vb)).__or__(chunk.eq(vc))
        var bits = Int(pack_bits(hit))
        if bits != 0:
            return i + _first_set(bits)
        i += SCAN_W
    while i < n:
        var v = Int(data[i])
        if v == a or v == b or v == c:
            return i
        i += 1
    return n


@always_inline
def scan_comment_or_break[origin: ImmOrigin](data: Span[Byte, origin], start: Int) -> Int:
    """First `#`, LF, or CR at or after `start`."""
    return scan_until(data, start, 35, 10, 13)


@always_inline
def scan_plain_stop[origin: ImmOrigin](data: Span[Byte, origin], start: Int) -> Int:
    """First LF, CR, or `#` at or after `start` (plain scalar line stop)."""
    return scan_until(data, start, 10, 13, 35)


@always_inline
def scan_dquote[origin: ImmOrigin](data: Span[Byte, origin], start: Int) -> Int:
    """First `"`, `\\`, or control (< 32) at or after `start`."""
    var n = len(data)
    var i = start
    var ptr = data.unsafe_ptr()
    var q = SIMD[DType.uint8, SCAN_W](34)
    var sl = SIMD[DType.uint8, SCAN_W](92)
    var thirty_two = SIMD[DType.uint8, SCAN_W](32)
    while i + SCAN_W <= n:
        var chunk = ptr.unsafe_load[width=SCAN_W](i)
        var hit = chunk.eq(q).__or__(chunk.eq(sl)).__or__(chunk.lt(thirty_two))
        var bits = Int(pack_bits(hit))
        if bits != 0:
            return i + _first_set(bits)
        i += SCAN_W
    while i < n:
        var c = Int(data[i])
        if c == 34 or c == 92 or c < 32:
            return i
        i += 1
    return n
