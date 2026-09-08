from std.collections import List, Span

from pb_runtime.error import DecodeError
from pb_wire.types import WireType
from pb_wire.utf8 import string_from_utf8
from pb_wire.varint import read_varint_at


comptime MAX_FIELD_NUMBER = UInt64(0x1FFFFFFF)  # 2^29 - 1


struct WireReader[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int
    var depth: Int
    var max_depth: Int

    def __init__(
        out self,
        data: Span[Byte, Self.origin],
        *,
        depth: Int = 0,
        max_depth: Int = 100,
    ):
        self.data = data
        self.pos = 0
        self.depth = depth
        self.max_depth = max_depth

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    def position(self) -> Int:
        return self.pos

    def read_varint(mut self) raises DecodeError -> UInt64:
        return read_varint_at(self.data, self.pos)

    def read_tag(mut self) raises DecodeError -> Tuple[UInt32, WireType]:
        var at = self.pos
        var key = self.read_varint()
        var field_u = key >> UInt64(3)
        if field_u < 1 or field_u > MAX_FIELD_NUMBER:
            raise DecodeError(DecodeError.KIND_BAD_FIELD, at, UInt32(field_u))
        var wt = UInt8(key & 7)
        var wire = WireType(wt)
        if not wire.is_implemented():
            raise DecodeError(
                DecodeError.KIND_INVALID_WIRE, at, UInt32(field_u)
            )
        return (UInt32(field_u), wire)

    def read_i32_le(mut self) raises DecodeError -> UInt32:
        if self.remaining() < 4:
            raise DecodeError(DecodeError.KIND_TRUNCATED, self.pos)
        var bits: UInt32 = 0
        comptime for i in range(4):
            bits |= UInt32(self.data[self.pos + i]) << (UInt32(i) * 8)
        self.pos += 4
        return bits

    def read_i64_le(mut self) raises DecodeError -> UInt64:
        if self.remaining() < 8:
            raise DecodeError(DecodeError.KIND_TRUNCATED, self.pos)
        var bits: UInt64 = 0
        comptime for i in range(8):
            bits |= UInt64(self.data[self.pos + i]) << (UInt64(i) * 8)
        self.pos += 8
        return bits

    def read_len_span(mut self) raises DecodeError -> Span[Byte, Self.origin]:
        var at = self.pos
        var n64 = self.read_varint()
        if n64 > UInt64(self.remaining()):
            raise DecodeError(DecodeError.KIND_OVERSIZE, at)
        var n = Int(n64)
        var start = self.pos
        self.pos += n
        return self.data[start : start + n]

    def read_string(mut self) raises DecodeError -> String:
        var start = self.position()
        var span = self.read_len_span()
        return string_from_utf8(span, start, 0)

    def read_bytes(mut self) raises DecodeError -> List[Byte]:
        var span = self.read_len_span()
        var out = List[Byte](capacity=len(span))
        for i in range(len(span)):
            out.append(span[i])
        return out^

    def subreader(
        self, span: Span[Byte, Self.origin]
    ) raises DecodeError -> WireReader[Self.origin]:
        if self.depth + 1 > self.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, self.pos)
        return WireReader[Self.origin](
            span, depth=self.depth + 1, max_depth=self.max_depth
        )

    def skip_field(mut self, wire: WireType) raises DecodeError:
        if wire == WireType.VARINT:
            _ = self.read_varint()
        elif wire == WireType.I64:
            _ = self.read_i64_le()
        elif wire == WireType.LEN:
            _ = self.read_len_span()
        elif wire == WireType.I32:
            _ = self.read_i32_le()
        else:
            raise DecodeError(DecodeError.KIND_INVALID_WIRE, self.pos)

    def read_packed_varint(mut self, mut out: List[UInt64]) raises DecodeError:
        var span = self.read_len_span()
        var inner = WireReader[Self.origin](
            span, depth=self.depth, max_depth=self.max_depth
        )
        while inner.remaining() > 0:
            out.append(inner.read_varint())

    def read_packed_fixed32(mut self, mut out: List[UInt32]) raises DecodeError:
        var start = self.position()
        var span = self.read_len_span()
        if len(span) % 4 != 0:
            raise DecodeError(DecodeError.KIND_BAD_PACKED, start)
        var inner = WireReader[Self.origin](
            span, depth=self.depth, max_depth=self.max_depth
        )
        while inner.remaining() > 0:
            out.append(inner.read_i32_le())

    def read_packed_fixed64(mut self, mut out: List[UInt64]) raises DecodeError:
        var start = self.position()
        var span = self.read_len_span()
        if len(span) % 8 != 0:
            raise DecodeError(DecodeError.KIND_BAD_PACKED, start)
        var inner = WireReader[Self.origin](
            span, depth=self.depth, max_depth=self.max_depth
        )
        while inner.remaining() > 0:
            out.append(inner.read_i64_le())
