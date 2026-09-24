from std.collections import Span


def load_u16[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) -> UInt16:
    """Little-endian load. The caller has checked the range. x86-64 allows the unaligned address."""
    return data.unsafe_ptr().unsafe_offset(pos).unsafe_bitcast[UInt16]()[]


def load_u32[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) -> UInt32:
    """Little-endian load. The caller has checked the range. x86-64 allows the unaligned address."""
    return data.unsafe_ptr().unsafe_offset(pos).unsafe_bitcast[UInt32]()[]


def load_u64[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) -> UInt64:
    """Little-endian load. The caller has checked the range. x86-64 allows the unaligned address."""
    return data.unsafe_ptr().unsafe_offset(pos).unsafe_bitcast[UInt64]()[]


def read_u8[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> UInt8:
    if pos < 0 or pos >= len(data):
        raise Error("truncated")
    return UInt8(data[pos])


def read_u16[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> UInt16:
    if pos < 0 or pos + 2 > len(data):
        raise Error("truncated")
    return load_u16(data, pos)


def read_u32[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> UInt32:
    if pos < 0 or pos + 4 > len(data):
        raise Error("truncated")
    return load_u32(data, pos)


def read_u64[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> UInt64:
    if pos < 0 or pos + 8 > len(data):
        raise Error("truncated")
    return load_u64(data, pos)


def read_i8[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int8:
    return Int8(read_u8(data, pos))


def read_i16[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int16:
    return Int16(read_u16(data, pos))


def read_i32[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int32:
    return Int32(read_u32(data, pos))


def read_i64[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Int64:
    return Int64(read_u64(data, pos))


def read_f32[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Float32:
    return Float32(from_bits=read_u32(data, pos))


def read_f64[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Float64:
    return Float64(from_bits=read_u64(data, pos))


def read_bool[origin: ImmOrigin](data: Span[Byte, origin], pos: Int) raises -> Bool:
    return read_u8(data, pos) != 0


def int_from_i32(v: Int32) -> Int:
    """Sign-extend an Int32. A direct `Int(read_i32(...))` zero-extends."""
    var bits = UInt32(v)
    if bits >= UInt32(2147483648):
        return Int(bits) - 4294967296
    return Int(bits)


def int_from_i16(v: Int16) -> Int:
    return Int(v)


def int_from_i8(v: Int8) -> Int:
    return Int(v)
