from pb_wire.varint import varint_len


@always_inline
def tag_len(field: UInt32) -> Int:
    return varint_len(UInt64(field) << 3)


@always_inline
def tag_varint_len(field: UInt32, value: UInt64) -> Int:
    return tag_len(field) + varint_len(value)


@always_inline
def tag_fixed32_len(field: UInt32) -> Int:
    return tag_len(field) + 4


@always_inline
def tag_fixed64_len(field: UInt32) -> Int:
    return tag_len(field) + 8


@always_inline
def tag_len_len(field: UInt32, payload_len: Int) -> Int:
    return tag_len(field) + varint_len(UInt64(payload_len)) + payload_len


@always_inline
def i32_to_u64(v: Int32) -> UInt64:
    """Sign-extend proto3 int32 so negatives encode as 10-byte varints."""
    return UInt64(Int64(v))


@always_inline
def i64_to_u64(v: Int64) -> UInt64:
    return UInt64(v)


@always_inline
def u64_to_i32(v: UInt64) -> Int32:
    """Low 32 bits, two's-complement. Not a checked conversion."""
    return Int32(UInt32(v))


@always_inline
def u64_to_i64(v: UInt64) -> Int64:
    return Int64(v)
