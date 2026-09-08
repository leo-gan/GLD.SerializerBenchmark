from std.collections import List, Span
from std.memory import unsafe_memcpy

from cbor_runtime.error import DecodeError
from cbor_wire.half import f32_from_bits, f64_from_bits, half_to_f64
from cbor_wire.head import (
    AI_INDEF,
    MAX_COUNT,
    MAX_DEPTH,
    MAX_ITEM_BYTES,
    read_head,
)
from cbor_wire.utf8 import span_from_utf8, string_from_utf8


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
        max_depth: Int = MAX_DEPTH,
    ):
        self.data = data
        self.pos = 0
        self.depth = depth
        self.max_depth = max_depth

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    def position(self) -> Int:
        return self.pos

    def read_head(mut self) raises DecodeError -> Tuple[Int, UInt64, Int]:
        return read_head(self.data, self.pos)

    def peek_break(self) -> Bool:
        if self.pos >= len(self.data):
            return False
        return Int(self.data[self.pos]) == 0xFF

    def read_break_or_item(mut self) raises DecodeError -> Bool:
        if self.pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        if Int(self.data[self.pos]) == 0xFF:
            self.pos += 1
            return True
        return False

    def enter(mut self) raises DecodeError:
        if self.depth >= self.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, self.pos)
        self.depth += 1

    def leave(mut self):
        if self.depth > 0:
            self.depth -= 1

    def peek_head_byte(self) raises DecodeError -> Int:
        if self.pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        return Int(self.data[self.pos])

    def read_exact(mut self, n: Int) raises DecodeError -> List[Byte]:
        if n < 0 or n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)
        if n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var out = List[Byte](unsafe_uninit_length=n)
        if n > 0:
            unsafe_memcpy(
                dest=out.unsafe_ptr(),
                src=self.data.unsafe_ptr().unsafe_offset(self.pos),
                count=n,
            )
        self.pos += n
        return out^

    def append_exact(mut self, mut dest: List[Byte], n: Int) raises DecodeError:
        """Copy the next `n` input bytes onto `dest` with one memcpy."""
        if n < 0 or n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)
        if n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        if n == 0:
            return
        var start = len(dest)
        dest.resize(unsafe_uninit_length=start + n)
        unsafe_memcpy(
            dest=dest.unsafe_ptr().unsafe_offset(start),
            src=self.data.unsafe_ptr().unsafe_offset(self.pos),
            count=n,
        )
        self.pos += n

    def read_text_exact(mut self, n: Int) raises DecodeError -> String:
        var at = self.pos
        if n < 0 or n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, at)
        if n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, at)
        var start = self.pos
        self.pos += n
        return string_from_utf8(self.data[start : start + n], at)

    def check_count(self, n: UInt64) raises DecodeError:
        if n > UInt64(MAX_COUNT):
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)

    def require_definite_len(self, major: Int, ai: Int) raises DecodeError:
        if ai == AI_INDEF:
            if major != 2 and major != 3 and major != 4 and major != 5:
                raise DecodeError(DecodeError.KIND_INDEF, self.pos)

    def read_text_span(mut self) raises DecodeError -> StringSpan[Self.origin]:
        """Definite tstr as a view into the input. Indefinite tstr is `KIND_INDEF`."""
        var at = self.pos
        var h = self.read_head()
        if h[0] != 3:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[2] == AI_INDEF:
            raise DecodeError(DecodeError.KIND_INDEF, at)
        var n = Int(h[1])
        if n < 0 or n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, at)
        if n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var start = self.pos
        self.pos += n
        return span_from_utf8(self.data[start : start + n], at)

    def read_text_chunks(mut self) raises DecodeError -> List[StringSpan[Self.origin]]:
        """Zero-copy views of each definite tstr chunk, including indefinite text."""
        var at = self.pos
        var h = self.read_head()
        if h[0] != 3:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        var out = List[StringSpan[Self.origin]]()
        if h[2] != AI_INDEF:
            var n = Int(h[1])
            if n < 0 or n > MAX_ITEM_BYTES:
                raise DecodeError(DecodeError.KIND_RANGE, at)
            if n > self.remaining():
                raise DecodeError(DecodeError.KIND_EOF, self.pos)
            var start = self.pos
            self.pos += n
            out.append(span_from_utf8(self.data[start : start + n], at))
            return out^
        var total = 0
        while True:
            if self.read_break_or_item():
                return out^
            var cat = self.pos
            var ch = self.read_head()
            if ch[0] != 3 or ch[2] == AI_INDEF:
                raise DecodeError(DecodeError.KIND_INDEF, cat)
            var cn = Int(ch[1])
            if cn < 0 or total + cn > MAX_ITEM_BYTES:
                raise DecodeError(DecodeError.KIND_RANGE, cat)
            if cn > self.remaining():
                raise DecodeError(DecodeError.KIND_EOF, self.pos)
            var cs = self.pos
            self.pos += cn
            out.append(span_from_utf8(self.data[cs : cs + cn], cat))
            total += cn

    def skip_item(mut self) raises DecodeError:
        """Advance past one well-formed item without allocating an arena."""
        var at = self.pos
        var h = self.read_head()
        self.skip_body(h[0], h[1], h[2], at)

    def skip_body(mut self, major: Int, arg: UInt64, ai: Int, at: Int) raises DecodeError:
        if major == 0 or major == 1:
            return
        if major == 7:
            if ai == AI_INDEF:
                raise DecodeError(DecodeError.KIND_BREAK, at)
            return
        if major == 2 or major == 3:
            if ai == AI_INDEF:
                while True:
                    if self.read_break_or_item():
                        return
                    var ch = self.read_head()
                    if ch[0] != major or ch[2] == AI_INDEF:
                        raise DecodeError(DecodeError.KIND_TYPE, self.pos)
                    var n = Int(ch[1])
                    if n < 0 or n > self.remaining():
                        raise DecodeError(DecodeError.KIND_EOF, self.pos)
                    self.pos += n
            var n2 = Int(arg)
            if n2 < 0 or n2 > self.remaining():
                raise DecodeError(DecodeError.KIND_EOF, self.pos)
            self.pos += n2
            return
        if major == 6:
            self.skip_item()
            return
        if major == 4:
            if ai == AI_INDEF:
                while True:
                    if self.read_break_or_item():
                        return
                    self.skip_item()
            self.check_count(arg)
            for _i in range(Int(arg)):
                self.skip_item()
            return
        if major == 5:
            if ai == AI_INDEF:
                while True:
                    if self.read_break_or_item():
                        return
                    self.skip_item()
                    if self.read_break_or_item():
                        raise DecodeError(DecodeError.KIND_MAP_PAIR, self.pos)
                    self.skip_item()
            self.check_count(arg)
            for _j in range(Int(arg)):
                self.skip_item()
                self.skip_item()
            return
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def take_int_key(mut self, mut key: Int64) raises DecodeError -> Bool:
        """If the next item is an integer, consume it into `key`."""
        var at = self.pos
        var h = self.read_head()
        if h[0] == 0:
            if h[1] > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            key = Int64(h[1])
            return True
        if h[0] == 1:
            if h[1] > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            key = -(Int64(h[1]) + Int64(1))
            return True
        self.skip_body(h[0], h[1], h[2], at)
        return False

    def take_definite_tstr(mut self, mut start: Int, mut n: Int) raises DecodeError -> Bool:
        """If the next item is a definite tstr, consume it and set `start`/`n` to the payload."""
        var at = self.pos
        var h = self.read_head()
        if h[0] != 3 or h[2] == AI_INDEF:
            self.skip_body(h[0], h[1], h[2], at)
            return False
        var ln = Int(h[1])
        if ln < 0 or ln > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, at)
        if ln > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        start = self.pos
        n = ln
        self.pos += ln
        return True

    def bytes_eq(self, start: Int, n: Int, lit: String) -> Bool:
        var b = lit.as_bytes()
        if n != len(b):
            return False
        for i in range(n):
            if Int(self.data[start + i]) != Int(b[i]):
                return False
        return True

    def read_bool(mut self) raises DecodeError -> Bool:
        var at = self.pos
        var h = self.read_head()
        if h[0] != 7:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[2] == 20:
            return False
        if h[2] == 21:
            return True
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_int64(mut self) raises DecodeError -> Int64:
        var at = self.pos
        var h = self.read_head()
        if h[0] == 0:
            if h[1] > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return Int64(h[1])
        if h[0] == 1:
            if h[1] > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return -(Int64(h[1]) + Int64(1))
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_uint64(mut self) raises DecodeError -> UInt64:
        var at = self.pos
        var h = self.read_head()
        if h[0] == 0:
            return h[1]
        if h[0] == 1:
            if h[1] > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return UInt64(-(Int64(h[1]) + Int64(1)))
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_float64(mut self) raises DecodeError -> Float64:
        var at = self.pos
        var h = self.read_head()
        if h[0] == 7:
            if h[2] == 25:
                return half_to_f64(UInt16(h[1]))
            if h[2] == 26:
                return Float64(f32_from_bits(UInt32(h[1])))
            if h[2] == 27:
                return f64_from_bits(h[1])
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[0] == 0:
            return Float64(h[1])
        if h[0] == 1:
            if h[1] > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return Float64(-(Int64(h[1]) + Int64(1)))
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_tstr(mut self) raises DecodeError -> String:
        var at = self.pos
        var h = self.read_head()
        if h[0] != 3:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[2] == AI_INDEF:
            raise DecodeError(DecodeError.KIND_INDEF, at)
        return self.read_text_exact(Int(h[1]))

    def read_bstr(mut self) raises DecodeError -> List[Byte]:
        var at = self.pos
        var h = self.read_head()
        if h[0] != 2:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[2] == AI_INDEF:
            raise DecodeError(DecodeError.KIND_INDEF, at)
        return self.read_exact(Int(h[1]))

    def read_array_len(mut self) raises DecodeError -> Int:
        var at = self.pos
        var h = self.read_head()
        if h[0] != 4:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[2] == AI_INDEF:
            raise DecodeError(DecodeError.KIND_INDEF, at)
        self.check_count(h[1])
        return Int(h[1])

    def read_map_len(mut self) raises DecodeError -> Int:
        var at = self.pos
        var h = self.read_head()
        if h[0] != 5:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[2] == AI_INDEF:
            raise DecodeError(DecodeError.KIND_INDEF, at)
        self.check_count(h[1])
        return Int(h[1])
