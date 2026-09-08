def zigzag_encode_i32(n: Int32) -> UInt32:
    """Protobuf ZigZag for sint32. `>>` on Int32 is arithmetic."""
    return UInt32((n << 1) ^ (n >> 31))


def zigzag_decode_i32(n: UInt32) -> Int32:
    return Int32((n >> 1) ^ UInt32(Int32(0) - Int32(n & 1)))


def zigzag_encode_i64(n: Int64) -> UInt64:
    return UInt64((n << 1) ^ (n >> 63))


def zigzag_decode_i64(n: UInt64) -> Int64:
    return Int64((n >> 1) ^ UInt64(Int64(0) - Int64(n & 1)))
