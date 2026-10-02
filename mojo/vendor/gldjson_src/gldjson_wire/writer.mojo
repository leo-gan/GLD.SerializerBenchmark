from std.collections import List, Span
from std.memory import unsafe_memcpy

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import EncodeOptions
from gldjson_wire.number import (
    encoded_float_len,
    encoded_int_len,
    try_write_simple_float,
    write_float_digits,
    write_int_known,
)
from gldjson_wire.string import encoded_string_len, needs_escape, write_string_escaped


struct WireWriter(Movable):
    """Writes JSON into one `List[Byte]` at a cursor.

    `encode` pre-sizes the list to `encoded_len` so the hot path stores
    bytes without growing. `ensure` only runs when the estimate was short.
    """

    var buf: List[Byte]
    var pos: Int
    var pretty_depth: Int

    def __init__(out self, *, capacity: Int = 64, exact: Bool = True):
        # Always pre-size the length (yyjson / glaze). `capacity=` used to
        # reserve only, so every write_byte resized from len 0.
        _ = exact
        if capacity > 0:
            self.buf = List[Byte](unsafe_uninit_length=capacity)
        else:
            self.buf = List[Byte]()
        self.pos = 0
        self.pretty_depth = 0

    def __init__(out self, var buf: List[Byte], *, pos: Int = 0):
        self.buf = buf^
        self.pos = pos
        self.pretty_depth = 0

    @no_inline
    def _grow_to(mut self, need: Int):
        if need > len(self.buf):
            self.buf.resize(unsafe_uninit_length=need)

    @always_inline
    def ensure(mut self, n: Int):
        var need = self.pos + n
        if need > len(self.buf):
            self._grow_to(need)

    @always_inline
    def write_byte(mut self, b: Byte):
        var i = self.pos
        if i >= len(self.buf):
            self._grow_to(i + 1)
            i = self.pos
        self.buf.unsafe_ptr().unsafe_offset(i)[] = b
        self.pos = i + 1

    @always_inline
    def write_bytes[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        var n = len(data)
        if n == 0:
            return
        var i = self.pos
        if i + n > len(self.buf):
            self._grow_to(i + n)
            i = self.pos
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(i),
            src=data.unsafe_ptr(),
            count=n,
        )
        self.pos = i + n

    def write_u64(mut self, w: UInt64):
        self.ensure(8)
        self.buf.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[UInt64]()[] = w
        self.pos += 8

    def write_u32(mut self, w: UInt32):
        self.ensure(4)
        self.buf.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[UInt32]()[] = w
        self.pos += 4

    def write_literal(mut self, s: String):
        self.write_bytes(s.as_bytes())

    @always_inline
    def write_null(mut self):
        var i = self.pos
        if i + 4 > len(self.buf):
            self._grow_to(i + 4)
            i = self.pos
        self.buf.unsafe_ptr().unsafe_offset(i).unsafe_bitcast[UInt32]()[] = UInt32(
            0x6C6C756E
        )
        self.pos = i + 4

    @always_inline
    def write_bool(mut self, v: Bool):
        var i = self.pos
        var p = self.buf.unsafe_ptr()
        if v:
            if i + 4 > len(self.buf):
                self._grow_to(i + 4)
                i = self.pos
                p = self.buf.unsafe_ptr()
            p.unsafe_offset(i).unsafe_bitcast[UInt32]()[] = UInt32(0x65757274)
            self.pos = i + 4
            return
        if i + 5 > len(self.buf):
            self._grow_to(i + 5)
            i = self.pos
            p = self.buf.unsafe_ptr()
        p.unsafe_offset(i).unsafe_bitcast[UInt32]()[] = UInt32(0x736C6166)
        p.unsafe_offset(i + 4)[] = Byte(101)
        self.pos = i + 5

    @always_inline
    def write_int(mut self, v: Int64):
        if v > Int64(-100) and v < Int64(100):
            var neg = v < Int64(0)
            var mag = Int(v)
            if neg:
                mag = -mag
            var need = 1
            if mag >= 10:
                need = 2
            if neg:
                need += 1
            var i = self.pos
            if i + need > len(self.buf):
                self._grow_to(i + need)
                i = self.pos
            var p = self.buf.unsafe_ptr()
            if neg:
                p.unsafe_offset(i)[] = Byte(45)
                i += 1
            if mag >= 10:
                p.unsafe_offset(i)[] = Byte(48 + mag // 10)
                p.unsafe_offset(i + 1)[] = Byte(48 + mag % 10)
                self.pos = i + 2
                return
            p.unsafe_offset(i)[] = Byte(48 + mag)
            self.pos = i + 1
            return
        var n = encoded_int_len(v)
        self.ensure(n)
        write_int_known(self.buf, self.pos, v, n)

    def finish_keep(deinit self, mut n: Int) -> List[Byte]:
        """Return the buffer without shrinking. glaze reused-dest path."""
        n = self.pos
        return self.buf^

    @always_inline
    def write_float(mut self, v: Float64):
        if try_write_simple_float(self.buf, self.pos, v):
            return
        self._write_float_slow(v)

    @no_inline
    def _write_float_slow(mut self, v: Float64):
        self.ensure(32)
        try:
            write_float_digits(self.buf, self.pos, v)
        except _:
            self.write_literal("0")

    @always_inline
    def write_string(mut self, s: String):
        var b = s.as_bytes()
        var n = len(b)
        if not needs_escape(b):
            var i = self.pos
            if i + n + 2 > len(self.buf):
                self._grow_to(i + n + 2)
                i = self.pos
            var p = self.buf.unsafe_ptr()
            p.unsafe_offset(i)[] = Byte(34)
            if n > 0:
                unsafe_memcpy(
                    dest=p.unsafe_offset(i + 1),
                    src=b.unsafe_ptr(),
                    count=n,
                )
            p.unsafe_offset(i + n + 1)[] = Byte(34)
            self.pos = i + n + 2
            return
        self.ensure(encoded_string_len(s))
        write_string_escaped(self.buf, self.pos, s)

    def write_indent(mut self, options: EncodeOptions):
        if options.mode != EncodeOptions.PRETTY:
            return
        var n = self.pretty_depth * options.indent
        if n <= 0:
            return
        self.ensure(n)
        var p = self.buf.unsafe_ptr()
        var base = self.pos
        var i = 0
        while i < n:
            p.unsafe_offset(base + i)[] = Byte(32)
            i += 1
        self.pos = base + n

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
