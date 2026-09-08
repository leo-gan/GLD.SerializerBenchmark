from std.collections import List, Span
from std.memory import unsafe_memcpy

from cbor_wire.head import extra_len, head_byte, shortest_ai
from cbor_wire.half import f32_to_bits, f64_to_bits, f64_to_half_bits, half_to_f64


def preferred_float_parts(v: Float64) -> Tuple[Int, UInt64]:
    """Return `(ai, payload)` for RFC 8949 preferred float width."""
    var bits = f64_to_bits(v)
    var exp = Int((bits >> UInt64(52)) & UInt64(0x7FF))
    var frac = bits & ((UInt64(1) << UInt64(52)) - UInt64(1))
    if exp == 0x7FF and frac != UInt64(0):
        if (frac << UInt64(12)) == UInt64(0):
            return (25, UInt64(0x7E00))
    var h = f64_to_half_bits(v)
    var back = half_to_f64(h)
    if f64_to_bits(back) == bits or (exp == 0x7FF and frac == UInt64(0)):
        if exp == 0x7FF and frac == UInt64(0):
            if (bits >> UInt64(63)) == UInt64(1):
                return (25, UInt64(0xFC00))
            return (25, UInt64(0x7C00))
        if f64_to_bits(back) == bits:
            return (25, UInt64(h))
    var f32 = Float32(v)
    if f64_to_bits(Float64(f32)) == bits:
        return (26, UInt64(f32_to_bits(f32)))
    return (27, bits)


def encoded_float_preferred_len(v: Float64) -> Int:
    return 1 + extra_len(preferred_float_parts(v)[0])


struct WireWriter(Movable):
    """Writes CBOR into one `List[Byte]` at a cursor.

    `encode` pre-sizes the list to `encoded_len` so the hot path stores
    bytes without growing. `ensure` only runs when the estimate was short.
    """

    var buf: List[Byte]
    var pos: Int

    def __init__(out self, *, capacity: Int = 64, exact: Bool = False):
        if exact and capacity > 0:
            self.buf = List[Byte](unsafe_uninit_length=capacity)
        else:
            self.buf = List[Byte](capacity=capacity)
        self.pos = 0

    def __init__(out self, var buf: List[Byte], *, pos: Int = 0):
        self.buf = buf^
        self.pos = pos

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

    def write_bytes_range(mut self, src: List[Byte], start: Int, n: Int):
        if n <= 0:
            return
        self.ensure(n)
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
            src=src.unsafe_ptr().unsafe_offset(start),
            count=n,
        )
        self.pos += n

    def write_head(mut self, major: Int, argument: UInt64):
        var ai = shortest_ai(argument)
        var extra = extra_len(ai)
        self.ensure(1 + extra)
        self.buf[self.pos] = head_byte(major, ai)
        self.pos += 1
        var i = extra
        while i > 0:
            i -= 1
            var shift = UInt64(i) * UInt64(8)
            self.buf[self.pos] = Byte((argument >> shift) & UInt64(0xFF))
            self.pos += 1

    def write_head_raw(mut self, major: Int, ai: Int, argument: UInt64):
        var extra = extra_len(ai)
        self.ensure(1 + extra)
        self.buf[self.pos] = head_byte(major, ai)
        self.pos += 1
        var i = extra
        while i > 0:
            i -= 1
            var shift = UInt64(i) * UInt64(8)
            self.buf[self.pos] = Byte((argument >> shift) & UInt64(0xFF))
            self.pos += 1

    def write_break(mut self):
        self.write_byte(Byte(0xFF))

    def write_uint(mut self, v: UInt64):
        self.write_head(0, v)

    def write_nint_arg(mut self, n: UInt64):
        # major 1, argument n means value -1-n
        self.write_head(1, n)

    def write_int(mut self, v: Int64):
        if v >= Int64(0):
            self.write_uint(UInt64(v))
            return
        var mag = UInt64(-(v + Int64(1)))
        self.write_nint_arg(mag)

    def write_bstr[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        self.write_head(2, UInt64(len(data)))
        self.write_bytes(data)

    def write_tstr(mut self, v: String):
        var b = v.as_bytes()
        self.write_head(3, UInt64(len(b)))
        self.write_bytes(b)

    def write_array_len(mut self, n: Int):
        self.write_head(4, UInt64(n))

    def write_map_len(mut self, n: Int):
        self.write_head(5, UInt64(n))

    def write_tag(mut self, number: UInt64):
        self.write_head(6, number)

    def write_simple(mut self, n: Int):
        if n < 24:
            self.write_byte(Byte(0xE0 | n))
            return
        self.write_head(7, UInt64(n))

    def write_false(mut self):
        self.write_byte(Byte(0xF4))

    def write_true(mut self):
        self.write_byte(Byte(0xF5))

    def write_null(mut self):
        self.write_byte(Byte(0xF6))

    def write_undefined(mut self):
        self.write_byte(Byte(0xF7))

    def write_bool(mut self, v: Bool):
        if v:
            self.write_true()
        else:
            self.write_false()

    def write_float16_bits(mut self, bits: UInt16):
        self.write_head_raw(7, 25, UInt64(bits))

    def write_float32_bits(mut self, bits: UInt32):
        self.write_head_raw(7, 26, UInt64(bits))

    def write_float64_bits(mut self, bits: UInt64):
        self.write_head_raw(7, 27, bits)

    def write_float_preferred(mut self, v: Float64):
        var parts = preferred_float_parts(v)
        if parts[0] == 25:
            self.write_float16_bits(UInt16(parts[1]))
        elif parts[0] == 26:
            self.write_float32_bits(UInt32(parts[1]))
        else:
            self.write_float64_bits(parts[1])

    def finish(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^
