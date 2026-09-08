from std.collections import List, Span

from cbor_runtime.error import DecodeError


comptime AI_INDEF = 31
comptime MAX_ITEM_BYTES = 64_194_304
comptime MAX_COUNT = 1_048_576
comptime MAX_DEPTH = 100


def head_byte(major: Int, ai: Int) -> Byte:
    return Byte((major << 5) | ai)


def shortest_ai(argument: UInt64) -> Int:
    if argument < UInt64(24):
        return Int(argument)
    if argument < UInt64(256):
        return 24
    if argument < UInt64(65536):
        return 25
    if argument < (UInt64(1) << UInt64(32)):
        return 26
    return 27


def extra_len(ai: Int) -> Int:
    if ai < 24:
        return 0
    if ai == 24:
        return 1
    if ai == 25:
        return 2
    if ai == 26:
        return 4
    if ai == 27:
        return 8
    return 0


def encoded_head_len(argument: UInt64) -> Int:
    return 1 + extra_len(shortest_ai(argument))


def encoded_uint_len(v: UInt64) -> Int:
    return encoded_head_len(v)


def encoded_int_len(v: Int64) -> Int:
    if v >= Int64(0):
        return encoded_head_len(UInt64(v))
    return encoded_head_len(UInt64(-(v + Int64(1))))


def encoded_bytes_len(n: Int) -> Int:
    return encoded_head_len(UInt64(n)) + n


def encoded_tstr_len(n: Int) -> Int:
    return encoded_bytes_len(n)


def encoded_bstr_len(n: Int) -> Int:
    return encoded_bytes_len(n)


def append_be(mut buf: List[Byte], argument: UInt64, n: Int):
    var i = n
    while i > 0:
        i -= 1
        var shift = UInt64(i) * UInt64(8)
        buf.append(Byte((argument >> shift) & UInt64(0xFF)))


def write_head(mut buf: List[Byte], major: Int, argument: UInt64):
    var ai = shortest_ai(argument)
    buf.append(head_byte(major, ai))
    append_be(buf, argument, extra_len(ai))


def write_head_raw(mut buf: List[Byte], major: Int, ai: Int, argument: UInt64):
    buf.append(head_byte(major, ai))
    append_be(buf, argument, extra_len(ai))


def write_break(mut buf: List[Byte]):
    buf.append(Byte(0xFF))


def read_be[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int, n: Int) raises DecodeError -> UInt64:
    if pos + n > len(data):
        raise DecodeError(DecodeError.KIND_EOF, pos)
    var value: UInt64 = 0
    for i in range(n):
        value = (value << UInt64(8)) | UInt64(data[pos + i])
    pos += n
    return value


def read_head[
    origin: ImmOrigin
](data: Span[Byte, origin], mut pos: Int) raises DecodeError -> Tuple[Int, UInt64, Int]:
    if pos >= len(data):
        raise DecodeError(DecodeError.KIND_EOF, pos)
    var at = pos
    var b = Int(data[pos])
    pos += 1
    var major = b >> 5
    var ai = b & 0x1F
    if ai >= 28 and ai <= 30:
        raise DecodeError(DecodeError.KIND_RESERVED_AI, at)
    if ai == AI_INDEF:
        return (major, UInt64(0), ai)
    if ai < 24:
        return (major, UInt64(ai), ai)
    var n = extra_len(ai)
    if n == 0:
        raise DecodeError(DecodeError.KIND_RESERVED_AI, at)
    var arg = read_be(data, pos, n)
    if major == 7 and ai == 24 and arg < UInt64(32):
        raise DecodeError(DecodeError.KIND_SIMPLE, at)
    return (major, arg, ai)
