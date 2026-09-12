from std.collections import List, Span
from std.memory import unsafe_memcpy

from msgpack_runtime.error import DecodeError
from msgpack_runtime.options import DecodeOptions, MAX_COUNT, MAX_ITEM_BYTES
from msgpack_wire.utf8 import string_from_utf8


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

    def enter(mut self) raises DecodeError:
        if self.depth >= self.options.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, self.pos)
        self.depth += 1

    def leave(mut self):
        if self.depth > 0:
            self.depth -= 1

    def peek_byte(self) raises DecodeError -> Int:
        if self.pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        return Int(self.data[self.pos])

    def take_byte(mut self) raises DecodeError -> Int:
        var b = self.peek_byte()
        self.pos += 1
        return b

    def read_be(mut self, n: Int) raises DecodeError -> UInt64:
        if n < 0 or n > 8:
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)
        if n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        if n == 8:
            var b0 = UInt64(Int(self.data[self.pos]))
            var b1 = UInt64(Int(self.data[self.pos + 1]))
            var b2 = UInt64(Int(self.data[self.pos + 2]))
            var b3 = UInt64(Int(self.data[self.pos + 3]))
            var b4 = UInt64(Int(self.data[self.pos + 4]))
            var b5 = UInt64(Int(self.data[self.pos + 5]))
            var b6 = UInt64(Int(self.data[self.pos + 6]))
            var b7 = UInt64(Int(self.data[self.pos + 7]))
            self.pos += 8
            return (
                (b0 << UInt64(56))
                | (b1 << UInt64(48))
                | (b2 << UInt64(40))
                | (b3 << UInt64(32))
                | (b4 << UInt64(24))
                | (b5 << UInt64(16))
                | (b6 << UInt64(8))
                | b7
            )
        if n == 4:
            var c0 = UInt64(Int(self.data[self.pos]))
            var c1 = UInt64(Int(self.data[self.pos + 1]))
            var c2 = UInt64(Int(self.data[self.pos + 2]))
            var c3 = UInt64(Int(self.data[self.pos + 3]))
            self.pos += 4
            return (c0 << UInt64(24)) | (c1 << UInt64(16)) | (c2 << UInt64(8)) | c3
        if n == 2:
            var d0 = UInt64(Int(self.data[self.pos]))
            var d1 = UInt64(Int(self.data[self.pos + 1]))
            self.pos += 2
            return (d0 << UInt64(8)) | d1
        var out = UInt64(0)
        var i = 0
        while i < n:
            out = (out << UInt64(8)) | UInt64(Int(self.data[self.pos]))
            self.pos += 1
            i += 1
        return out

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

    def check_count(self, n: UInt64) raises DecodeError:
        if n > UInt64(MAX_COUNT):
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)

    def check_len(self, n: Int) raises DecodeError:
        if n < 0 or n > MAX_ITEM_BYTES:
            raise DecodeError(DecodeError.KIND_RANGE, self.pos)
        if n > self.remaining():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)

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

    def try_eat_fixstr[origin2: ImmOrigin](mut self, name: Span[Byte, origin2]) -> Bool:
        """Match a shortest-form string key without allocating."""
        var n = len(name)
        if n > 31:
            return False
        if self.pos + 1 + n > len(self.data):
            return False
        if Int(self.data[self.pos]) != (0xA0 | n):
            return False
        var i = 0
        while i < n:
            if Int(self.data[self.pos + 1 + i]) != Int(name[i]):
                return False
            i += 1
        self.pos += 1 + n
        return True

    def load_u64(self) -> UInt64:
        var p = self.data.unsafe_ptr().unsafe_offset(self.pos)
        return p.bitcast[UInt64]()[]

    def load_u32_at(self, off: Int) -> UInt32:
        var p = self.data.unsafe_ptr().unsafe_offset(self.pos + off)
        return p.bitcast[UInt32]()[]

    def peek_is_str(self) raises DecodeError -> Bool:
        var b = self.peek_byte()
        return (b >= 0xA0 and b <= 0xBF) or b == 0xD9 or b == 0xDA or b == 0xDB

    def peek_is_int(self) raises DecodeError -> Bool:
        var b = self.peek_byte()
        if b <= 0x7F:
            return True
        if b >= 0xE0:
            return True
        return b >= 0xCC and b <= 0xD3

    def peek_is_nil(self) raises DecodeError -> Bool:
        return self.peek_byte() == 0xC0

    def peek_is_bin(self) raises DecodeError -> Bool:
        var b = self.peek_byte()
        return b == 0xC4 or b == 0xC5 or b == 0xC6

    def peek_is_ext(self) raises DecodeError -> Bool:
        var b = self.peek_byte()
        return (b >= 0xC7 and b <= 0xC9) or (b >= 0xD4 and b <= 0xD8)

    def read_nil(mut self) raises DecodeError:
        var b = self.take_byte()
        if b != 0xC0:
            raise DecodeError(DecodeError.KIND_TYPE, self.pos - 1)

    def read_bool(mut self) raises DecodeError -> Bool:
        var b = self.take_byte()
        if b == 0xC3:
            return True
        if b == 0xC2:
            return False
        raise DecodeError(DecodeError.KIND_TYPE, self.pos - 1)

    def _sign_extend(self, bits: UInt64, width: Int) -> Int64:
        if width == 1:
            var v = Int(bits)
            if v >= 128:
                return Int64(v - 256)
            return Int64(v)
        if width == 2:
            var v2 = Int(bits)
            if v2 >= 32768:
                return Int64(v2 - 65536)
            return Int64(v2)
        if width == 4:
            var hi = bits >> UInt64(31)
            if hi == UInt64(1):
                return Int64(bits) - Int64(UInt64(1) << UInt64(32))
            return Int64(bits)
        return Int64(bits)

    def read_i64(mut self) raises DecodeError -> Int64:
        var at = self.pos
        var b = self.take_byte()
        if b == 0xC1:
            raise DecodeError(DecodeError.KIND_UNUSED, at)
        if b <= 0x7F:
            return Int64(b)
        if b >= 0xE0:
            return Int64(b - 256)
        if b == 0xCC:
            return Int64(self.read_be(1))
        if b == 0xCD:
            return Int64(self.read_be(2))
        if b == 0xCE:
            return Int64(self.read_be(4))
        if b == 0xCF:
            var u = self.read_be(8)
            if u > UInt64(Int64.MAX):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return Int64(u)
        if b == 0xD0:
            return self._sign_extend(self.read_be(1), 1)
        if b == 0xD1:
            return self._sign_extend(self.read_be(2), 2)
        if b == 0xD2:
            return self._sign_extend(self.read_be(4), 4)
        if b == 0xD3:
            return Int64(self.read_be(8))
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_u64(mut self) raises DecodeError -> UInt64:
        var at = self.pos
        var b = self.take_byte()
        if b == 0xC1:
            raise DecodeError(DecodeError.KIND_UNUSED, at)
        if b <= 0x7F:
            return UInt64(b)
        if b >= 0xE0:
            raise DecodeError(DecodeError.KIND_RANGE, at)
        if b == 0xCC:
            return self.read_be(1)
        if b == 0xCD:
            return self.read_be(2)
        if b == 0xCE:
            return self.read_be(4)
        if b == 0xCF:
            return self.read_be(8)
        if b == 0xD0:
            var s = self._sign_extend(self.read_be(1), 1)
            if s < Int64(0):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return UInt64(s)
        if b == 0xD1:
            var s2 = self._sign_extend(self.read_be(2), 2)
            if s2 < Int64(0):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return UInt64(s2)
        if b == 0xD2:
            var s4 = self._sign_extend(self.read_be(4), 4)
            if s4 < Int64(0):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return UInt64(s4)
        if b == 0xD3:
            var s8 = Int64(self.read_be(8))
            if s8 < Int64(0):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return UInt64(s8)
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def try_read_int(mut self) raises DecodeError -> Tuple[Bool, Int64, UInt64]:
        """Return (fits_i64, i64, u64). u64 is set when fits_i64 is false."""
        var b = self.peek_byte()
        if b == 0xCF:
            self.pos += 1
            var u = self.read_be(8)
            if u > UInt64(Int64.MAX):
                return (False, Int64(0), u)
            return (True, Int64(u), u)
        return (True, self.read_i64(), UInt64(0))

    def read_int_key(mut self) raises DecodeError -> Optional[Int64]:
        if not self.peek_is_int():
            raise DecodeError(DecodeError.KIND_TYPE, self.pos)
        var t = self.try_read_int()
        if t[0]:
            return Optional[Int64](t[1])
        return Optional[Int64](None)

    def read_f32(mut self) raises DecodeError -> Float32:
        var at = self.pos
        var b = self.take_byte()
        if b != 0xCA:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        var bits = UInt32(self.read_be(4))
        return Float32(from_bits=bits)

    def read_f64(mut self) raises DecodeError -> Float64:
        var at = self.pos
        var b = self.take_byte()
        if b == 0xCA:
            var bits32 = UInt32(self.read_be(4))
            return Float64(Float32(from_bits=bits32))
        if b == 0xCB:
            var bits = self.read_be(8)
            return Float64(from_bits=bits)
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_as_f64(mut self) raises DecodeError -> Float64:
        var at = self.pos
        var b = self.peek_byte()
        if b == 0xCA or b == 0xCB:
            return self.read_f64()
        if self.peek_is_int():
            var t = self.try_read_int()
            if t[0]:
                return Float64(t[1])
            return Float64(t[2])
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def _str_len(mut self) raises DecodeError -> Int:
        var at = self.pos
        var b = self.take_byte()
        if b >= 0xA0 and b <= 0xBF:
            return b & 0x1F
        if b == 0xD9:
            return Int(self.read_be(1))
        if b == 0xDA:
            return Int(self.read_be(2))
        if b == 0xDB:
            var n = self.read_be(4)
            if n > UInt64(MAX_ITEM_BYTES):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return Int(n)
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_str(mut self) raises DecodeError -> String:
        var at = self.pos
        var n = self._str_len()
        self.check_len(n)
        var start = self.pos
        self.pos += n
        return string_from_utf8(self.data[start : start + n], at)

    def _bin_len(mut self) raises DecodeError -> Int:
        var at = self.pos
        var b = self.take_byte()
        if b == 0xC4:
            return Int(self.read_be(1))
        if b == 0xC5:
            return Int(self.read_be(2))
        if b == 0xC6:
            var n = self.read_be(4)
            if n > UInt64(MAX_ITEM_BYTES):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            return Int(n)
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_bin(mut self) raises DecodeError -> List[Byte]:
        var n = self._bin_len()
        return self.read_exact(n)

    def read_array_header(mut self) raises DecodeError -> Int:
        var at = self.pos
        var b = self.take_byte()
        if b >= 0x90 and b <= 0x9F:
            return b & 0x0F
        if b == 0xDC:
            var n = self.read_be(2)
            self.check_count(n)
            return Int(n)
        if b == 0xDD:
            var n32 = self.read_be(4)
            self.check_count(n32)
            return Int(n32)
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def read_map_header(mut self) raises DecodeError -> Int:
        var at = self.pos
        var b = self.take_byte()
        if b >= 0x80 and b <= 0x8F:
            return b & 0x0F
        if b == 0xDE:
            var n = self.read_be(2)
            self.check_count(n)
            return Int(n)
        if b == 0xDF:
            var n32 = self.read_be(4)
            self.check_count(n32)
            return Int(n32)
        raise DecodeError(DecodeError.KIND_TYPE, at)

    def _ext_header(mut self) raises DecodeError -> Tuple[Int8, Int]:
        var at = self.pos
        var b = self.take_byte()
        var n = 0
        if b == 0xD4:
            n = 1
        elif b == 0xD5:
            n = 2
        elif b == 0xD6:
            n = 4
        elif b == 0xD7:
            n = 8
        elif b == 0xD8:
            n = 16
        elif b == 0xC7:
            n = Int(self.read_be(1))
        elif b == 0xC8:
            n = Int(self.read_be(2))
        elif b == 0xC9:
            var n32 = self.read_be(4)
            if n32 > UInt64(MAX_ITEM_BYTES):
                raise DecodeError(DecodeError.KIND_RANGE, at)
            n = Int(n32)
        else:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        var tb = self.take_byte()
        var t = Int8(tb)
        if tb >= 128:
            t = Int8(tb - 256)
        return (t, n)

    def read_ext(mut self) raises DecodeError -> Tuple[Int8, List[Byte]]:
        var h = self._ext_header()
        var payload = self.read_exact(h[1])
        return (h[0], payload^)

    def read_timestamp(mut self) raises DecodeError -> Tuple[Int64, Int]:
        var at = self.pos
        var h = self._ext_header()
        if Int(h[0]) != -1:
            raise DecodeError(DecodeError.KIND_TYPE, at)
        if h[1] != 4 and h[1] != 8 and h[1] != 12:
            raise DecodeError(DecodeError.KIND_EXT, at)
        var payload = self.read_exact(h[1])
        var ts = timestamp_from_payload(payload, at)
        return (ts[0], ts[1])

    def skip_value(mut self) raises DecodeError:
        var at = self.pos
        var b = self.peek_byte()
        if b == 0xC1:
            raise DecodeError(DecodeError.KIND_UNUSED, at)
        if b <= 0x7F or b >= 0xE0 or b == 0xC0 or b == 0xC2 or b == 0xC3:
            self.pos += 1
            return
        if b == 0xCC or b == 0xD0:
            self.pos += 1
            _ = self.read_exact(1)
            return
        if b == 0xCD or b == 0xD1:
            self.pos += 1
            _ = self.read_exact(2)
            return
        if b == 0xCE or b == 0xD2 or b == 0xCA:
            self.pos += 1
            _ = self.read_exact(4)
            return
        if b == 0xCF or b == 0xD3 or b == 0xCB:
            self.pos += 1
            _ = self.read_exact(8)
            return
        if (b >= 0xA0 and b <= 0xBF) or b == 0xD9 or b == 0xDA or b == 0xDB:
            var n = self._str_len()
            self.check_len(n)
            self.pos += n
            return
        if b == 0xC4 or b == 0xC5 or b == 0xC6:
            var bn = self._bin_len()
            _ = self.read_exact(bn)
            return
        if (b >= 0xC7 and b <= 0xC9) or (b >= 0xD4 and b <= 0xD8):
            var eh = self._ext_header()
            _ = self.read_exact(eh[1])
            return
        if (b >= 0x90 and b <= 0x9F) or b == 0xDC or b == 0xDD:
            self.enter()
            var an = self.read_array_header()
            var i = 0
            while i < an:
                self.skip_value()
                i += 1
            self.leave()
            return
        if (b >= 0x80 and b <= 0x8F) or b == 0xDE or b == 0xDF:
            self.enter()
            var mn = self.read_map_header()
            var j = 0
            while j < mn:
                self.skip_value()
                self.skip_value()
                j += 1
            self.leave()
            return
        raise DecodeError(DecodeError.KIND_SYNTAX, at)


def timestamp_from_payload(
    payload: List[Byte], offset: Int
) raises DecodeError -> Tuple[Int64, Int]:
    var n = len(payload)
    if n == 4:
        var sec = (
            (UInt64(Int(payload[0])) << UInt64(24))
            | (UInt64(Int(payload[1])) << UInt64(16))
            | (UInt64(Int(payload[2])) << UInt64(8))
            | UInt64(Int(payload[3]))
        )
        return (Int64(sec), 0)
    if n == 8:
        var hi = (
            (UInt64(Int(payload[0])) << UInt64(24))
            | (UInt64(Int(payload[1])) << UInt64(16))
            | (UInt64(Int(payload[2])) << UInt64(8))
            | UInt64(Int(payload[3]))
        )
        var lo = (
            (UInt64(Int(payload[4])) << UInt64(24))
            | (UInt64(Int(payload[5])) << UInt64(16))
            | (UInt64(Int(payload[6])) << UInt64(8))
            | UInt64(Int(payload[7]))
        )
        var packed = (hi << UInt64(32)) | lo
        var nsec = Int((packed >> UInt64(34)) & UInt64(0x3FFFFFFF))
        var sec64 = packed & ((UInt64(1) << UInt64(34)) - UInt64(1))
        if nsec >= 1_000_000_000:
            raise DecodeError(DecodeError.KIND_RANGE, offset)
        return (Int64(sec64), nsec)
    if n == 12:
        var nsec32 = (
            (Int(payload[0]) << 24)
            | (Int(payload[1]) << 16)
            | (Int(payload[2]) << 8)
            | Int(payload[3])
        )
        var secb = (
            (UInt64(Int(payload[4])) << UInt64(56))
            | (UInt64(Int(payload[5])) << UInt64(48))
            | (UInt64(Int(payload[6])) << UInt64(40))
            | (UInt64(Int(payload[7])) << UInt64(32))
            | (UInt64(Int(payload[8])) << UInt64(24))
            | (UInt64(Int(payload[9])) << UInt64(16))
            | (UInt64(Int(payload[10])) << UInt64(8))
            | UInt64(Int(payload[11]))
        )
        if nsec32 >= 1_000_000_000:
            raise DecodeError(DecodeError.KIND_RANGE, offset)
        return (Int64(secb), nsec32)
    raise DecodeError(DecodeError.KIND_EXT, offset)
