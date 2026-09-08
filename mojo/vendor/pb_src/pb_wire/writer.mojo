from std.collections import List, Span

from pb_wire.types import WireType
from pb_wire.varint import append_varint


struct WireWriter(Movable):
    """Appends protobuf wire bytes into one `List[Byte]`."""

    var buf: List[Byte]

    def __init__(out self, *, capacity: Int = 64):
        self.buf = List[Byte](capacity=capacity)

    def write_byte(mut self, b: Byte):
        self.buf.append(b)

    def write_varint(mut self, value: UInt64):
        append_varint(self.buf, value)

    def write_tag(mut self, field: UInt32, wire: WireType):
        self.write_varint((UInt64(field) << 3) | UInt64(wire.value))

    def write_i32_le(mut self, bits: UInt32):
        comptime for i in range(4):
            self.write_byte(Byte((bits >> (UInt32(i) * 8)) & 0xFF))

    def write_i64_le(mut self, bits: UInt64):
        comptime for i in range(8):
            self.write_byte(Byte((bits >> (UInt64(i) * 8)) & 0xFF))

    def write_bytes[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        for i in range(len(data)):
            self.write_byte(data[i])

    def write_len_header(mut self, field: UInt32, payload_len: Int):
        self.write_tag(field, WireType.LEN)
        self.write_varint(UInt64(payload_len))

    def finish(deinit self) -> List[Byte]:
        return self.buf^
