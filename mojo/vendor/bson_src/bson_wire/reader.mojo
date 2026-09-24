from std.collections import List
from std.memory import unsafe_memcpy

from bson_runtime.error import DecodeError
from bson_wire.types import (
    MAX_DEPTH,
    MAX_DOC_BYTES,
    TY_ARRAY,
    TY_BINARY,
    TY_BOOL,
    TY_CODE,
    TY_CODEWS,
    TY_DATETIME,
    TY_DBPOINTER,
    TY_DECIMAL128,
    TY_DOCUMENT,
    TY_DOUBLE,
    TY_INT32,
    TY_INT64,
    TY_MAXKEY,
    TY_MINKEY,
    TY_NULL,
    TY_OBJECTID,
    TY_REGEX,
    TY_STRING,
    TY_SYMBOL,
    TY_TIMESTAMP,
    TY_UNDEFINED,
)


def _has_zero_byte(v: UInt64) -> Bool:
    # SWAR: a zero byte makes (v - 0x01..) borrow into the high bit of that byte.
    var low = UInt64(0x0101010101010101)
    var high = UInt64(0x8080808080808080)
    return ((v - low) & (~v) & high) != UInt64(0)


struct WireReader[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int
    var end: Int

    def __init__(out self, data: Span[Byte, Self.origin]):
        self.data = data
        self.pos = 0
        self.end = len(data)

    def remaining(self) -> Int:
        return self.end - self.pos

    def _need(mut self, n: Int) raises DecodeError:
        if self.pos + n > self.end:
            raise DecodeError(DecodeError.KIND_EOF, self.pos, n)

    def read_u8(mut self) raises DecodeError -> Int:
        self._need(1)
        var b = Int(self.data[self.pos])
        self.pos += 1
        return b

    def read_i32(mut self) raises DecodeError -> Int32:
        self._need(4)
        var v = self.data.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[Int32]()[]
        self.pos += 4
        return v

    def read_i64(mut self) raises DecodeError -> Int64:
        self._need(8)
        var v = self.data.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[Int64]()[]
        self.pos += 8
        return v

    def read_f64(mut self) raises DecodeError -> Float64:
        self._need(8)
        var bits = self.data.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[UInt64]()[]
        self.pos += 8
        return Float64(from_bits=bits)

    def read_raw(mut self, n: Int) raises DecodeError -> List[Byte]:
        if n < 0:
            raise DecodeError(DecodeError.KIND_RANGE, self.pos, n)
        self._need(n)
        var out = List[Byte]()
        if n == 0:
            return out^
        out = List[Byte](unsafe_uninit_length=n)
        unsafe_memcpy(dest=out.unsafe_ptr(), src=self.data.unsafe_ptr().unsafe_offset(self.pos), count=n)
        self.pos += n
        return out^

    def _skip(mut self, n: Int) raises DecodeError:
        if n < 0:
            raise DecodeError(DecodeError.KIND_RANGE, self.pos, n)
        self._need(n)
        self.pos += n

    def read_cstring(mut self) raises DecodeError -> String:
        var start = self.pos
        self._scan_nul()
        var n = self.pos - start
        var tmp = List[Byte]()
        if n > 0:
            tmp = List[Byte](unsafe_uninit_length=n)
            unsafe_memcpy(
                dest=tmp.unsafe_ptr(),
                src=self.data.unsafe_ptr().unsafe_offset(start),
                count=n,
            )
        self.pos += 1
        try:
            return String(from_utf8=Span(unsafe_ptr=tmp.unsafe_ptr(), length=len(tmp)))
        except _:
            raise DecodeError(DecodeError.KIND_UTF8, start, n)

    def key_is(mut self, literal: String) raises DecodeError -> Bool:
        """Consume one cstring. Return true when its bytes equal `literal`."""
        var lit = literal.as_bytes()
        var i = 0
        var matched = True
        while i < len(lit):
            if self.pos >= self.end:
                raise DecodeError(DecodeError.KIND_EOF, self.pos, 1)
            if self.data[self.pos] != lit[i]:
                matched = False
                break
            self.pos += 1
            i += 1
        if matched:
            if self.pos >= self.end:
                raise DecodeError(DecodeError.KIND_EOF, self.pos, 1)
            if self.data[self.pos] != Byte(0):
                matched = False
            else:
                self.pos += 1
                return True
        self._scan_nul()
        self.pos += 1
        return False

    def _scan_nul(mut self) raises DecodeError:
        # Word scan, then a byte tail. A cstring longer than the buffer is EOF.
        while self.pos + 8 <= self.end:
            var w = self.data.unsafe_ptr().unsafe_offset(self.pos).unsafe_bitcast[UInt64]()[]
            if _has_zero_byte(w):
                break
            self.pos += 8
        while self.pos < self.end:
            if self.data[self.pos] == Byte(0):
                return
            self.pos += 1
        raise DecodeError(DecodeError.KIND_EOF, self.pos, 1)

    def read_bson_string(mut self) raises DecodeError -> String:
        var n = Int(self.read_i32())
        if n < 1 or self.pos + n > self.end:
            raise DecodeError(DecodeError.KIND_SIZE, self.pos, n)
        if self.data[self.pos + n - 1] != Byte(0):
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos, n)
        var tmp = List[Byte]()
        var nbytes = n - 1
        if nbytes > 0:
            tmp = List[Byte](unsafe_uninit_length=nbytes)
            unsafe_memcpy(
                dest=tmp.unsafe_ptr(),
                src=self.data.unsafe_ptr().unsafe_offset(self.pos),
                count=nbytes,
            )
        self.pos += n
        try:
            return String(from_utf8=Span(unsafe_ptr=tmp.unsafe_ptr(), length=len(tmp)))
        except _:
            raise DecodeError(DecodeError.KIND_UTF8, self.pos - n, n)

    def enter_document(mut self) raises DecodeError -> Int:
        var start = self.pos
        var n = Int(self.read_i32())
        if n < 5 or n > MAX_DOC_BYTES or start + n > self.end:
            raise DecodeError(DecodeError.KIND_SIZE, start, n)
        if self.data[start + n - 1] != Byte(0):
            raise DecodeError(DecodeError.KIND_SYNTAX, start, n)
        return start + n

    def finish_document(mut self, end: Int) raises DecodeError:
        if self.pos != end - 1:
            raise DecodeError(DecodeError.KIND_SIZE, self.pos, end)
        if self.read_u8() != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos - 1, 0)

    def skip_value(mut self, typ: Int) raises DecodeError:
        if typ == TY_DOUBLE or typ == TY_DATETIME or typ == TY_INT64:
            self._skip(8)
        elif typ == TY_INT32:
            self._skip(4)
        elif typ == TY_BOOL:
            self._skip(1)
        elif typ == TY_NULL or typ == TY_UNDEFINED or typ == TY_MINKEY or typ == TY_MAXKEY:
            return
        elif typ == TY_OBJECTID:
            self._skip(12)
        elif typ == TY_DECIMAL128:
            self._skip(16)
        elif typ == TY_TIMESTAMP:
            self._skip(8)
        elif typ == TY_STRING or typ == TY_CODE or typ == TY_SYMBOL:
            var n = Int(self.read_i32())
            self._skip(n)
        elif typ == TY_DOCUMENT or typ == TY_ARRAY or typ == TY_CODEWS:
            var start = self.pos
            var n = Int(self.read_i32())
            if n < 5 or start + n > self.end:
                raise DecodeError(DecodeError.KIND_SIZE, start, n)
            self.pos = start + n
        elif typ == TY_BINARY:
            var n = Int(self.read_i32())
            self._skip(1 + n)
        elif typ == TY_REGEX:
            self._scan_nul()
            self.pos += 1
            self._scan_nul()
            self.pos += 1
        elif typ == TY_DBPOINTER:
            var n = Int(self.read_i32())
            self._skip(n + 12)
        else:
            raise DecodeError(DecodeError.KIND_TYPE, self.pos, typ)

    def skip_element(mut self, depth: Int) raises DecodeError:
        if depth > MAX_DEPTH:
            raise DecodeError(DecodeError.KIND_DEPTH, self.pos, depth)
        var typ = self.read_u8()
        self._scan_nul()
        self.pos += 1
        self.skip_value(typ)
