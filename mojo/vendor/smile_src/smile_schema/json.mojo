from std.collections import List, Span

from smile_runtime.error import DecodeError
from smile_runtime.utf8 import append_utf8, string_from_span


comptime J_NULL = 1
comptime J_BOOL = 2
comptime J_INT = 3
comptime J_STR = 4
comptime J_ARR = 5
comptime J_OBJ = 6


struct JEdge(Copyable, ImplicitlyCopyable):
    var key: Int
    var val: Int

    def __init__(out self, key: Int, val: Int):
        self.key = key
        self.val = val


struct JNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int
    var child: Int
    var nchild: Int

    def __init__(out self, kind: Int):
        self.kind = kind
        self.a = 0
        self.child = -1
        self.nchild = 0


struct JDoc(Movable):
    var nodes: List[JNode]
    var edges: List[JEdge]
    var texts: List[String]
    var ints: List[Int]
    var root: Int

    def __init__(out self):
        self.nodes = List[JNode]()
        self.edges = List[JEdge]()
        self.texts = List[String]()
        self.ints = List[Int]()
        self.root = 0

    def _node(mut self, kind: Int) -> Int:
        var id = len(self.nodes)
        self.nodes.append(JNode(kind))
        return id

    def _text(mut self, var s: String) -> Int:
        var id = len(self.texts)
        self.texts.append(s^)
        return id

    def add_null(mut self) -> Int:
        return self._node(J_NULL)

    def add_bool(mut self, v: Bool) -> Int:
        var id = self._node(J_BOOL)
        var n = self.nodes[id]
        if v:
            n.a = 1
        self.nodes[id] = n
        return id

    def add_int(mut self, v: Int) -> Int:
        var id = self._node(J_INT)
        var n = self.nodes[id]
        n.a = len(self.ints)
        self.ints.append(v)
        self.nodes[id] = n
        return id

    def add_str(mut self, var s: String) -> Int:
        var id = self._node(J_STR)
        var n = self.nodes[id]
        n.a = self._text(s^)
        self.nodes[id] = n
        return id

    def start_arr(mut self) -> Int:
        return self._node(J_ARR)

    def start_obj(mut self) -> Int:
        return self._node(J_OBJ)

    def _attach(mut self, parent: Int, key: Int, val: Int):
        var n = self.nodes[parent]
        if n.child < 0 or n.child + n.nchild != len(self.edges):
            var start = len(self.edges)
            var i = 0
            var base = n.child
            while i < n.nchild:
                self.edges.append(self.edges[base + i])
                i += 1
            n.child = start
        self.edges.append(JEdge(key, val))
        n.nchild += 1
        self.nodes[parent] = n

    def add_elem(mut self, parent: Int, val: Int):
        self._attach(parent, -1, val)

    def add_field(mut self, parent: Int, key: Int, val: Int):
        self._attach(parent, key, val)

    def kind(self, id: Int) -> Int:
        return self.nodes[id].kind

    def as_bool(self, id: Int) -> Bool:
        return self.nodes[id].a != 0

    def as_int(self, id: Int) -> Int:
        return self.ints[self.nodes[id].a]

    def as_str(self, id: Int) -> String:
        return self.texts[self.nodes[id].a]

    def count(self, id: Int) -> Int:
        return self.nodes[id].nchild

    def at(self, id: Int, index: Int) -> Int:
        return self.edges[self.nodes[id].child + index].val

    def key_at(self, id: Int, index: Int) -> String:
        return self.texts[self.edges[self.nodes[id].child + index].key]

    def get(self, id: Int, key: String) -> Int:
        var n = self.nodes[id]
        var i = 0
        while i < n.nchild:
            var e = self.edges[n.child + i]
            if self.texts[e.key] == key:
                return e.val
            i += 1
        return -1


struct JParser[origin: ImmOrigin]:
    var raw: Span[Byte, Self.origin]
    var i: Int
    var doc: JDoc

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.doc = JDoc()

    def take_doc(mut self) -> JDoc:
        var empty = JDoc()
        var out = self.doc^
        self.doc = empty^
        return out^

    def _peek(self) raises DecodeError -> Int:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        return Int(self.raw[self.i])

    def _b(mut self) raises DecodeError -> Int:
        var c = self._peek()
        self.i += 1
        return c

    def skip(mut self):
        while self.i < len(self.raw):
            var c = Int(self.raw[self.i])
            if c != 32 and c != 9 and c != 10 and c != 13:
                return
            self.i += 1

    def parse_value(mut self) raises DecodeError -> Int:
        self.skip()
        var c = self._b()
        if c == 110:
            self._lit("ull")
            return self.doc.add_null()
        if c == 116:
            self._lit("rue")
            return self.doc.add_bool(True)
        if c == 102:
            self._lit("alse")
            return self.doc.add_bool(False)
        if c == 34:
            var s = self._string()
            return self.doc.add_str(s^)
        if c == 91:
            return self._array()
        if c == 123:
            return self._object()
        if c == 45 or (c >= 48 and c <= 57):
            self.i -= 1
            return self._number()
        raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)

    def _lit(mut self, want: String) raises DecodeError:
        var raw = want.as_bytes()
        var k = 0
        while k < len(raw):
            if self._b() != Int(raw[k]):
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
            k += 1

    def _hex(mut self) raises DecodeError -> Int:
        var c = self._b()
        if c >= 48 and c <= 57:
            return c - 48
        if c >= 97 and c <= 102:
            return c - 87
        if c >= 65 and c <= 70:
            return c - 55
        raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)

    def _string(mut self) raises DecodeError -> String:
        var buf = List[Byte]()
        while True:
            var c = self._b()
            if c == 34:
                break
            if c == 92:
                var e = self._b()
                if e == 34 or e == 92 or e == 47:
                    buf.append(Byte(e))
                elif e == 98:
                    buf.append(Byte(8))
                elif e == 102:
                    buf.append(Byte(12))
                elif e == 110:
                    buf.append(Byte(10))
                elif e == 114:
                    buf.append(Byte(13))
                elif e == 116:
                    buf.append(Byte(9))
                elif e == 117:
                    var cp = 0
                    var h = 0
                    while h < 4:
                        cp = (cp << 4) | self._hex()
                        h += 1
                    if cp >= 0xD800 and cp <= 0xDBFF:
                        if self._b() != 92 or self._b() != 117:
                            raise DecodeError(DecodeError.KIND_SCHEMA, self.i)
                        var lo = 0
                        h = 0
                        while h < 4:
                            lo = (lo << 4) | self._hex()
                            h += 1
                        if lo < 0xDC00 or lo > 0xDFFF:
                            raise DecodeError(DecodeError.KIND_SCHEMA, self.i)
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
                    append_utf8(buf, cp, self.i)
                else:
                    raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
            elif c < 0x20:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
            else:
                buf.append(Byte(c))
        return string_from_span(Span(buf), self.i)

    def _number(mut self) raises DecodeError -> Int:
        var start = self.i
        if self._peek() == 45:
            self.i += 1
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_SCHEMA, start)
        var c = Int(self.raw[self.i])
        if c == 48:
            self.i += 1
        elif c >= 49 and c <= 57:
            while self.i < len(self.raw):
                c = Int(self.raw[self.i])
                if c < 48 or c > 57:
                    break
                self.i += 1
        else:
            raise DecodeError(DecodeError.KIND_SCHEMA, self.i)
        var is_float = False
        if self.i < len(self.raw) and Int(self.raw[self.i]) == 46:
            is_float = True
            self.i += 1
            var saw = False
            while self.i < len(self.raw):
                c = Int(self.raw[self.i])
                if c < 48 or c > 57:
                    break
                saw = True
                self.i += 1
            if not saw:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i)
        if self.i < len(self.raw) and (Int(self.raw[self.i]) == 101 or Int(self.raw[self.i]) == 69):
            is_float = True
            self.i += 1
            if self.i < len(self.raw) and (Int(self.raw[self.i]) == 43 or Int(self.raw[self.i]) == 45):
                self.i += 1
            var saw = False
            while self.i < len(self.raw):
                c = Int(self.raw[self.i])
                if c < 48 or c > 57:
                    break
                saw = True
                self.i += 1
            if not saw:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i)
        var tmp = List[Byte]()
        var k = start
        while k < self.i:
            tmp.append(self.raw[k])
            k += 1
        var text = string_from_span(Span(tmp), start)
        if is_float:
            return self.doc.add_str(text^)
        return self.doc.add_int(_json_int(text))

    def _array(mut self) raises DecodeError -> Int:
        var id = self.doc.start_arr()
        self.skip()
        if self._peek() == 93:
            self.i += 1
            return id
        while True:
            var v = self.parse_value()
            self.doc.add_elem(id, v)
            self.skip()
            var c = self._b()
            if c == 93:
                break
            if c != 44:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
        return id

    def _object(mut self) raises DecodeError -> Int:
        var id = self.doc.start_obj()
        self.skip()
        if self._peek() == 125:
            self.i += 1
            return id
        while True:
            self.skip()
            if self._b() != 34:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
            var key = self._string()
            self.skip()
            if self._b() != 58:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
            var v = self.parse_value()
            var kid = self.doc._text(key^)
            self.doc.add_field(id, kid, v)
            self.skip()
            var c = self._b()
            if c == 125:
                break
            if c != 44:
                raise DecodeError(DecodeError.KIND_SCHEMA, self.i - 1)
        return id


def _json_int(text: String) raises DecodeError -> Int:
    if text == "-9223372036854775808":
        return Int(UInt64(1) << 63)
    var raw = text.as_bytes()
    var i = 0
    var neg = False
    if len(raw) > 0 and Int(raw[0]) == 45:
        neg = True
        i = 1
    var v = 0
    if i >= len(raw):
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)
    while i < len(raw):
        var d = Int(raw[i]) - 48
        if d < 0 or d > 9:
            raise DecodeError(DecodeError.KIND_SCHEMA, i)
        if v > 922337203685477580 or (v == 922337203685477580 and d > 7):
            raise DecodeError(DecodeError.KIND_RANGE, i)
        v = v * 10 + d
        i += 1
    if neg:
        return -v
    return v


def parse_json(text: String) raises DecodeError -> JDoc:
    var raw = text.as_bytes()
    var start = 0
    if len(raw) >= 3 and Int(raw[0]) == 0xEF and Int(raw[1]) == 0xBB and Int(raw[2]) == 0xBF:
        start = 3
    var p = JParser(raw[start:])
    var root = p.parse_value()
    p.skip()
    if p.i != len(p.raw):
        raise DecodeError(DecodeError.KIND_SCHEMA, p.i)
    p.doc.root = root
    return p.take_doc()