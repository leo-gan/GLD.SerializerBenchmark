from avro_wire.reader import WireReader
from avro_wire.size import bytes_len, string_len, zigzag_varint_len_i32, zigzag_varint_len_i64
from avro_wire.varint import decode_varint, encode_varint, varint_len
from avro_wire.writer import WireWriter
from avro_wire.zigzag import (
    zigzag_decode_i32,
    zigzag_decode_i64,
    zigzag_encode_i32,
    zigzag_encode_i64,
)
