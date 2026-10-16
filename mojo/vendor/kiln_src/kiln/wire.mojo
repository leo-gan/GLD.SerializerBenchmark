from std.collections import List, Span
from std.memory import unsafe_memcpy

from kiln.error import KilnError
from kiln.utf8 import string_from_span, utf8_ok


comptime PROFILE_FROZEN = 0
comptime PROFILE_EVOLVE = 1
comptime PROFILE_VIEW = 2
comptime PROFILE_TENSOR = 3
comptime PROFILE_COLUMNS = 4

comptime MAX_BYTES = 16777216
comptime MAX_COUNT = 16777216
comptime MAX_DEPTH = 64
comptime FRAME_LEN = 16


struct Writer(Movable):
    """A reusable little-endian byte sink.

    The caller keeps the writer and calls `encode`, which sets the
    length back to zero and writes into the existing allocation when
    the value fits. Growth copies the bytes already written and then
    doubles capacity.
    """

    var buf: List[UInt8]
    var length: Int
    var depth: Int
    var max_depth: Int

    def __init__(out self, capacity: Int = 256):
        var cap = capacity
        if cap < 64:
            cap = 64
        self.buf = List[UInt8](unsafe_uninit_length=cap)
        self.length = 0
        self.depth = 0
        self.max_depth = MAX_DEPTH

    def reset(mut self):
        self.length = 0
        self.depth = 0

    @always_inline
    def enter(mut self) raises KilnError:
        if self.depth >= self.max_depth:
            raise KilnError(KilnError.DEPTH, self.length)
        self.depth += 1

    @always_inline
    def leave(mut self):
        if self.depth > 0:
            self.depth -= 1

    @always_inline
    def ensure(mut self, extra: Int):
        """Grow so `length + extra` bytes fit. Does not advance `length`."""
        var need = self.length + extra
        var cap = len(self.buf)
        if need <= cap:
            return
        var ncap = cap
        if ncap < 64:
            ncap = 64
        while ncap < need:
            ncap = ncap * 2
        var grown = List[UInt8](unsafe_uninit_length=ncap)
        if self.length > 0:
            unsafe_memcpy(
                dest=grown.unsafe_ptr(),
                src=self.buf.unsafe_ptr(),
                count=self.length,
            )
        self.buf = grown^

    def reserve(mut self, n: Int) -> Int:
        """Reserve `n` bytes and return the index they start at."""
        var i = self.length
        self.ensure(n)
        self.length = i + n
        return i

    @always_inline
    def put_u8(mut self, v: UInt8):
        var i = self.length
        if i + 1 > len(self.buf):
            self.ensure(1)
            i = self.length
        self.buf.unsafe_ptr()[unsafe_offset=i] = v
        self.length = i + 1

    @always_inline
    def put_u16(mut self, v: UInt16):
        var i = self.length
        if i + 2 > len(self.buf):
            self.ensure(2)
            i = self.length
        var p = self.buf.unsafe_ptr()
        p[unsafe_offset=i] = UInt8(v)
        p[unsafe_offset=i + 1] = UInt8(v >> 8)
        self.length = i + 2

    @always_inline
    def put_u32(mut self, v: UInt32):
        var i = self.length
        if i + 4 > len(self.buf):
            self.ensure(4)
            i = self.length
        var p = self.buf.unsafe_ptr()
        p[unsafe_offset=i] = UInt8(v)
        p[unsafe_offset=i + 1] = UInt8(v >> 8)
        p[unsafe_offset=i + 2] = UInt8(v >> 16)
        p[unsafe_offset=i + 3] = UInt8(v >> 24)
        self.length = i + 4

    @always_inline
    def put_u64(mut self, v: UInt64):
        var i = self.length
        if i + 8 > len(self.buf):
            self.ensure(8)
            i = self.length
        var p = self.buf.unsafe_ptr()
        p[unsafe_offset=i] = UInt8(v)
        p[unsafe_offset=i + 1] = UInt8(v >> 8)
        p[unsafe_offset=i + 2] = UInt8(v >> 16)
        p[unsafe_offset=i + 3] = UInt8(v >> 24)
        p[unsafe_offset=i + 4] = UInt8(v >> 32)
        p[unsafe_offset=i + 5] = UInt8(v >> 40)
        p[unsafe_offset=i + 6] = UInt8(v >> 48)
        p[unsafe_offset=i + 7] = UInt8(v >> 56)
        self.length = i + 8

    @always_inline
    def put_i32(mut self, v: Int32):
        self.put_u32(UInt32(v.to_bits()))

    @always_inline
    def put_i64(mut self, v: Int64):
        self.put_u64(UInt64(v.to_bits()))

    @always_inline
    def put_f32(mut self, v: Float32):
        self.put_u32(UInt32(v.to_bits()))

    @always_inline
    def put_f64(mut self, v: Float64):
        self.put_u64(UInt64(v.to_bits()))

    @always_inline
    def put_span[origin: ImmOrigin](mut self, sp: Span[UInt8, origin]):
        var n = len(sp)
        if n == 0:
            return
        var i = self.length
        if i + n > len(self.buf):
            self.ensure(n)
            i = self.length
        unsafe_memcpy(
            dest=self.buf.unsafe_ptr().unsafe_offset(i),
            src=sp.unsafe_ptr(),
            count=n,
        )
        self.length = i + n

    def copy_bytes(self) -> List[UInt8]:
        """A list whose length is the number of bytes written."""
        var n = self.length
        var out = List[UInt8](unsafe_uninit_length=n)
        if n > 0:
            unsafe_memcpy(dest=out.unsafe_ptr(), src=self.buf.unsafe_ptr(), count=n)
        return out^


struct Reader[origin: ImmOrigin](Movable):
    """A forward cursor over a borrowed Kiln buffer.

    Lengths are rejected when they extend past the buffer, so a hostile
    count cannot allocate. `check_utf8` applies to strings.
    """

    var data: Span[UInt8, Self.origin]
    var pos: Int
    var depth: Int
    var max_depth: Int
    var check_utf8: Bool

    def __init__(
        out self,
        data: Span[UInt8, Self.origin],
        check_utf8: Bool = True,
        max_depth: Int = MAX_DEPTH,
    ):
        self.data = data
        self.pos = 0
        self.depth = 0
        self.max_depth = max_depth
        self.check_utf8 = check_utf8

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    @always_inline
    def enter(mut self) raises KilnError:
        if self.depth >= self.max_depth:
            raise KilnError(KilnError.DEPTH, self.pos)
        self.depth += 1

    @always_inline
    def leave(mut self):
        if self.depth > 0:
            self.depth -= 1

    @always_inline
    def u8_fast(mut self) -> UInt8:
        var b = self.data.unsafe_ptr()[unsafe_offset=self.pos]
        self.pos += 1
        return b

    @always_inline
    def u32_fast(mut self) -> UInt32:
        var i = self.pos
        var p = self.data.unsafe_ptr()
        var v = (
            UInt32(p[unsafe_offset=i])
            | (UInt32(p[unsafe_offset=i + 1]) << 8)
            | (UInt32(p[unsafe_offset=i + 2]) << 16)
            | (UInt32(p[unsafe_offset=i + 3]) << 24)
        )
        self.pos = i + 4
        return v

    @always_inline
    def u64_fast(mut self) -> UInt64:
        var i = self.pos
        var p = self.data.unsafe_ptr()
        var v = UInt64(p[unsafe_offset=i])
        v = v | (UInt64(p[unsafe_offset=i + 1]) << 8)
        v = v | (UInt64(p[unsafe_offset=i + 2]) << 16)
        v = v | (UInt64(p[unsafe_offset=i + 3]) << 24)
        v = v | (UInt64(p[unsafe_offset=i + 4]) << 32)
        v = v | (UInt64(p[unsafe_offset=i + 5]) << 40)
        v = v | (UInt64(p[unsafe_offset=i + 6]) << 48)
        v = v | (UInt64(p[unsafe_offset=i + 7]) << 56)
        self.pos = i + 8
        return v

    @always_inline
    def str_fast(mut self) -> StringSpan[Self.origin]:
        var n = Int(self.u32_fast())
        var start = self.pos
        self.pos += n
        return StringSpan(unsafe_from_utf8=self.data[start:self.pos])

    @always_inline
    def u8(mut self) raises KilnError -> UInt8:
        var i = self.pos
        if i >= len(self.data):
            raise KilnError(KilnError.EOF, i)
        var b = self.data.unsafe_ptr()[unsafe_offset=i]
        self.pos = i + 1
        return b

    @always_inline
    def u16(mut self) raises KilnError -> UInt16:
        var i = self.pos
        if i + 2 > len(self.data):
            raise KilnError(KilnError.EOF, i)
        var p = self.data.unsafe_ptr()
        var v = UInt16(p[unsafe_offset=i]) | (UInt16(p[unsafe_offset=i + 1]) << 8)
        self.pos = i + 2
        return v

    @always_inline
    def u32(mut self) raises KilnError -> UInt32:
        var i = self.pos
        if i + 4 > len(self.data):
            raise KilnError(KilnError.EOF, i)
        var p = self.data.unsafe_ptr()
        var v = (
            UInt32(p[unsafe_offset=i])
            | (UInt32(p[unsafe_offset=i + 1]) << 8)
            | (UInt32(p[unsafe_offset=i + 2]) << 16)
            | (UInt32(p[unsafe_offset=i + 3]) << 24)
        )
        self.pos = i + 4
        return v

    @always_inline
    def u64(mut self) raises KilnError -> UInt64:
        var i = self.pos
        if i + 8 > len(self.data):
            raise KilnError(KilnError.EOF, i)
        var p = self.data.unsafe_ptr()
        var v = UInt64(p[unsafe_offset=i])
        v = v | (UInt64(p[unsafe_offset=i + 1]) << 8)
        v = v | (UInt64(p[unsafe_offset=i + 2]) << 16)
        v = v | (UInt64(p[unsafe_offset=i + 3]) << 24)
        v = v | (UInt64(p[unsafe_offset=i + 4]) << 32)
        v = v | (UInt64(p[unsafe_offset=i + 5]) << 40)
        v = v | (UInt64(p[unsafe_offset=i + 6]) << 48)
        v = v | (UInt64(p[unsafe_offset=i + 7]) << 56)
        self.pos = i + 8
        return v

    @always_inline
    def i32(mut self) raises KilnError -> Int32:
        return Int32(from_bits=self.u32())

    @always_inline
    def i64(mut self) raises KilnError -> Int64:
        return Int64(from_bits=self.u64())

    @always_inline
    def f32(mut self) raises KilnError -> Float32:
        return Float32(from_bits=self.u32())

    @always_inline
    def f64(mut self) raises KilnError -> Float64:
        return Float64(from_bits=self.u64())

    @always_inline
    def boolean(mut self) raises KilnError -> Bool:
        var b = Int(self.u8())
        if b == 0:
            return False
        if b == 1:
            return True
        raise KilnError(KilnError.TYPE, self.pos - 1)

    def count(mut self) raises KilnError -> Int:
        var n = Int(self.u32())
        if n < 0 or n > MAX_COUNT:
            raise KilnError(KilnError.LIMIT, self.pos - 4)
        return n

    def take(mut self, n: Int) raises KilnError -> Span[UInt8, Self.origin]:
        if n < 0 or n > MAX_BYTES:
            raise KilnError(KilnError.LIMIT, self.pos)
        if self.pos + n > len(self.data):
            raise KilnError(KilnError.EOF, self.pos)
        var start = self.pos
        self.pos += n
        return self.data[start:self.pos]

    @always_inline
    def read_string(mut self) raises KilnError -> String:
        var n = self.count()
        var start = self.pos
        var sp = self.take(n)
        return string_from_span(sp, start, self.check_utf8)

    def read_string_slice(mut self) raises KilnError -> StringSpan[Self.origin]:
        """A view of the string bytes. The slice lives as long as `data`."""
        var n = self.count()
        var start = self.pos
        var sp = self.take(n)
        if self.check_utf8 and not utf8_ok(sp):
            raise KilnError(KilnError.UTF8, start)
        return StringSpan(unsafe_from_utf8=sp)
