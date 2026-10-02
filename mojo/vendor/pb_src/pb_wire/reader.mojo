from std.collections import List, Span
from std.memory import Pointer, unsafe_memcpy
from std.sys import is_little_endian

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

    @always_inline
    def remaining(self) -> Int:
        return len(self.data) - self.pos

    @always_inline
    def position(self) -> Int:
        return self.pos

    @always_inline
    def read_varint(mut self) raises DecodeError -> UInt64:
        return read_varint_at(self.data, self.pos)

    @always_inline
    def read_tag(mut self) raises DecodeError -> Tuple[UInt32, WireType]:
        var pos = self.pos
        var n = len(self.data)
        # Field numbers below 16 are a single byte on the wire.
        if pos < n:
            var b = UInt64(self.data.unsafe_get(pos))
            if b < 0x80:
                self.pos = pos + 1
                var field_u = b >> 3
                var wt = UInt8(b & 7)
                if field_u < 1:
                    raise DecodeError(
                        DecodeError.KIND_BAD_FIELD, pos, UInt32(field_u)
                    )
                if wt != 0 and wt != 1 and wt != 2 and wt != 5:
                    raise DecodeError(
                        DecodeError.KIND_INVALID_WIRE, pos, UInt32(field_u)
                    )
                return (UInt32(field_u), WireType(wt))
        var at = self.pos
        var key = self.read_varint()
        var field_u = key >> UInt64(3)
        if field_u < 1 or field_u > MAX_FIELD_NUMBER:
            raise DecodeError(DecodeError.KIND_BAD_FIELD, at, UInt32(field_u))
        var wt = UInt8(key & 7)
        if wt != 0 and wt != 1 and wt != 2 and wt != 5:
            raise DecodeError(
                DecodeError.KIND_INVALID_WIRE, at, UInt32(field_u)
            )
        return (UInt32(field_u), WireType(wt))

    @always_inline
    def read_i32_le(mut self) raises DecodeError -> UInt32:
        var pos = self.pos
        if len(self.data) - pos < 4:
            raise DecodeError(DecodeError.KIND_TRUNCATED, pos)
        if is_little_endian():
            var bits = UInt32(0)
            unsafe_memcpy(
                dest=Pointer(to=bits).unsafe_bitcast[Byte](),
                src=self.data.unsafe_ptr().unsafe_offset(pos),
                count=4,
            )
            self.pos = pos + 4
            return bits
        var bits = UInt32(self.data.unsafe_get(pos))
        bits |= UInt32(self.data.unsafe_get(pos + 1)) << 8
        bits |= UInt32(self.data.unsafe_get(pos + 2)) << 16
        bits |= UInt32(self.data.unsafe_get(pos + 3)) << 24
        self.pos = pos + 4
        return bits

    @always_inline
    def read_i64_le(mut self) raises DecodeError -> UInt64:
        var pos = self.pos
        if len(self.data) - pos < 8:
            raise DecodeError(DecodeError.KIND_TRUNCATED, pos)
        if is_little_endian():
            var bits = UInt64(0)
            unsafe_memcpy(
                dest=Pointer(to=bits).unsafe_bitcast[Byte](),
                src=self.data.unsafe_ptr().unsafe_offset(pos),
                count=8,
            )
            self.pos = pos + 8
            return bits
        var bits = UInt64(self.data.unsafe_get(pos))
        bits |= UInt64(self.data.unsafe_get(pos + 1)) << 8
        bits |= UInt64(self.data.unsafe_get(pos + 2)) << 16
        bits |= UInt64(self.data.unsafe_get(pos + 3)) << 24
        bits |= UInt64(self.data.unsafe_get(pos + 4)) << 32
        bits |= UInt64(self.data.unsafe_get(pos + 5)) << 40
        bits |= UInt64(self.data.unsafe_get(pos + 6)) << 48
        bits |= UInt64(self.data.unsafe_get(pos + 7)) << 56
        self.pos = pos + 8
        return bits

    @always_inline
    def read_len_span(mut self) raises DecodeError -> Span[Byte, Self.origin]:
        var at = self.pos
        var n64 = self.read_varint()
        if n64 > UInt64(self.remaining()):
            raise DecodeError(DecodeError.KIND_OVERSIZE, at)
        var n = Int(n64)
        var start = self.pos
        self.pos += n
        return self.data[start : start + n]

    @always_inline
    def read_string(mut self) raises DecodeError -> String:
        var start = self.position()
        var span = self.read_len_span()
        return string_from_utf8(span, start, 0)

    @always_inline
    def read_bytes(mut self) raises DecodeError -> List[Byte]:
        var span = self.read_len_span()
        var out = List[Byte](capacity=len(span))
        out.extend(span)
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
        var nbytes = len(span)
        if nbytes % 4 != 0:
            raise DecodeError(DecodeError.KIND_BAD_PACKED, start)
        var count = nbytes // 4
        if count == 0:
            return
        if is_little_endian():
            var base = len(out)
            out.resize(unsafe_uninit_length=base + count)
            unsafe_memcpy(
                dest=out.unsafe_ptr().unsafe_offset(base).unsafe_bitcast[Byte](),
                src=span.unsafe_ptr(),
                count=nbytes,
            )
            return
        var inner = WireReader[Self.origin](
            span, depth=self.depth, max_depth=self.max_depth
        )
        while inner.remaining() > 0:
            out.append(inner.read_i32_le())

    def read_packed_fixed64(mut self, mut out: List[UInt64]) raises DecodeError:
        var start = self.position()
        var span = self.read_len_span()
        var nbytes = len(span)
        if nbytes % 8 != 0:
            raise DecodeError(DecodeError.KIND_BAD_PACKED, start)
        var count = nbytes // 8
        if count == 0:
            return
        if is_little_endian():
            var base = len(out)
            out.resize(unsafe_uninit_length=base + count)
            unsafe_memcpy(
                dest=out.unsafe_ptr().unsafe_offset(base).unsafe_bitcast[Byte](),
                src=span.unsafe_ptr(),
                count=nbytes,
            )
            return
        var inner = WireReader[Self.origin](
            span, depth=self.depth, max_depth=self.max_depth
        )
        while inner.remaining() > 0:
            out.append(inner.read_i64_le())
