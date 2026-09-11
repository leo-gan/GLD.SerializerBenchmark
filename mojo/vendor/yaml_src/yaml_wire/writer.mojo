from std.collections import List, Span
from std.memory import unsafe_memcpy

from yaml_runtime.options import EncodeOptions
from yaml_wire.number import encoded_float_len, encoded_int_len, write_float_digits, write_int_known
from yaml_wire.scalar import hex_digit_ascii, is_plain_safe


struct WireWriter(Movable):
    """Writes YAML into one `List[Byte]` at a cursor."""

    var buf: List[Byte]
    var pos: Int
    var indent_depth: Int

    def __init__(out self, *, capacity: Int = 64, exact: Bool = False):
        _ = exact
        if capacity > 0:
            self.buf = List[Byte](unsafe_uninit_length=capacity)
        else:
            self.buf = List[Byte]()
        self.pos = 0
        self.indent_depth = 0

    def __init__(out self, var buf: List[Byte], *, pos: Int = 0):
        self.buf = buf^
        self.pos = pos
        self.indent_depth = 0

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

    def write_ascii(mut self, s: String):
        self.write_bytes(s.as_bytes())

    def write_indent(mut self, options: EncodeOptions):
        var n = self.indent_depth * options.indent
        if n <= 0:
            return
        self.ensure(n)
        var i = 0
        while i + 1 < n:
            self.buf[self.pos] = Byte(32)
            self.buf[self.pos + 1] = Byte(32)
            self.pos += 2
            i += 2
        if i < n:
            self.buf[self.pos] = Byte(32)
            self.pos += 1

    def write_lf(mut self):
        self.write_byte(Byte(10))

    def write_null(mut self):
        self.ensure(4)
        self.buf[self.pos] = Byte(110)
        self.buf[self.pos + 1] = Byte(117)
        self.buf[self.pos + 2] = Byte(108)
        self.buf[self.pos + 3] = Byte(108)
        self.pos += 4

    def write_bool(mut self, v: Bool):
        if v:
            self.ensure(4)
            self.buf[self.pos] = Byte(116)
            self.buf[self.pos + 1] = Byte(114)
            self.buf[self.pos + 2] = Byte(117)
            self.buf[self.pos + 3] = Byte(101)
            self.pos += 4
        else:
            self.ensure(5)
            self.buf[self.pos] = Byte(102)
            self.buf[self.pos + 1] = Byte(97)
            self.buf[self.pos + 2] = Byte(108)
            self.buf[self.pos + 3] = Byte(115)
            self.buf[self.pos + 4] = Byte(101)
            self.pos += 5

    def write_int(mut self, v: Int64):
        var n = encoded_int_len(v)
        self.ensure(n)
        write_int_known(self.buf, self.pos, v, n)

    def write_float(mut self, v: Float64):
        var n = encoded_float_len(v)
        self.ensure(n + 4)
        write_float_digits(self.buf, self.pos, v)

    def write_string(mut self, s: String, options: EncodeOptions):
        var data = s.as_bytes()
        if is_plain_safe(data, options.is_flow()):
            self.write_bytes(data)
            return
        self.write_byte(Byte(34))
        var i = 0
        var n = len(data)
        while i < n:
            var c = Int(data[i])
            if c == 10:
                self.write_byte(Byte(92))
                self.write_byte(Byte(110))
            elif c == 13:
                self.write_byte(Byte(92))
                self.write_byte(Byte(114))
            elif c == 9:
                self.write_byte(Byte(92))
                self.write_byte(Byte(116))
            elif c == 34:
                self.write_byte(Byte(92))
                self.write_byte(Byte(34))
            elif c == 92:
                self.write_byte(Byte(92))
                self.write_byte(Byte(92))
            elif c < 32:
                self.write_ascii("\\u00")
                self.write_byte(Byte(hex_digit_ascii(c >> 4)))
                self.write_byte(Byte(hex_digit_ascii(c & 15)))
            else:
                self.write_byte(data[i])
            i += 1
        self.write_byte(Byte(34))

    def write_binary[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        self.write_ascii("!!binary ")
        _write_b64(self, data)

    def finish(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^

    def finish_keep(deinit self, mut n: Int) -> List[Byte]:
        n = self.pos
        return self.buf^


def _write_b64[origin: ImmOrigin](mut w: WireWriter, data: Span[Byte, origin]):
    comptime T = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var tab = T.as_bytes()
    var n = len(data)
    var i = 0
    w.ensure(((n + 2) // 3) * 4)
    while i + 2 < n:
        var a = Int(data[i])
        var b = Int(data[i + 1])
        var c = Int(data[i + 2])
        var v = (a << 16) | (b << 8) | c
        w.write_byte(tab[(v >> 18) & 63])
        w.write_byte(tab[(v >> 12) & 63])
        w.write_byte(tab[(v >> 6) & 63])
        w.write_byte(tab[v & 63])
        i += 3
    if i < n:
        var a = Int(data[i])
        var b = 0
        if i + 1 < n:
            b = Int(data[i + 1])
        var v = (a << 16) | (b << 8)
        w.write_byte(tab[(v >> 18) & 63])
        w.write_byte(tab[(v >> 12) & 63])
        if i + 1 < n:
            w.write_byte(tab[(v >> 6) & 63])
        else:
            w.write_byte(Byte(61))
        w.write_byte(Byte(61))
