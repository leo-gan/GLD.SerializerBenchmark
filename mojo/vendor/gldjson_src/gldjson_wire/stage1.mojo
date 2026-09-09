from std.collections import List, Span
from std.memory.unsafe import pack_bits

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import DecodeOptions


def ensure_index[
    origin: ImmOrigin
](data: Span[Byte, origin], mut positions: List[UInt32]) raises DecodeError:
    """Record offsets of `{ } [ ] : , "`. Not used on the generated hot path."""
    _ = DecodeOptions.default
    if len(positions) > 0:
        return
    var n = len(data)
    var i = 0
    var ptr = data.unsafe_ptr()
    var open_b = SIMD[DType.uint8, 16](123)
    var close_b = SIMD[DType.uint8, 16](125)
    var open_a = SIMD[DType.uint8, 16](91)
    var close_a = SIMD[DType.uint8, 16](93)
    var colon = SIMD[DType.uint8, 16](58)
    var comma = SIMD[DType.uint8, 16](44)
    var quote = SIMD[DType.uint8, 16](34)
    while i + 16 <= n:
        var chunk = ptr.load[width=16](i)
        var hit = (
            chunk.eq(open_b)
            .__or__(chunk.eq(close_b))
            .__or__(chunk.eq(open_a))
            .__or__(chunk.eq(close_a))
            .__or__(chunk.eq(colon))
            .__or__(chunk.eq(comma))
            .__or__(chunk.eq(quote))
        )
        var bits = Int(pack_bits(hit))
        var off = 0
        var b = bits
        while off < 16:
            if (b & 1) != 0:
                positions.append(UInt32(i + off))
            b >>= 1
            off += 1
        i += 16
    while i < n:
        var c = Int(data[i])
        if (
            c == 123
            or c == 125
            or c == 91
            or c == 93
            or c == 58
            or c == 44
            or c == 34
        ):
            positions.append(UInt32(i))
        i += 1
