from std.collections import List, Span

from parquet_runtime.buf import buf_need, put_u8, string_from, u64_at
from parquet_runtime.error import DecodeError


comptime T_BOOL_TRUE = 1
comptime T_BOOL_FALSE = 2
comptime T_BYTE = 3
comptime T_I16 = 4
comptime T_I32 = 5
comptime T_I64 = 6
comptime T_DOUBLE = 7
comptime T_BINARY = 8
comptime T_LIST = 9
comptime T_SET = 10
comptime T_MAP = 11
comptime T_STRUCT = 12


def _sl(v: UInt64, n: Int) -> UInt64:
    return v << UInt64(n)


def _sr(v: UInt64, n: Int) -> UInt64:
    return v >> UInt64(n)


def zz_from(u: UInt64) -> Int:
    var mag = _sr(u, 1)
    if (u & 1) == 0:
        return Int(mag)
    if mag == 0:
        return -1
    var neg = ~mag
    return Int(neg)


def zz_to(n: Int) -> UInt64:
    var u = UInt64(n)
    var sign = _sr(u, 63)
    return _sl(u, 1) ^ (UInt64(0) - sign)


struct TOut:
    var b: List[Byte]
    var last: Int

    def __init__(out self):
        self.b = List[Byte](capacity=256)
        self.last = 0

    def uvar(mut self, v: UInt64):
        var x = v
        while x >= 128:
            self.b.append(Byte(Int((x & 127) | 128)))
            x = _sr(x, 7)
        self.b.append(Byte(Int(x)))

    def field(mut self, id: Int, typ: Int):
        var delta = id - self.last
        if delta > 0 and delta < 16:
            self.b.append(Byte((delta << 4) | typ))
        else:
            self.b.append(Byte(typ))
            self.uvar(UInt64(id))
        self.last = id

    def stop(mut self):
        self.b.append(Byte(0))

    def begin(mut self, id: Int) -> Int:
        self.field(id, T_STRUCT)
        var mine = self.last
        self.last = 0
        return mine

    def end(mut self, mine: Int):
        self.stop()
        self.last = mine

    def i32(mut self, id: Int, v: Int):
        self.field(id, T_I32)
        self.uvar(zz_to(v))

    def i64(mut self, id: Int, v: Int):
        self.field(id, T_I64)
        self.uvar(zz_to(v))

    def bool(mut self, id: Int, v: Int):
        if v != 0:
            self.field(id, T_BOOL_TRUE)
        else:
            self.field(id, T_BOOL_FALSE)

    def binary(mut self, id: Int, raw: List[Byte]):
        self.field(id, T_BINARY)
        self.uvar(UInt64(len(raw)))
        var i = 0
        while i < len(raw):
            self.b.append(raw[i])
            i += 1

    def text(mut self, id: Int, value: String):
        var raw = value.as_bytes()
        self.field(id, T_BINARY)
        self.uvar(UInt64(len(raw)))
        var i = 0
        while i < len(raw):
            self.b.append(raw[i])
            i += 1

    def list_begin(mut self, id: Int, et: Int, n: Int) -> Int:
        self.field(id, T_LIST)
        var mine = self.last
        if n < 15:
            self.b.append(Byte((n << 4) | et))
        else:
            self.b.append(Byte(0xF0 | et))
            self.uvar(UInt64(n))
        self.last = 0
        return mine

    def finish_list(mut self, mine: Int):
        self.last = mine


struct TRead[origin: ImmOrigin]:
    var raw: Span[Byte, Self.origin]
    var i: Int
    var last: Int
    var fid: Int
    var typ: Int

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.last = 0
        self.fid = 0
        self.typ = 0

    def need(self, n: Int) raises DecodeError:
        buf_need(len(self.raw), n, self.i)

    def byte(mut self) raises DecodeError -> Int:
        if self.i < 0 or self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var v = Int(self.raw[self.i])
        self.i += 1
        return v

    def uvar(mut self) raises DecodeError -> UInt64:
        var shift = 0
        var out = UInt64(0)
        while True:
            var b = self.byte()
            out = out | _sl(UInt64(b & 127), shift)
            if b < 128:
                return out
            shift += 7
            if shift > 63:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)

    def zz(mut self) raises DecodeError -> Int:
        return zz_from(self.uvar())

    def next(mut self) raises DecodeError -> Int:
        var b = self.byte()
        if b == 0:
            self.typ = 0
            self.fid = 0
            return 0
        var delta = b >> 4
        self.typ = b & 15
        if delta == 0:
            self.fid = Int(self.uvar())
        else:
            self.fid = self.last + delta
        self.last = self.fid
        return 1

    def enter(mut self) -> Int:
        var prev = self.last
        self.last = 0
        return prev

    def leave(mut self, prev: Int):
        self.last = prev

    def read_i32(mut self) raises DecodeError -> Int:
        if self.typ != T_I32 and self.typ != T_I16 and self.typ != T_BYTE:
            raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)
        return self.zz()

    def read_i64(mut self) raises DecodeError -> Int:
        if self.typ != T_I64 and self.typ != T_I32 and self.typ != T_I16 and self.typ != T_BYTE:
            raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)
        return self.zz()

    def read_bool(self) raises DecodeError -> Int:
        if self.typ == T_BOOL_TRUE:
            return 1
        if self.typ == T_BOOL_FALSE:
            return 0
        raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)

    def read_double(mut self) raises DecodeError -> UInt64:
        if self.typ != T_DOUBLE:
            raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)
        var v = u64_at(self.raw, self.i)
        self.i += 8
        return v

    def read_bin(mut self) raises DecodeError -> List[Byte]:
        if self.typ != T_BINARY:
            raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)
        var n = Int(self.uvar())
        if n < 0 or n > 268435456:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        self.need(n)
        var out = List[Byte]()
        out.resize(n, Byte(0))
        var k = 0
        while k < n:
            out[k] = self.raw[self.i + k]
            k += 1
        self.i += n
        return out^

    def read_text(mut self) raises DecodeError -> String:
        if self.typ != T_BINARY:
            raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)
        var n = Int(self.uvar())
        if n < 0 or n > 268435456:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        self.need(n)
        var start = self.i
        self.i += n
        return string_from(self.raw[start:self.i], start)

    def list_head(mut self) raises DecodeError -> Int:
        """Element count. Element type is left in `typ`."""
        if self.typ != T_LIST and self.typ != T_SET:
            raise DecodeError(DecodeError.KIND_TYPE, self.i, self.fid)
        var b = self.byte()
        var n = b >> 4
        self.typ = b & 15
        if n == 15:
            n = Int(self.uvar())
        if n < 0 or n > 100000000:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        return n

    def skip(mut self) raises DecodeError:
        var t = self.typ
        if t == T_BOOL_TRUE or t == T_BOOL_FALSE:
            return
        if t >= T_BYTE and t <= T_I64:
            _ = self.uvar()
            return
        if t == T_DOUBLE:
            self.need(8)
            self.i += 8
            return
        if t == T_BINARY:
            var n = Int(self.uvar())
            self.need(n)
            self.i += n
            return
        if t == T_LIST or t == T_SET:
            self.skip_list()
            return
        if t == T_MAP:
            self.skip_map()
            return
        if t == T_STRUCT:
            var prev = self.enter()
            while self.next() != 0:
                self.skip()
            self.leave(prev)
            return
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i, self.fid)

    def skip_elem(mut self, et: Int) raises DecodeError:
        if et == T_BOOL_TRUE or et == T_BOOL_FALSE:
            _ = self.byte()
            return
        self.typ = et
        self.skip()

    def skip_list(mut self) raises DecodeError:
        var n = self.list_head()
        var et = self.typ
        var k = 0
        while k < n:
            self.skip_elem(et)
            k += 1

    def skip_map(mut self) raises DecodeError:
        var n = Int(self.uvar())
        if n == 0:
            return
        if n < 0 or n > 100000000:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        var kinds = self.byte()
        var kt = kinds >> 4
        var vt = kinds & 15
        var k = 0
        while k < n:
            self.skip_elem(kt)
            self.skip_elem(vt)
            k += 1

    def elem_bool(mut self) raises DecodeError -> Int:
        var b = self.byte()
        if b == T_BOOL_TRUE:
            return 1
        if b == T_BOOL_FALSE:
            return 0
        raise DecodeError(DecodeError.KIND_TYPE, self.i)

    def elem_i32(mut self) raises DecodeError -> Int:
        return self.zz()

    def elem_i64(mut self) raises DecodeError -> Int:
        return self.zz()

    def elem_bin(mut self) raises DecodeError -> List[Byte]:
        self.typ = T_BINARY
        return self.read_bin()

    def elem_text(mut self) raises DecodeError -> String:
        self.typ = T_BINARY
        return self.read_text()
