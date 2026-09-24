from avro_wire.varint import varint_len
from avro_wire.zigzag import zigzag_encode_i32, zigzag_encode_i64


def zigzag_varint_len_i32(n: Int32) -> Int:
    return varint_len(UInt64(zigzag_encode_i32(n)))


def zigzag_varint_len_i64(n: Int64) -> Int:
    return varint_len(zigzag_encode_i64(n))


def bytes_len(n: Int) -> Int:
    return zigzag_varint_len_i64(Int64(n)) + n


def string_len(n: Int) -> Int:
    return bytes_len(n)
