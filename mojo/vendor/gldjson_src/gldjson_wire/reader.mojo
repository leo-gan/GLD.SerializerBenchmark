from std.collections import Span

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import DecodeOptions
from gldjson_wire.classify import MAX_COUNT, MAX_DEPTH
from gldjson_wire.number import NumberTok, parse_int, parse_number
from gldjson_wire.simdscan import skip_ws_span
from gldjson_wire.string import parse_string


struct WireReader[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int
    var depth: Int
    var options: DecodeOptions

    def __init__(
        out self,
        data: Span[Byte, Self.origin],
        options: DecodeOptions = DecodeOptions.default,
        *,
        depth: Int = 0,
    ):
        self.data = data
        self.pos = 0
        self.depth = depth
        self.options = options

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    def position(self) -> Int:
        return self.pos

    def load_u64(self) -> UInt64:
        """Unaligned little-endian 8 bytes at `pos`. Caller checked length."""
        return (
            self.data.unsafe_ptr()
            .unsafe_offset(self.pos)
            .unsafe_bitcast[UInt64]()[]
        )

    def load_u32_at(self, off: Int) -> UInt32:
        """Unaligned little-endian 4 bytes at `pos + off`. Caller checked length."""
        return (
            self.data.unsafe_ptr()
            .unsafe_offset(self.pos + off)
            .unsafe_bitcast[UInt32]()[]
        )

    def eat_here(mut self, ch: Int) raises DecodeError:
        if self.pos >= len(self.data) or Int(self.data[self.pos]) != ch:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
        self.pos += 1

    def skip_ws(mut self) raises DecodeError:
        if self.pos == 0 and len(self.data) >= 3:
            if (
                Int(self.data[0]) == 0xEF
                and Int(self.data[1]) == 0xBB
                and Int(self.data[2]) == 0xBF
            ):
                raise DecodeError(DecodeError.KIND_SYNTAX, 0)
        var p = self.pos
        skip_ws_span(self.data, p)
        self.pos = p

    def peek(mut self) raises DecodeError -> Int:
        self.skip_ws()
        if self.pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        return Int(self.data[self.pos])

    def try_eat_bytes[origin2: ImmOrigin](mut self, lit: Span[Byte, origin2]) -> Bool:
        var n = len(lit)
        if self.pos + n > len(self.data):
            return False
        var i = 0
        while i < n:
            if Int(self.data[self.pos + i]) != Int(lit[i]):
                return False
            i += 1
        self.pos += n
        return True

    def eat(mut self, ch: Int) raises DecodeError:
        self.skip_ws()
        if self.pos >= len(self.data) or Int(self.data[self.pos]) != ch:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
        self.pos += 1

    def enter(mut self) raises DecodeError:
        if self.depth >= self.options.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, self.pos)
        self.depth += 1

    def leave(mut self):
        if self.depth > 0:
            self.depth -= 1

    def read_null(mut self) raises DecodeError:
        self.skip_ws()
        self._eat4(110, 117, 108, 108)

    def read_true(mut self) raises DecodeError:
        self.skip_ws()
        self._eat4(116, 114, 117, 101)

    def read_false(mut self) raises DecodeError:
        self.skip_ws()
        self._eat5(102, 97, 108, 115, 101)

    def read_true_here(mut self) raises DecodeError:
        self._eat4(116, 114, 117, 101)

    def read_false_here(mut self) raises DecodeError:
        self._eat5(102, 97, 108, 115, 101)

    def _eat4(mut self, a: Int, b: Int, c: Int, d: Int) raises DecodeError:
        if self.pos + 4 > len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var want = (
            UInt32(a)
            | (UInt32(b) << 8)
            | (UInt32(c) << 16)
            | (UInt32(d) << 24)
        )
        if self.load_u32_at(0) != want:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
        self.pos += 4

    def _eat5(mut self, a: Int, b: Int, c: Int, d: Int, e: Int) raises DecodeError:
        if self.pos + 5 > len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        var want = (
            UInt32(a)
            | (UInt32(b) << 8)
            | (UInt32(c) << 16)
            | (UInt32(d) << 24)
        )
        if self.load_u32_at(0) != want or Int(self.data[self.pos + 4]) != e:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
        self.pos += 5

    def read_string(mut self) raises DecodeError -> String:
        self.skip_ws()
        return parse_string(self.data, self.pos)

    def read_string_here(mut self) raises DecodeError -> String:
        return parse_string(self.data, self.pos)

    def read_number(mut self) raises DecodeError -> NumberTok:
        self.skip_ws()
        return parse_number(self.data, self.pos)

    def read_number_here(mut self) raises DecodeError -> NumberTok:
        return parse_number(self.data, self.pos)

    def read_int_here(mut self) raises DecodeError -> Int64:
        return parse_int(self.data, self.pos)

    def skip_value(mut self) raises DecodeError:
        var c = self.peek()
        if c == 110:
            self.read_null()
        elif c == 116:
            self.read_true()
        elif c == 102:
            self.read_false()
        elif c == 34:
            _ = self.read_string()
        elif c == 91:
            self._skip_array()
        elif c == 123:
            self._skip_object()
        elif c == 45 or (c >= 48 and c <= 57):
            _ = self.read_number()
        else:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)

    def _skip_array(mut self) raises DecodeError:
        self.enter()
        self.eat(91)
        var c = self.peek()
        if c == 93:
            self.eat(93)
            self.leave()
            return
        var n = 0
        while True:
            if n >= MAX_COUNT:
                raise DecodeError(DecodeError.KIND_RANGE, self.pos)
            self.skip_value()
            n += 1
            var s = self.peek()
            if s == 93:
                self.eat(93)
                self.leave()
                return
            if s != 44:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
            self.eat(44)
            if self.peek() == 93:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)

    def _skip_object(mut self) raises DecodeError:
        self.enter()
        self.eat(123)
        var c = self.peek()
        if c == 125:
            self.eat(125)
            self.leave()
            return
        var n = 0
        while True:
            if n >= MAX_COUNT:
                raise DecodeError(DecodeError.KIND_RANGE, self.pos)
            if self.peek() != 34:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
            _ = self.read_string()
            self.eat(58)
            self.skip_value()
            n += 1
            var s = self.peek()
            if s == 125:
                self.eat(125)
                self.leave()
                return
            if s != 44:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
            self.eat(44)
            if self.peek() == 125:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
