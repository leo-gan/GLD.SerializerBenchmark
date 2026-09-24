from std.collections import List
from std.memory import unsafe_memcpy

from bson_runtime.error import DecodeError

comptime JK_NULL = 0
comptime JK_BOOL = 1
comptime JK_NUM = 2
comptime JK_STR = 3
comptime JK_ARR = 4
comptime JK_OBJ = 5


struct JNode(Movable):
    var kind: Int
    var flag: Bool
    var text: String
    var keys: List[String]
    var kids: List[Int]

    def __init__(out self):
        self.kind = JK_NULL
        self.flag = False
        self.text = ""
        self.keys = List[String]()
        self.kids = List[Int]()


struct JsonDoc(Movable):
    var nodes: List[JNode]
    var root: Int

    def __init__(out self):
        self.nodes = List[JNode]()
        self.root = 0

    def add(mut self) -> Int:
        var i = len(self.nodes)
        self.nodes.append(JNode())
        return i


def _ws(c: Int) -> Bool:
    return c == 32 or c == 9 or c == 10 or c == 13


struct Parser:
    var raw: List[Byte]
    var i: Int
    var doc: JsonDoc

    def __init__(out self, text: String):
        var src = text.as_bytes()
        self.raw = List[Byte]()
        if len(src) > 0:
            self.raw = List[Byte](unsafe_uninit_length=len(src))
            unsafe_memcpy(dest=self.raw.unsafe_ptr(), src=src.unsafe_ptr(), count=len(src))
        self.i = 0
        self.doc = JsonDoc()

    def skip(mut self):
        while self.i < len(self.raw) and _ws(Int(self.raw[self.i])):
            self.i += 1

    def parse_string(mut self) raises DecodeError -> String:
        var n = len(self.raw)
        if self.i >= n or self.raw[self.i] != Byte(ord('"')):
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i, 0)
        self.i += 1
        var out = List[Byte]()
        while self.i < n:
            var c = self.raw[self.i]
            self.i += 1
            if c == Byte(ord('"')):
                try:
                    return String(from_utf8=Span(unsafe_ptr=out.unsafe_ptr(), length=len(out)))
                except _:
                    raise DecodeError(DecodeError.KIND_UTF8, self.i, len(out))
            if c != Byte(ord("\\")):
                out.append(c)
                continue
            if self.i >= n:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i, 0)
            var e = self.raw[self.i]
            self.i += 1
            if e == Byte(ord('"')) or e == Byte(ord("\\")) or e == Byte(ord("/")):
                out.append(e)
            elif e == Byte(ord("b")):
                out.append(Byte(8))
            elif e == Byte(ord("f")):
                out.append(Byte(12))
            elif e == Byte(ord("n")):
                out.append(Byte(10))
            elif e == Byte(ord("r")):
                out.append(Byte(13))
            elif e == Byte(ord("t")):
                out.append(Byte(9))
            elif e == Byte(ord("u")):
                var cp = self._hex4()
                if cp >= 0xD800 and cp <= 0xDBFF:
                    if self.i + 6 <= len(self.raw) and self.raw[self.i] == Byte(ord("\\")) and self.raw[self.i + 1] == Byte(ord("u")):
                        self.i += 2
                        var cp2 = self._hex4()
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (cp2 - 0xDC00)
                self._utf8(cp, out)
            else:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i, Int(e))
            n = len(self.raw)
        raise DecodeError(DecodeError.KIND_EOF, self.i, 0)

    def _hex4(mut self) raises DecodeError -> Int:
        if self.i + 4 > len(self.raw):
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i, 0)
        var cp = 0
        var h = 0
        while h < 4:
            var ch = Int(self.raw[self.i + h])
            var d = 0
            if ch >= 48 and ch <= 57:
                d = ch - 48
            elif ch >= 97 and ch <= 102:
                d = ch - 87
            elif ch >= 65 and ch <= 70:
                d = ch - 55
            else:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i, ch)
            cp = (cp << 4) | d
            h += 1
        self.i += 4
        return cp

    def _utf8(self, cp: Int, mut out: List[Byte]):
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

    def parse_value(mut self) raises DecodeError -> Int:
        self.skip()
        var n = len(self.raw)
        if self.i >= n:
            raise DecodeError(DecodeError.KIND_EOF, self.i, 0)
        var c = self.raw[self.i]
        if c == Byte(ord('"')):
            var text = self.parse_string()
            var idx = self.doc.add()
            self.doc.nodes[idx].kind = JK_STR
            self.doc.nodes[idx].text = text
            return idx
        if c == Byte(ord("{")):
            return self.parse_object()
        if c == Byte(ord("[")):
            return self.parse_array()
        if c == Byte(ord("t")):
            self.i += 4
            var idx = self.doc.add()
            self.doc.nodes[idx].kind = JK_BOOL
            self.doc.nodes[idx].flag = True
            return idx
        if c == Byte(ord("f")):
            self.i += 5
            var idx = self.doc.add()
            self.doc.nodes[idx].kind = JK_BOOL
            self.doc.nodes[idx].flag = False
            return idx
        if c == Byte(ord("n")):
            self.i += 4
            var idx = self.doc.add()
            self.doc.nodes[idx].kind = JK_NULL
            return idx
        return self.parse_number()

    def parse_object(mut self) raises DecodeError -> Int:
        self.i += 1
        var idx = self.doc.add()
        self.doc.nodes[idx].kind = JK_OBJ
        var keys = List[String]()
        var kids = List[Int]()
        self.skip()
        if self.i < len(self.raw) and self.raw[self.i] == Byte(ord("}")):
            self.i += 1
            return idx
        while True:
            self.skip()
            var key = self.parse_string()
            self.skip()
            if self.i >= len(self.raw) or self.raw[self.i] != Byte(ord(":")):
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i, 0)
            self.i += 1
            var child = self.parse_value()
            keys.append(key)
            kids.append(child)
            self.skip()
            if self.i < len(self.raw) and self.raw[self.i] == Byte(ord(",")):
                self.i += 1
                continue
            if self.i < len(self.raw) and self.raw[self.i] == Byte(ord("}")):
                self.i += 1
                break
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i, 0)
        var k = 0
        while k < len(keys):
            self.doc.nodes[idx].keys.append(keys[k])
            self.doc.nodes[idx].kids.append(kids[k])
            k += 1
        return idx

    def parse_array(mut self) raises DecodeError -> Int:
        self.i += 1
        var idx = self.doc.add()
        self.doc.nodes[idx].kind = JK_ARR
        var kids = List[Int]()
        self.skip()
        if self.i < len(self.raw) and self.raw[self.i] == Byte(ord("]")):
            self.i += 1
            return idx
        while True:
            var child = self.parse_value()
            kids.append(child)
            self.skip()
            if self.i < len(self.raw) and self.raw[self.i] == Byte(ord(",")):
                self.i += 1
                continue
            if self.i < len(self.raw) and self.raw[self.i] == Byte(ord("]")):
                self.i += 1
                break
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i, 0)
        var k = 0
        while k < len(kids):
            self.doc.nodes[idx].kids.append(kids[k])
            k += 1
        return idx

    def parse_number(mut self) raises DecodeError -> Int:
        var n = len(self.raw)
        var start = self.i
        if self.raw[self.i] == Byte(ord("-")):
            self.i += 1
        var saw = False
        while self.i < n and self.raw[self.i] >= Byte(ord("0")) and self.raw[self.i] <= Byte(ord("9")):
            saw = True
            self.i += 1
        if self.i < n and self.raw[self.i] == Byte(ord(".")):
            self.i += 1
            while self.i < n and self.raw[self.i] >= Byte(ord("0")) and self.raw[self.i] <= Byte(ord("9")):
                saw = True
                self.i += 1
        if self.i < n and (self.raw[self.i] == Byte(ord("e")) or self.raw[self.i] == Byte(ord("E"))):
            self.i += 1
            if self.i < n and (self.raw[self.i] == Byte(ord("+")) or self.raw[self.i] == Byte(ord("-"))):
                self.i += 1
            while self.i < n and self.raw[self.i] >= Byte(ord("0")) and self.raw[self.i] <= Byte(ord("9")):
                self.i += 1
        if not saw:
            raise DecodeError(DecodeError.KIND_SYNTAX, start, 0)
        var tmp = List[Byte]()
        var p = start
        while p < self.i:
            tmp.append(self.raw[p])
            p += 1
        var idx = self.doc.add()
        self.doc.nodes[idx].kind = JK_NUM
        try:
            self.doc.nodes[idx].text = String(from_utf8=Span(unsafe_ptr=tmp.unsafe_ptr(), length=len(tmp)))
        except _:
            raise DecodeError(DecodeError.KIND_UTF8, start, 0)
        return idx

    def finish(deinit self) raises DecodeError -> JsonDoc:
        self.doc.root = self.parse_value()
        self.skip()
        if self.i != len(self.raw):
            raise DecodeError(DecodeError.KIND_TRAILING, self.i, 0)
        return self.doc^


def parse_json(text: String) raises DecodeError -> JsonDoc:
    var p = Parser(text)
    return p^.finish()
