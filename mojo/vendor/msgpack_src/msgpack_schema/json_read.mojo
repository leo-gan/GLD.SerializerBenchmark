from std.collections import List, Span

from msgpack_runtime.error import DecodeError
from msgpack_wire.utf8 import string_from_utf8


comptime JK_NULL = 0
comptime JK_BOOL = 1
comptime JK_INT = 2
comptime JK_FLOAT = 3
comptime JK_STR = 4
comptime JK_ARRAY = 5
comptime JK_OBJECT = 6


struct JNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int64
    var b: UInt64
    var c: Int

    def __init__(out self, kind: Int, a: Int64 = 0, b: UInt64 = 0, c: Int = 0):
        self.kind = kind
        self.a = a
        self.b = b
        self.c = c


struct ReadValue(Movable):
    var nodes: List[JNode]
    var kids: List[Int]
    var texts: List[String]
    var root: Int

    def __init__(out self):
        self.nodes = List[JNode]()
        self.kids = List[Int]()
        self.texts = List[String]()
        self.root = 0

    def add(mut self, n: JNode) -> Int:
        var i = len(self.nodes)
        self.nodes.append(n)
        return i

    def is_object(self) -> Bool:
        return self.nodes[self.root].kind == JK_OBJECT

    def is_array(self) -> Bool:
        return self.nodes[self.root].kind == JK_ARRAY

    def is_string(self) -> Bool:
        return self.nodes[self.root].kind == JK_STR

    def is_int(self) -> Bool:
        return self.nodes[self.root].kind == JK_INT

    def is_bool(self) -> Bool:
        return self.nodes[self.root].kind == JK_BOOL

    def count(self) -> Int:
        return Int(self.nodes[self.root].b)

    def as_str(self) raises DecodeError -> String:
        if self.nodes[self.root].kind != JK_STR:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.texts[Int(self.nodes[self.root].a)]

    def as_int(self) raises DecodeError -> Int64:
        if self.nodes[self.root].kind != JK_INT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].a

    def as_bool(self) raises DecodeError -> Bool:
        if self.nodes[self.root].kind != JK_BOOL:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].a != Int64(0)

    def at(self, i: Int) raises DecodeError -> ReadValue:
        if self.nodes[self.root].kind != JK_ARRAY:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return _jview(self, self.kids[Int(self.nodes[self.root].a) + i])

    def pair(self, i: Int) raises DecodeError -> Tuple[String, ReadValue]:
        if self.nodes[self.root].kind != JK_OBJECT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var base = Int(self.nodes[self.root].a) + i * 2
        var k = self.kids[base]
        return (self.texts[Int(self.nodes[k].a)], _jview(self, self.kids[base + 1]))

    def get(self, key: String) raises DecodeError -> ReadValue:
        if not self.is_object():
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = Int(self.nodes[self.root].b)
        var found = -1
        var i = n - 1
        while i >= 0:
            var k = self.kids[Int(self.nodes[self.root].a) + i * 2]
            if self.texts[Int(self.nodes[k].a)] == key:
                found = self.kids[Int(self.nodes[self.root].a) + i * 2 + 1]
                break
            i -= 1
        if found < 0:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return _jview(self, found)


def _jview(src: ReadValue, root: Int) -> ReadValue:
    var out = ReadValue()
    out.nodes = src.nodes.copy()
    out.kids = src.kids.copy()
    out.texts = src.texts.copy()
    out.root = root
    return out^


struct JReader[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int

    def __init__(out self, data: Span[Byte, Self.origin]):
        self.data = data
        self.pos = 0

    def skip_ws(mut self):
        while self.pos < len(self.data):
            var c = Int(self.data[self.pos])
            if c == 32 or c == 9 or c == 10 or c == 13:
                self.pos += 1
            else:
                return

    def peek(mut self) raises DecodeError -> Int:
        self.skip_ws()
        if self.pos >= len(self.data):
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        return Int(self.data[self.pos])

    def eat(mut self, b: Int) raises DecodeError:
        if self.peek() != b:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
        self.pos += 1


def decode_json[
    origin: ImmOrigin
](buf: Span[Byte, origin]) raises DecodeError -> ReadValue:
    if len(buf) >= 3 and Int(buf[0]) == 0xEF and Int(buf[1]) == 0xBB and Int(buf[2]) == 0xBF:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    var r = JReader[origin](buf)
    var v = ReadValue()
    v.root = _parse_j(r, v)
    r.skip_ws()
    if r.pos < len(r.data):
        raise DecodeError(DecodeError.KIND_TRAILING, r.pos)
    return v^


def _parse_j[
    origin: ImmOrigin
](mut r: JReader[origin], mut v: ReadValue) raises DecodeError -> Int:
    var c = r.peek()
    if c == 110:
        r.eat(110)
        r.eat(117)
        r.eat(108)
        r.eat(108)
        return v.add(JNode(JK_NULL))
    if c == 116:
        r.eat(116)
        r.eat(114)
        r.eat(117)
        r.eat(101)
        return v.add(JNode(JK_BOOL, a=Int64(1)))
    if c == 102:
        r.eat(102)
        r.eat(97)
        r.eat(108)
        r.eat(115)
        r.eat(101)
        return v.add(JNode(JK_BOOL, a=Int64(0)))
    if c == 34:
        return v.add(JNode(JK_STR, a=Int64(_parse_jstr(r, v))))
    if c == 91:
        return _parse_jarr(r, v)
    if c == 123:
        return _parse_jobj(r, v)
    if c == 45 or (c >= 48 and c <= 57):
        return _parse_jnum(r, v)
    raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)


def _parse_jstr[
    origin: ImmOrigin
](mut r: JReader[origin], mut v: ReadValue) raises DecodeError -> Int:
    r.eat(34)
    var out = List[Byte]()
    while r.pos < len(r.data):
        var c = Int(r.data[r.pos])
        r.pos += 1
        if c == 34:
            var text: String
            try:
                text = String(from_utf8=out)
            except _:
                raise DecodeError(DecodeError.KIND_UTF8, r.pos)
            var ti = len(v.texts)
            v.texts.append(text^)
            return ti
        if c == 92:
            if r.pos >= len(r.data):
                raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
            var e = Int(r.data[r.pos])
            r.pos += 1
            if e == 34 or e == 92 or e == 47:
                out.append(Byte(e))
            elif e == 98:
                out.append(Byte(8))
            elif e == 102:
                out.append(Byte(12))
            elif e == 110:
                out.append(Byte(10))
            elif e == 114:
                out.append(Byte(13))
            elif e == 116:
                out.append(Byte(9))
            elif e == 117:
                var cp = _hex4(r)
                if cp >= 0xD800 and cp <= 0xDBFF:
                    if r.pos + 1 >= len(r.data) or Int(r.data[r.pos]) != 92:
                        raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
                    r.pos += 1
                    if r.pos >= len(r.data) or Int(r.data[r.pos]) != 117:
                        raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
                    r.pos += 1
                    var lo = _hex4(r)
                    if lo < 0xDC00 or lo > 0xDFFF:
                        raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
                elif cp >= 0xDC00 and cp <= 0xDFFF:
                    raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
                _utf8_append(out, cp)
            else:
                raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
        elif c < 32:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
        else:
            out.append(Byte(c))
    raise DecodeError(DecodeError.KIND_EOF, r.pos)


def _hex4[origin: ImmOrigin](mut r: JReader[origin]) raises DecodeError -> Int:
    var n = 0
    var i = 0
    while i < 4:
        if r.pos >= len(r.data):
            raise DecodeError(DecodeError.KIND_EOF, r.pos)
        var c = Int(r.data[r.pos])
        r.pos += 1
        var d = -1
        if c >= 48 and c <= 57:
            d = c - 48
        elif c >= 65 and c <= 70:
            d = c - 55
        elif c >= 97 and c <= 102:
            d = c - 87
        if d < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
        n = (n << 4) + d
        i += 1
    return n


def _utf8_append(mut out: List[Byte], cp: Int):
    if cp < 0x80:
        out.append(Byte(cp))
    elif cp < 0x800:
        out.append(Byte(0xC0 | (cp >> 6)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    elif cp < 0x10000:
        out.append(Byte(0xE0 | (cp >> 12)))
        out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        out.append(Byte(0x80 | (cp & 0x3F)))
    else:
        out.append(Byte(0xF0 | (cp >> 18)))
        out.append(Byte(0x80 | ((cp >> 12) & 0x3F)))
        out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
        out.append(Byte(0x80 | (cp & 0x3F)))


def _parse_jnum[
    origin: ImmOrigin
](mut r: JReader[origin], mut v: ReadValue) raises DecodeError -> Int:
    var start = r.pos
    if r.peek() == 45:
        r.pos += 1
    if r.pos >= len(r.data):
        raise DecodeError(DecodeError.KIND_EOF, r.pos)
    var c0 = Int(r.data[r.pos])
    if c0 == 48:
        r.pos += 1
        if r.pos < len(r.data):
            var n = Int(r.data[r.pos])
            if n >= 48 and n <= 57:
                raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
    elif c0 >= 49 and c0 <= 57:
        r.pos += 1
        while r.pos < len(r.data):
            var d = Int(r.data[r.pos])
            if d >= 48 and d <= 57:
                r.pos += 1
            else:
                break
    else:
        raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
    var is_float = False
    if r.pos < len(r.data) and Int(r.data[r.pos]) == 46:
        is_float = True
        r.pos += 1
        var digits = 0
        while r.pos < len(r.data):
            var d = Int(r.data[r.pos])
            if d >= 48 and d <= 57:
                r.pos += 1
                digits += 1
            else:
                break
        if digits == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
    if r.pos < len(r.data) and (Int(r.data[r.pos]) == 101 or Int(r.data[r.pos]) == 69):
        is_float = True
        r.pos += 1
        if r.pos < len(r.data) and (Int(r.data[r.pos]) == 43 or Int(r.data[r.pos]) == 45):
            r.pos += 1
        var ed = 0
        while r.pos < len(r.data):
            var d = Int(r.data[r.pos])
            if d >= 48 and d <= 57:
                r.pos += 1
                ed += 1
            else:
                break
        if ed == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
    var tok = string_from_utf8(r.data[start : r.pos], start)
    if not is_float:
        try:
            var iv = atol(tok)
            return v.add(JNode(JK_INT, a=Int64(iv)))
        except _:
            pass
    try:
        var fv = atof(tok)
        return v.add(JNode(JK_FLOAT, b=UInt64(fv.to_bits())))
    except _:
        raise DecodeError(DecodeError.KIND_RANGE, start)


def _parse_jarr[
    origin: ImmOrigin
](mut r: JReader[origin], mut v: ReadValue) raises DecodeError -> Int:
    r.eat(91)
    var ids = List[Int]()
    if r.peek() == 93:
        r.eat(93)
        var kstart0 = len(v.kids)
        return v.add(JNode(JK_ARRAY, a=Int64(kstart0), b=UInt64(0)))
    while True:
        ids.append(_parse_j(r, v))
        var c = r.peek()
        if c == 93:
            r.eat(93)
            var kstart = len(v.kids)
            var i = 0
            while i < len(ids):
                v.kids.append(ids[i])
                i += 1
            return v.add(JNode(JK_ARRAY, a=Int64(kstart), b=UInt64(len(ids))))
        if c != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
        r.eat(44)


def _parse_jobj[
    origin: ImmOrigin
](mut r: JReader[origin], mut v: ReadValue) raises DecodeError -> Int:
    r.eat(123)
    var ids = List[Int]()
    if r.peek() == 125:
        r.eat(125)
        var kstart0 = len(v.kids)
        return v.add(JNode(JK_OBJECT, a=Int64(kstart0), b=UInt64(0)))
    while True:
        if r.peek() != 34:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
        var ki = v.add(JNode(JK_STR, a=Int64(_parse_jstr(r, v))))
        r.eat(58)
        var val = _parse_j(r, v)
        ids.append(ki)
        ids.append(val)
        var c = r.peek()
        if c == 125:
            r.eat(125)
            var kstart = len(v.kids)
            var i = 0
            while i < len(ids):
                v.kids.append(ids[i])
                i += 1
            return v.add(JNode(JK_OBJECT, a=Int64(kstart), b=UInt64(len(ids) // 2)))
        if c != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.pos)
        r.eat(44)
