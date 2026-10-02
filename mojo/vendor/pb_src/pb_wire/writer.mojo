from std.collections import List, Span
from std.memory import Pointer, unsafe_memcpy
from std.sys import is_little_endian

from pb_wire.types import WireType
from pb_wire.varint import append_varint


struct WireWriter(Movable):
    """Appends protobuf wire bytes into one `List[Byte]`."""

    var buf: List[Byte]

    def __init__(out self, *, capacity: Int = 64):
        self.buf = List[Byte](capacity=capacity)

    @always_inline
    def write_byte(mut self, b: Byte):
        self.buf.append(b)

    @always_inline
    def write_varint(mut self, value: UInt64):
        append_varint(self.buf, value)

    @always_inline
    def write_tag(mut self, field: UInt32, wire: WireType):
        self.write_varint((UInt64(field) << 3) | UInt64(wire.value))

    @always_inline
    def write_i32_le(mut self, bits: UInt32):
        # Protobuf fixed32 is little-endian; one copy beats four appends.
        if is_little_endian():
            var native = bits
            var start = len(self.buf)
            self.buf.resize(unsafe_uninit_length=start + 4)
            unsafe_memcpy(
                dest=self.buf.unsafe_ptr().unsafe_offset(start),
                src=Pointer(to=native).unsafe_bitcast[Byte](),
                count=4,
            )
            return
        comptime for i in range(4):
            self.write_byte(Byte((bits >> (UInt32(i) * 8)) & 0xFF))

    @always_inline
    def write_i64_le(mut self, bits: UInt64):
        if is_little_endian():
            var native = bits
            var start = len(self.buf)
            self.buf.resize(unsafe_uninit_length=start + 8)
            unsafe_memcpy(
                dest=self.buf.unsafe_ptr().unsafe_offset(start),
                src=Pointer(to=native).unsafe_bitcast[Byte](),
                count=8,
            )
            return
        comptime for i in range(8):
            self.write_byte(Byte((bits >> (UInt64(i) * 8)) & 0xFF))

    @always_inline
    def write_bytes[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        var n = len(data)
        if n == 0:
            return
        # One growth check plus a copy beats a per-byte append for payloads.
        self.buf.extend(data)

    @always_inline
    def write_len_header(mut self, field: UInt32, payload_len: Int):
        self.write_tag(field, WireType.LEN)
        self.write_varint(UInt64(payload_len))

    def finish(deinit self) -> List[Byte]:
        return self.buf^
