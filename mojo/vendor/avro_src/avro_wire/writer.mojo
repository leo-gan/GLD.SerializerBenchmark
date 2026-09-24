from std.collections import List, Span

from avro_wire.varint import append_varint
from avro_wire.zigzag import zigzag_encode_i32, zigzag_encode_i64


struct WireWriter(Movable):
    """Appends Avro binary bytes into one `List[Byte]`."""

    var buf: List[Byte]

    def __init__(out self, *, capacity: Int = 64):
        self.buf = List[Byte](capacity=capacity)

    def write_byte(mut self, b: Byte):
        self.buf.append(b)

    def write_varint(mut self, value: UInt64):
        append_varint(self.buf, value)

    def write_bool(mut self, v: Bool):
        if v:
            self.write_byte(Byte(1))
        else:
            self.write_byte(Byte(0))

    def write_int(mut self, v: Int32):
        self.write_varint(UInt64(zigzag_encode_i32(v)))

    def write_long(mut self, v: Int64):
        self.write_varint(zigzag_encode_i64(v))

    def write_float(mut self, v: Float32):
        var bits = UInt32(v.to_bits())
        comptime for i in range(4):
            self.write_byte(Byte((bits >> (UInt32(i) * 8)) & 0xFF))

    def write_double(mut self, v: Float64):
        var bits = UInt64(v.to_bits())
        comptime for i in range(8):
            self.write_byte(Byte((bits >> (UInt64(i) * 8)) & 0xFF))

    def write_bytes[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        self.write_long(Int64(len(data)))
        for i in range(len(data)):
            self.write_byte(data[i])

    def write_string(mut self, v: String):
        self.write_bytes(v.as_bytes())

    def write_fixed[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        for i in range(len(data)):
            self.write_byte(data[i])

    def write_block_start(mut self, count: Int64):
        self.write_long(count)

    def write_block_end(mut self):
        self.write_long(0)

    def finish(deinit self) -> List[Byte]:
        return self.buf^
