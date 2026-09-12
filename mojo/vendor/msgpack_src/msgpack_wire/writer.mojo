from std.collections import List, Span
from std.memory import unsafe_memcpy

from msgpack_runtime.options import MAX_ITEM_BYTES


def encoded_int_len(v: Int64) -> Int:
    if v >= Int64(0) and v <= Int64(127):
        return 1
    if v >= Int64(-32) and v <= Int64(-1):
        return 1
    if v >= Int64(128) and v <= Int64(255):
        return 2
    if v >= Int64(-128) and v <= Int64(-33):
        return 2
    if v >= Int64(256) and v <= Int64(65535):
        return 3
    if v >= Int64(-32768) and v <= Int64(-129):
        return 3
    if v >= Int64(65536) and v <= Int64(4294967295):
        return 5
    if v >= Int64(-2147483648) and v <= Int64(-32769):
        return 5
    return 9


def encoded_uint_len(v: UInt64) -> Int:
    if v <= UInt64(127):
        return 1
    if v <= UInt64(255):
        return 2
    if v <= UInt64(65535):
        return 3
    if v <= UInt64(4294967295):
        return 5
    return 9


def encoded_str_len(n: Int) -> Int:
    if n <= 31:
        return 1 + n
    if n <= 255:
        return 2 + n
    if n <= 65535:
        return 3 + n
    return 5 + n


def encoded_bin_len(n: Int) -> Int:
    if n <= 255:
        return 2 + n
    if n <= 65535:
        return 3 + n
    return 5 + n


def encoded_array_header_len(n: Int) -> Int:
    if n <= 15:
        return 1
    if n <= 65535:
        return 3
    return 5


def encoded_map_header_len(n: Int) -> Int:
    return encoded_array_header_len(n)


def encoded_ext_len(n: Int) -> Int:
    if n == 1 or n == 2 or n == 4 or n == 8 or n == 16:
        return 2 + n
    if n <= 255:
        return 3 + n
    if n <= 65535:
        return 4 + n
    return 6 + n


def encoded_f32_len() -> Int:
    return 5


def encoded_f64_len() -> Int:
    return 9


struct WireWriter(Movable):
    """Writes MessagePack into one `List[Byte]` at a cursor.

    `encode` pre-sizes the list so the hot path stores bytes without growing.
    `ensure` only runs when the estimate was short.
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

    def write_be(mut self, argument: UInt64, n: Int):
        if n == 8:
            self.ensure(8)
            self.buf[self.pos] = Byte((argument >> UInt64(56)) & UInt64(0xFF))
            self.buf[self.pos + 1] = Byte((argument >> UInt64(48)) & UInt64(0xFF))
            self.buf[self.pos + 2] = Byte((argument >> UInt64(40)) & UInt64(0xFF))
            self.buf[self.pos + 3] = Byte((argument >> UInt64(32)) & UInt64(0xFF))
            self.buf[self.pos + 4] = Byte((argument >> UInt64(24)) & UInt64(0xFF))
            self.buf[self.pos + 5] = Byte((argument >> UInt64(16)) & UInt64(0xFF))
            self.buf[self.pos + 6] = Byte((argument >> UInt64(8)) & UInt64(0xFF))
            self.buf[self.pos + 7] = Byte(argument & UInt64(0xFF))
            self.pos += 8
            return
        if n == 4:
            self.ensure(4)
            self.buf[self.pos] = Byte((argument >> UInt64(24)) & UInt64(0xFF))
            self.buf[self.pos + 1] = Byte((argument >> UInt64(16)) & UInt64(0xFF))
            self.buf[self.pos + 2] = Byte((argument >> UInt64(8)) & UInt64(0xFF))
            self.buf[self.pos + 3] = Byte(argument & UInt64(0xFF))
            self.pos += 4
            return
        if n == 2:
            self.ensure(2)
            self.buf[self.pos] = Byte((argument >> UInt64(8)) & UInt64(0xFF))
            self.buf[self.pos + 1] = Byte(argument & UInt64(0xFF))
            self.pos += 2
            return
        self.ensure(n)
        var i = n
        while i > 0:
            i -= 1
            var shift = UInt64(i) * UInt64(8)
            self.buf[self.pos] = Byte((argument >> shift) & UInt64(0xFF))
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

    def write_nil(mut self):
        self.write_byte(Byte(0xC0))

    def write_bool(mut self, v: Bool):
        if v:
            self.write_byte(Byte(0xC3))
        else:
            self.write_byte(Byte(0xC2))

    def write_int(mut self, v: Int64):
        if v >= Int64(-32) and v <= Int64(127):
            self.ensure(1)
            self.buf[self.pos] = Byte(Int(v) & 0xFF)
            self.pos += 1
            return
        if v >= Int64(128) and v <= Int64(255):
            self.ensure(2)
            self.buf[self.pos] = Byte(0xCC)
            self.buf[self.pos + 1] = Byte(Int(v))
            self.pos += 2
            return
        if v >= Int64(-128) and v <= Int64(-33):
            self.write_byte(Byte(0xD0))
            self.write_byte(Byte(Int(v) & 0xFF))
            return
        if v >= Int64(256) and v <= Int64(65535):
            self.write_byte(Byte(0xCD))
            self.write_be(UInt64(v), 2)
            return
        if v >= Int64(-32768) and v <= Int64(-129):
            self.write_byte(Byte(0xD1))
            self.write_be(UInt64(Int(v) & 0xFFFF), 2)
            return
        if v >= Int64(65536) and v <= Int64(4294967295):
            self.write_byte(Byte(0xCE))
            self.write_be(UInt64(v), 4)
            return
        if v >= Int64(-2147483648) and v <= Int64(-32769):
            self.write_byte(Byte(0xD2))
            self.write_be(UInt64(UInt32(Int(v))), 4)
            return
        if v >= Int64(0):
            self.write_byte(Byte(0xCF))
            self.write_be(UInt64(v), 8)
            return
        self.write_byte(Byte(0xD3))
        self.write_be(UInt64(v), 8)

    def write_uint(mut self, v: UInt64):
        if v <= UInt64(Int64.MAX):
            self.write_int(Int64(v))
            return
        self.write_byte(Byte(0xCF))
        self.write_be(v, 8)

    def write_f32_bits(mut self, bits: UInt32):
        self.write_byte(Byte(0xCA))
        self.write_be(UInt64(bits), 4)

    def write_f64_bits(mut self, bits: UInt64):
        self.write_byte(Byte(0xCB))
        self.write_be(bits, 8)

    def write_f32(mut self, v: Float32):
        self.write_f32_bits(UInt32(v.to_bits()))

    def write_f64(mut self, v: Float64):
        var bits = UInt64(v.to_bits())
        self.ensure(9)
        self.buf[self.pos] = Byte(0xCB)
        var be = (
            ((bits & UInt64(0x00000000000000FF)) << UInt64(56))
            | ((bits & UInt64(0x000000000000FF00)) << UInt64(40))
            | ((bits & UInt64(0x0000000000FF0000)) << UInt64(24))
            | ((bits & UInt64(0x00000000FF000000)) << UInt64(8))
            | ((bits & UInt64(0x000000FF00000000)) >> UInt64(8))
            | ((bits & UInt64(0x0000FF0000000000)) >> UInt64(24))
            | ((bits & UInt64(0x00FF000000000000)) >> UInt64(40))
            | ((bits & UInt64(0xFF00000000000000)) >> UInt64(56))
        )
        self.buf.unsafe_ptr().unsafe_offset(self.pos + 1).unsafe_bitcast[UInt64]()[] = be
        self.pos += 9

    def write_str_header(mut self, n: Int):
        if n <= 31:
            self.write_byte(Byte(0xA0 | n))
        elif n <= 255:
            self.write_byte(Byte(0xD9))
            self.write_byte(Byte(n))
        elif n <= 65535:
            self.write_byte(Byte(0xDA))
            self.write_be(UInt64(n), 2)
        else:
            self.write_byte(Byte(0xDB))
            self.write_be(UInt64(n), 4)

    def write_bin_header(mut self, n: Int):
        if n <= 255:
            self.write_byte(Byte(0xC4))
            self.write_byte(Byte(n))
        elif n <= 65535:
            self.write_byte(Byte(0xC5))
            self.write_be(UInt64(n), 2)
        else:
            self.write_byte(Byte(0xC6))
            self.write_be(UInt64(n), 4)

    def write_str(mut self, v: String):
        var b = v.as_bytes()
        var n = len(b)
        if n <= 31:
            self.write_fixstr(b)
            return
        self.write_str_header(n)
        self.write_bytes(b)

    def write_lit(mut self, word: UInt64, n: Int):
        """Store `n` little-endian bytes of `word` (1…8). Used for baked keys."""
        self.ensure(n)
        if self.pos + 8 <= len(self.buf):
            var p = self.buf.unsafe_ptr().unsafe_offset(self.pos)
            p.unsafe_bitcast[UInt64]()[] = word
            self.pos += n
            return
        var i = 0
        while i < n:
            self.buf[self.pos + i] = Byte((word >> UInt64(i * 8)) & UInt64(0xFF))
            i += 1
        self.pos += n

    def write_fixstr[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        """One-header memcpy of a short UTF-8 key or value (length 0…31)."""
        var n = len(data)
        self.ensure(1 + n)
        self.buf[self.pos] = Byte(0xA0 | n)
        self.pos += 1
        if n > 0:
            unsafe_memcpy(
                dest=self.buf.unsafe_ptr().unsafe_offset(self.pos),
                src=data.unsafe_ptr(),
                count=n,
            )
            self.pos += n

    def write_bin[origin: ImmOrigin](mut self, data: Span[Byte, origin]):
        self.write_bin_header(len(data))
        self.write_bytes(data)

    def write_array_header(mut self, n: Int):
        if n <= 15:
            self.write_byte(Byte(0x90 | n))
        elif n <= 65535:
            self.write_byte(Byte(0xDC))
            self.write_be(UInt64(n), 2)
        else:
            self.write_byte(Byte(0xDD))
            self.write_be(UInt64(n), 4)

    def write_map_header(mut self, n: Int):
        if n <= 15:
            self.write_byte(Byte(0x80 | n))
        elif n <= 65535:
            self.write_byte(Byte(0xDE))
            self.write_be(UInt64(n), 2)
        else:
            self.write_byte(Byte(0xDF))
            self.write_be(UInt64(n), 4)

    def write_ext_header(mut self, t: Int8, n: Int):
        var tb = Byte(Int(t) & 0xFF)
        if n == 1:
            self.write_byte(Byte(0xD4))
            self.write_byte(tb)
        elif n == 2:
            self.write_byte(Byte(0xD5))
            self.write_byte(tb)
        elif n == 4:
            self.write_byte(Byte(0xD6))
            self.write_byte(tb)
        elif n == 8:
            self.write_byte(Byte(0xD7))
            self.write_byte(tb)
        elif n == 16:
            self.write_byte(Byte(0xD8))
            self.write_byte(tb)
        elif n <= 255:
            self.write_byte(Byte(0xC7))
            self.write_byte(Byte(n))
            self.write_byte(tb)
        elif n <= 65535:
            self.write_byte(Byte(0xC8))
            self.write_be(UInt64(n), 2)
            self.write_byte(tb)
        else:
            self.write_byte(Byte(0xC9))
            self.write_be(UInt64(n), 4)
            self.write_byte(tb)

    def write_ext[origin: ImmOrigin](mut self, t: Int8, data: Span[Byte, origin]):
        self.write_ext_header(t, len(data))
        self.write_bytes(data)

    def finish(deinit self) -> List[Byte]:
        if self.pos < len(self.buf):
            self.buf.resize(unsafe_uninit_length=self.pos)
        return self.buf^

    def finish_keep(deinit self) -> List[Byte]:
        """Return the buffer without shrinking. `pos` is the live prefix."""
        return self.buf^
