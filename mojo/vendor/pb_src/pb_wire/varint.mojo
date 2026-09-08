from std.collections import List, Span

from pb_runtime.error import DecodeError


def append_varint(mut buf: List[Byte], value: UInt64):
    """Append an unsigned LEB128 varint to `buf`."""
    var v = value
    while v > 127:
        buf.append(Byte((v & 0x7F) | 0x80))
        v >>= UInt64(7)
    buf.append(Byte(v & 0x7F))


def encode_varint(value: UInt64) -> List[Byte]:
    var buf = List[Byte](capacity=10)
    append_varint(buf, value)
    return buf^


def read_varint_at[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> UInt64:
    """Read a varint starting at `pos`. Advances `pos`. Rejects overlong forms."""
    var result: UInt64 = 0
    var shift: Int = 0
    var i: Int = 0
    while i < 10:
        if pos >= len(data):
            raise DecodeError(DecodeError.KIND_TRUNCATED, pos)
        var b = UInt64(data[pos])
        var at = pos
        pos += 1
        if i == 9:
            # 10th byte: only payload bit 0 is in range; continuation is overflow.
            if b > 1:
                raise DecodeError(DecodeError.KIND_OVERFLOW, at)
            result |= b << UInt64(63)
            return result
        result |= (b & 0x7F) << UInt64(shift)
        if (b & 0x80) == 0:
            return result
        shift += 7
        i += 1
    raise DecodeError(DecodeError.KIND_OVERFLOW, pos)


def decode_varint[
    origin: ImmOrigin
](data: Span[Byte, origin]) raises DecodeError -> UInt64:
    var pos = 0
    return read_varint_at(data, pos)


def varint_len(value: UInt64) -> Int:
    var v = value
    var n = 1
    while v > 127:
        v >>= UInt64(7)
        n += 1
    return n
