from std.collections import List, Span

from avro_runtime.error import DecodeError
from avro_wire.utf8 import string_from_utf8
from avro_wire.varint import read_varint_at
from avro_wire.zigzag import zigzag_decode_i32, zigzag_decode_i64


struct WireReader[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int

    def __init__(out self, data: Span[Byte, Self.origin]):
        self.data = data
        self.pos = 0

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    def position(self) -> Int:
        return self.pos

    def read_varint(mut self) raises DecodeError -> UInt64:
        return read_varint_at(self.data, self.pos)

    def read_bool(mut self) raises DecodeError -> Bool:
        if self.remaining() < 1:
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var b = Int(self.data[self.pos])
        self.pos += 1
        if b == 0:
            return False
        if b == 1:
            return True
        raise DecodeError(DecodeError.KIND_BAD_BOOL, self.pos - 1)

    def read_int(mut self) raises DecodeError -> Int32:
        var u = self.read_varint()
        if u > UInt64(UInt32.MAX):
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)
        return zigzag_decode_i32(UInt32(u))

    def read_long(mut self) raises DecodeError -> Int64:
        return zigzag_decode_i64(self.read_varint())

    def read_float(mut self) raises DecodeError -> Float32:
        if self.remaining() < 4:
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var bits: UInt32 = 0
        comptime for i in range(4):
            bits |= UInt32(self.data[self.pos + i]) << (UInt32(i) * 8)
        self.pos += 4
        return Float32(from_bits=bits)

    def read_double(mut self) raises DecodeError -> Float64:
        if self.remaining() < 8:
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var bits: UInt64 = 0
        comptime for i in range(8):
            bits |= UInt64(self.data[self.pos + i]) << (UInt64(i) * 8)
        self.pos += 8
        return Float64(from_bits=bits)

    def read_len(mut self) raises DecodeError -> Int:
        var at = self.pos
        var n64 = self.read_long()
        if n64 < 0:
            raise DecodeError(DecodeError.KIND_RANGE, at)
        if n64 > Int64(self.remaining()):
            raise DecodeError(DecodeError.KIND_RANGE, at)
        return Int(n64)

    def read_bytes(mut self) raises DecodeError -> List[Byte]:
        var n = self.read_len()
        var out = List[Byte](capacity=n)
        for i in range(n):
            out.append(self.data[self.pos + i])
        self.pos += n
        return out^

    def read_string(mut self) raises DecodeError -> String:
        var at = self.pos
        var n = self.read_len()
        var start = self.pos
        self.pos += n
        return string_from_utf8(self.data[start : start + n], at)

    def read_fixed(mut self, n: Int) raises DecodeError -> List[Byte]:
        if n < 0 or n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var out = List[Byte](capacity=n)
        for i in range(n):
            out.append(self.data[self.pos + i])
        self.pos += n
        return out^

    def read_block_count(mut self) raises DecodeError -> Tuple[Int64, Int64]:
        """Return (item_count, size_hint_or_neg1). item_count 0 ends the array."""
        var at = self.pos
        var count = self.read_long()
        if count == 0:
            return (Int64(0), Int64(-1))
        if count > 0:
            return (count, Int64(-1))
        var size = self.read_long()
        if size < 0:
            raise DecodeError(DecodeError.KIND_BAD_BLOCK, at)
        var items = -count
        return (items, size)
