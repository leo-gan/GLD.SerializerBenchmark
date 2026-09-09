from std.collections import List, Span
from std.memory import unsafe_memcpy

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import EncodeOptions
from gldjson_wire.number import encoded_float_len, encoded_int_len, write_float_digits, write_int_digits
from gldjson_wire.string import encoded_string_len, write_string_escaped


struct WireWriter(Movable):
    """Writes JSON into one `List[Byte]` at a cursor.

    `encode` pre-sizes the list to `encoded_len` so the hot path stores
    bytes without growing. `ensure` only runs when the estimate was short.
    """

    var buf: List[Byte]
    var pos: Int
    var pretty_depth: Int

    def __init__(out self, *, capacity: Int = 64, exact: Bool = False):
        if exact and capacity > 0:
            self.buf = List[Byte](unsafe_uninit_length=capacity)
        else:
            self.buf = List[Byte](capacity=capacity)
        self.pos = 0
        self.pretty_depth = 0

    def __init__(out self, var buf: List[Byte], *, pos: Int = 0):
        self.buf = buf^
        self.pos = pos
        self.pretty_depth = 0

    def ensure(mut self, n: Int):
        var need = self.pos + n
        if need > len(self.buf):
            self.buf.resize(unsafe_uninit_length=need)

    def write_byte(mut self, b: Byte):
        self.ensure(1)
        self.buf[self.pos] = b
        self.pos += 1

    def write_bytes[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        var n = len(data)
        if n == 0:
            return
        self.ensure(n)
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
            src=data.unsafe_ptr(),
            count=n,
        )
        self.pos += n

    def write_literal(mut self, s: String):
        self.write_bytes(s.as_bytes())

    def write_null(mut self):
        self.write_literal("null")

    def write_bool(mut self, v: Bool):
        if v:
            self.write_literal("true")
        else:
            self.write_literal("false")

    def write_int(mut self, v: Int64):
        var n = encoded_int_len(v)
        self.ensure(n)
        write_int_digits(self.buf, self.pos, v)

    def write_float(mut self, v: Float64):
        var n = encoded_float_len(v)
        if n < 1:
            n = 24
        self.ensure(n)
        try:
            write_float_digits(self.buf, self.pos, v)
        except _:
            self.write_literal("0")

    def write_string(mut self, s: String):
        var n = encoded_string_len(s)
        self.ensure(n)
        write_string_escaped(self.buf, self.pos, s)

    def write_indent(mut self, options: EncodeOptions):
        if options.mode != EncodeOptions.PRETTY:
            return
        var n = self.pretty_depth * options.indent
        if n <= 0:
            return
        self.ensure(n)
        var i = 0
        while i < n:
            self.buf[self.pos] = Byte(32)
            self.pos += 1
            i += 1

    def write_member_sep(mut self, options: EncodeOptions, first: Bool):
        var pretty = options.mode == EncodeOptions.PRETTY
        if first:
            if pretty:
                self.write_byte(Byte(10))
                self.write_indent(options)
            return
        if pretty:
            self.write_byte(Byte(44))
            self.write_byte(Byte(10))
            self.write_indent(options)
        else:
            self.write_byte(Byte(44))

    def write_colon(mut self, options: EncodeOptions):
        if options.mode == EncodeOptions.PRETTY:
            self.write_byte(Byte(58))
            self.write_byte(Byte(32))
        else:
            self.write_byte(Byte(58))

    def finish(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^
