from std.collections import List, Span

from pb_runtime.error import DecodeError
from pb_wire.reader import WireReader
from pb_wire.types import WireType
from pb_wire.writer import WireWriter


comptime UNKNOWN_PRESERVE_DEFAULT = True


struct UnknownFieldSet(
    Copyable, Movable, Defaultable, Deinitable, Equatable
):
    """Raw tag+payload records that the schema does not name.

    Official proto3 preserves these and writes them back on encode.
    """

    var buf: List[Byte]

    def __init__(out self):
        self.buf = List[Byte]()

    def encoded_len(self) -> Int:
        return len(self.buf)

    def encode_to(self, mut enc: WireWriter):
        if len(self.buf) != 0:
            enc.write_bytes(self.buf)

    def add[
        origin: ImmOrigin
    ](
        mut self, field: UInt32, wire: WireType, mut dec: WireReader[origin]
    ) raises DecodeError:
        var tmp = WireWriter()
        tmp.write_tag(field, wire)
        if wire == WireType.VARINT:
            tmp.write_varint(dec.read_varint())
        elif wire == WireType.I64:
            tmp.write_i64_le(dec.read_i64_le())
        elif wire == WireType.I32:
            tmp.write_i32_le(dec.read_i32_le())
        elif wire == WireType.LEN:
            var span = dec.read_len_span()
            tmp.write_varint(UInt64(len(span)))
            tmp.write_bytes(span)
        else:
            raise DecodeError(DecodeError.KIND_INVALID_WIRE, dec.position(), field)
        var chunk = tmp^.finish()
        for i in range(len(chunk)):
            self.buf.append(chunk[i])

    def __eq__(self, other: Self) -> Bool:
        if len(self.buf) != len(other.buf):
            return False
        for i in range(len(self.buf)):
            if self.buf[i] != other.buf[i]:
                return False
        return True
