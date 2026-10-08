from std.collections import List, Span

from arrow_runtime.error import DecodeError


comptime J_NULL = 0
comptime J_BOOL = 1
comptime J_NUM = 2
comptime J_STR = 3
comptime J_ARR = 4
comptime J_OBJ = 5


struct JNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int
    var n: Int

    def __init__(out self, kind: Int, a: Int, n: Int):
        self.kind = kind
        self.a = a
        self.n = n


struct JsonDoc:
    var nodes: List[JNode]
    var edges: List[Int]
    var pair_k: List[Int]
    var pair_v: List[Int]
    var texts: List[String]
    var root: Int

    def __init__(out self):
        self.nodes = List[JNode]()
        self.edges = List[Int]()
        self.pair_k = List[Int]()
        self.pair_v = List[Int]()
        self.texts = List[String]()
        self.root = 0

    def push(mut self, n: JNode) -> Int:
        self.nodes.append(n)
        return len(self.nodes) - 1

    def kind(self, id: Int) -> Int:
        return self.nodes[id].kind

    def text(self, id: Int) -> String:
        return self.texts[self.nodes[id].a]

    def boolean(self, id: Int) -> Bool:
        return self.nodes[id].a != 0

    def child(self, id: Int, i: Int) -> Int:
        if self.kind(id) == J_OBJ:
            return self.pair_v[self.nodes[id].a + i]
        return self.edges[self.nodes[id].a + i]

    def key(self, id: Int, i: Int) -> String:
        return self.texts[self.pair_k[self.nodes[id].a + i]]

    def find(self, id: Int, name: String) -> Int:
        if id < 0 or self.kind(id) != J_OBJ:
            return -1
        var i = 0
        while i < self.nodes[id].n:
            if self.key(id, i) == name:
                return self.child(id, i)
            i += 1
        return -1

    def count(self, id: Int) -> Int:
        return self.nodes[id].n


def parse_json[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> JsonDoc:
    var doc = JsonDoc()
    var i = 0
    i = _skip(raw, i)
    var root = 0
    root, i = _value(raw, doc, i)
    i = _skip(raw, i)
    if i != len(raw):
        raise DecodeError(DecodeError.KIND_SYNTAX, i)
    doc.root = root
    return doc^


def _skip[origin: ImmOrigin](raw: Span[Byte, origin], i0: Int) -> Int:
    var i = i0
    while i < len(raw):
        var c = Int(raw[i])
        if c != 32 and c != 9 and c != 10 and c != 13:
            return i
        i += 1
    return i


def _value[origin: ImmOrigin](raw: Span[Byte, origin], mut doc: JsonDoc, i0: Int) raises DecodeError -> Tuple[Int, Int]:
    var i = _skip(raw, i0)
    if i >= len(raw):
        raise DecodeError(DecodeError.KIND_EOF, i)
    var c = Int(raw[i])
    if c == 110:
        return _lit(raw, doc, i, "null", J_NULL, 0)
    if c == 116:
        return _lit(raw, doc, i, "true", J_BOOL, 1)
    if c == 102:
        return _lit(raw, doc, i, "false", J_BOOL, 0)
    if c == 34:
        var text = String("")
        text, i = _string(raw, i)
        var id = doc.push(JNode(J_STR, len(doc.texts), 0))
        doc.texts.append(text)
        return (id, i)
    if c == 91:
        return _array(raw, doc, i)
    if c == 123:
        return _object(raw, doc, i)
    if c == 45 or (c >= 48 and c <= 57):
        return _number(raw, doc, i)
    raise DecodeError(DecodeError.KIND_SYNTAX, i)


def _lit[origin: ImmOrigin](
    raw: Span[Byte, origin], mut doc: JsonDoc, i0: Int, word: String, kind: Int, a: Int
) raises DecodeError -> Tuple[Int, Int]:
    var bytes = word.as_bytes()
    var i = 0
    while i < len(bytes):
        if i0 + i >= len(raw) or raw[i0 + i] != bytes[i]:
            raise DecodeError(DecodeError.KIND_SYNTAX, i0)
        i += 1
    return (doc.push(JNode(kind, a, 0)), i0 + len(bytes))


def _string[origin: ImmOrigin](raw: Span[Byte, origin], i0: Int) raises DecodeError -> Tuple[String, Int]:
    var i = i0 + 1
    var out = List[Byte]()
    while i < len(raw):
        var c = Int(raw[i])
        if c == 34:
            return (String(unsafe_from_utf8=Span(out)), i + 1)
        if c == 92:
            i += 1
            if i >= len(raw):
                raise DecodeError(DecodeError.KIND_SYNTAX, i)
            var e = Int(raw[i])
            if e == 34 or e == 92 or e == 47:
                out.append(Byte(e))
            elif e == 110:
                out.append(Byte(10))
            elif e == 116:
                out.append(Byte(9))
            elif e == 114:
                out.append(Byte(13))
            elif e == 98:
                out.append(Byte(8))
            elif e == 102:
                out.append(Byte(12))
            elif e == 117:
                var cp = 0
                var h = 0
                while h < 4:
                    i += 1
                    if i >= len(raw):
                        raise DecodeError(DecodeError.KIND_SYNTAX, i)
                    cp = (cp << 4) + _hex(raw, i)
                    h += 1
                _utf8_append(out, cp)
            else:
                raise DecodeError(DecodeError.KIND_SYNTAX, i)
        else:
            out.append(Byte(c))
        i += 1
    raise DecodeError(DecodeError.KIND_EOF, i0)


def _hex[origin: ImmOrigin](raw: Span[Byte, origin], i: Int) raises DecodeError -> Int:
    var c = Int(raw[i])
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 97 and c <= 102:
        return c - 87
    if c >= 65 and c <= 70:
        return c - 55
    raise DecodeError(DecodeError.KIND_SYNTAX, i)


def _utf8_append(mut out: List[Byte], cp: Int):
    if cp < 128:
        out.append(Byte(cp))
    elif cp < 2048:
        out.append(Byte(192 | (cp >> 6)))
        out.append(Byte(128 | (cp & 63)))
    else:
        out.append(Byte(224 | (cp >> 12)))
        out.append(Byte(128 | ((cp >> 6) & 63)))
        out.append(Byte(128 | (cp & 63)))


def _number[origin: ImmOrigin](raw: Span[Byte, origin], mut doc: JsonDoc, i0: Int) raises DecodeError -> Tuple[Int, Int]:
    var i = i0
    var start = i
    if Int(raw[i]) == 45:
        i += 1
    while i < len(raw) and Int(raw[i]) >= 48 and Int(raw[i]) <= 57:
        i += 1
    if i < len(raw) and Int(raw[i]) == 46:
        i += 1
        while i < len(raw) and Int(raw[i]) >= 48 and Int(raw[i]) <= 57:
            i += 1
    if i < len(raw) and (Int(raw[i]) == 101 or Int(raw[i]) == 69):
        i += 1
        if i < len(raw) and (Int(raw[i]) == 43 or Int(raw[i]) == 45):
            i += 1
        while i < len(raw) and Int(raw[i]) >= 48 and Int(raw[i]) <= 57:
            i += 1
    var text = String(unsafe_from_utf8=raw[start:i])
    var id = doc.push(JNode(J_NUM, len(doc.texts), 0))
    doc.texts.append(text)
    return (id, i)


def _array[origin: ImmOrigin](raw: Span[Byte, origin], mut doc: JsonDoc, i0: Int) raises DecodeError -> Tuple[Int, Int]:
    var i = i0 + 1
    var ids = List[Int]()
    i = _skip(raw, i)
    if i < len(raw) and Int(raw[i]) != 93:
        while True:
            var child = 0
            child, i = _value(raw, doc, i)
            ids.append(child)
            i = _skip(raw, i)
            if i < len(raw) and Int(raw[i]) == 44:
                i = _skip(raw, i + 1)
            else:
                break
    if i >= len(raw) or Int(raw[i]) != 93:
        raise DecodeError(DecodeError.KIND_SYNTAX, i)
    var start = len(doc.edges)
    var k = 0
    while k < len(ids):
        doc.edges.append(ids[k])
        k += 1
    return (doc.push(JNode(J_ARR, start, len(ids))), i + 1)


def _object[origin: ImmOrigin](raw: Span[Byte, origin], mut doc: JsonDoc, i0: Int) raises DecodeError -> Tuple[Int, Int]:
    var i = i0 + 1
    var ks = List[Int]()
    var vs = List[Int]()
    i = _skip(raw, i)
    if i < len(raw) and Int(raw[i]) != 125:
        while True:
            i = _skip(raw, i)
            if i >= len(raw) or Int(raw[i]) != 34:
                raise DecodeError(DecodeError.KIND_SYNTAX, i)
            var key = String("")
            key, i = _string(raw, i)
            ks.append(len(doc.texts))
            doc.texts.append(key)
            i = _skip(raw, i)
            if i >= len(raw) or Int(raw[i]) != 58:
                raise DecodeError(DecodeError.KIND_SYNTAX, i)
            var child = 0
            child, i = _value(raw, doc, i + 1)
            vs.append(child)
            i = _skip(raw, i)
            if i < len(raw) and Int(raw[i]) == 44:
                i += 1
            else:
                break
    if i >= len(raw) or Int(raw[i]) != 125:
        raise DecodeError(DecodeError.KIND_SYNTAX, i)
    var start = len(doc.pair_v)
    var k = 0
    while k < len(vs):
        doc.pair_k.append(ks[k])
        doc.pair_v.append(vs[k])
        k += 1
    return (doc.push(JNode(J_OBJ, start, len(vs))), i + 1)
