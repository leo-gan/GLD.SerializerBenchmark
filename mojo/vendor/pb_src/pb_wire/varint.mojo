from std.bit import count_leading_zeros
from std.collections import List, Span

from pb_runtime.error import DecodeError


@always_inline
def append_varint(mut buf: List[Byte], value: UInt64):
    """Append an unsigned LEB128 varint to `buf`."""
    var v = value
    while v > 127:
        buf.append(Byte((v & 0x7F) | 0x80))
        v >>= UInt64(7)
    buf.append(Byte(v & 0x7F))


@always_inline
def encode_varint(value: UInt64) -> List[Byte]:
    var buf = List[Byte](capacity=10)
    append_varint(buf, value)
    return buf^


@always_inline
def read_varint_at[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> UInt64:
    """Read a varint starting at `pos`. Advances `pos`. Rejects overlong forms."""
    var n = len(data)
    var i = pos
    if i >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i)

    # One-byte tags and small integers are the common case. Unsafe loads avoid
    # a bounds check on every continuation byte after the length test above.
    var b0 = UInt64(data.unsafe_get(i))
    if b0 < 0x80:
        pos = i + 1
        return b0
    if i + 1 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 1)
    var b1 = UInt64(data.unsafe_get(i + 1))
    var result: UInt64 = (b0 & 0x7F) | ((b1 & 0x7F) << 7)
    if b1 < 0x80:
        pos = i + 2
        return result

    if i + 2 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 2)
    var b2 = UInt64(data.unsafe_get(i + 2))
    result |= (b2 & 0x7F) << 14
    if b2 < 0x80:
        pos = i + 3
        return result

    if i + 3 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 3)
    var b3 = UInt64(data.unsafe_get(i + 3))
    result |= (b3 & 0x7F) << 21
    if b3 < 0x80:
        pos = i + 4
        return result

    if i + 4 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 4)
    var b4 = UInt64(data.unsafe_get(i + 4))
    result |= (b4 & 0x7F) << 28
    if b4 < 0x80:
        pos = i + 5
        return result

    if i + 5 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 5)
    var b5 = UInt64(data.unsafe_get(i + 5))
    result |= (b5 & 0x7F) << 35
    if b5 < 0x80:
        pos = i + 6
        return result

    if i + 6 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 6)
    var b6 = UInt64(data.unsafe_get(i + 6))
    result |= (b6 & 0x7F) << 42
    if b6 < 0x80:
        pos = i + 7
        return result

    if i + 7 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 7)
    var b7 = UInt64(data.unsafe_get(i + 7))
    result |= (b7 & 0x7F) << 49
    if b7 < 0x80:
        pos = i + 8
        return result

    if i + 8 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 8)
    var b8 = UInt64(data.unsafe_get(i + 8))
    result |= (b8 & 0x7F) << 56
    if b8 < 0x80:
        pos = i + 9
        return result

    if i + 9 >= n:
        raise DecodeError(DecodeError.KIND_TRUNCATED, i + 9)
    var b9 = UInt64(data.unsafe_get(i + 9))
    # 10th byte: only payload bit 0 is in range; continuation is overflow.
    if b9 > 1:
        raise DecodeError(DecodeError.KIND_OVERFLOW, i + 9)
    pos = i + 10
    return result | (b9 << 63)


@always_inline
def decode_varint[
    origin: ImmOrigin
](data: Span[Byte, origin]) raises DecodeError -> UInt64:
    var pos = 0
    return read_varint_at(data, pos)


@always_inline
def varint_len(value: UInt64) -> Int:
    # 7 payload bits per byte. clz(0) == 64, which would round down to 0.
    var bits = 64 - Int(count_leading_zeros(value))
    if bits == 0:
        return 1
    return (bits + 6) // 7
