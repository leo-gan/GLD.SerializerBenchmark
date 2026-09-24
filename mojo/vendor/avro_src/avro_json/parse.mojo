from std.collections import List

from avro_json.value import (
    JSON_ARRAY,
    JSON_BOOL,
    JSON_FLOAT,
    JSON_INT,
    JSON_NULL,
    JSON_OBJECT,
    JSON_STRING,
    JsonDoc,
    JsonError,
    JsonNode,
)


struct _Parser(Movable):
    var text: String
    var pos: Int

    def __init__(out self, text: String):
        self.text = text
        self.pos = 0

    def _len(self) -> Int:
        return self.text.byte_length()

    def _byte(self, i: Int) -> Int:
        return Int(self.text.as_bytes()[i])

    def _skip(mut self):
        while self.pos < self._len():
            var c = self._byte(self.pos)
            if c == 32 or c == 9 or c == 10 or c == 13:
                self.pos += 1
            else:
                return

    def _peek(mut self) raises JsonError -> Int:
        self._skip()
        if self.pos >= self._len():
            raise JsonError("unexpected end", self.pos)
        return self._byte(self.pos)

    def _eat(mut self, ch: Int) raises JsonError:
        self._skip()
        if self.pos >= self._len() or self._byte(self.pos) != ch:
            raise JsonError("expected char", self.pos)
        self.pos += 1

    def parse_value(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        var c = self._peek()
        if c == 110:
            return self._lit(doc, "null", JSON_NULL)
        if c == 116:
            return self._true(doc)
        if c == 102:
            return self._false(doc)
        if c == 34:
            return self._string(doc)
        if c == 91:
            return self._array(doc)
        if c == 123:
            return self._object(doc)
        if c == 45 or (c >= 48 and c <= 57):
            return self._number(doc)
        raise JsonError("unexpected token", self.pos)

    def _lit(mut self, mut doc: JsonDoc, word: String, kind: Int) raises JsonError -> Int:
        var i = 0
        while i < word.byte_length():
            if self.pos >= self._len() or self._byte(self.pos) != Int(word.as_bytes()[i]):
                raise JsonError("bad literal", self.pos)
            self.pos += 1
            i += 1
        var n = JsonNode()
        n.kind = kind
        return doc.add(n^)

    def _true(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        _ = self._lit(doc, "true", JSON_BOOL)
        var last = len(doc.nodes) - 1
        doc.nodes[last].b = True
        return last

    def _false(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        return self._lit(doc, "false", JSON_BOOL)

    def _string(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        self._eat(34)
        var out = List[Byte]()
        while self.pos < self._len():
            var c = self._byte(self.pos)
            self.pos += 1
            if c == 34:
                var n = JsonNode()
                n.kind = JSON_STRING
                try:
                    n.s = String(from_utf8=out)
                except _:
                    raise JsonError("bad utf8", self.pos)
                return doc.add(n^)
            if c == 92:
                if self.pos >= self._len():
                    raise JsonError("bad escape", self.pos)
                var e = self._byte(self.pos)
                self.pos += 1
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
                    var cp = self._hex4()
                    self._append_utf8(out, cp)
                else:
                    raise JsonError("bad escape", self.pos)
            else:
                out.append(Byte(c))
        raise JsonError("unterminated string", self.pos)

    def _hex4(mut self) raises JsonError -> Int:
        var v = 0
        var i = 0
        while i < 4:
            if self.pos >= self._len():
                raise JsonError("bad unicode", self.pos)
            var c = self._byte(self.pos)
            self.pos += 1
            var digit: Int
            if c >= 48 and c <= 57:
                digit = c - 48
            elif c >= 97 and c <= 102:
                digit = c - 87
            elif c >= 65 and c <= 70:
                digit = c - 55
            else:
                raise JsonError("bad unicode", self.pos)
            v = (v << 4) + digit
            i += 1
        return v

    def _append_utf8(mut self, mut out: List[Byte], cp: Int):
        if cp < 0x80:
            out.append(Byte(cp))
        elif cp < 0x800:
            out.append(Byte(0xC0 | (cp >> 6)))
            out.append(Byte(0x80 | (cp & 0x3F)))
        else:
            out.append(Byte(0xE0 | (cp >> 12)))
            out.append(Byte(0x80 | ((cp >> 6) & 0x3F)))
            out.append(Byte(0x80 | (cp & 0x3F)))

    def _number(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        var start = self.pos
        if self._byte(self.pos) == 45:
            self.pos += 1
        if self.pos >= self._len():
            raise JsonError("bad number", start)
        if self._byte(self.pos) == 48:
            self.pos += 1
        else:
            if self._byte(self.pos) < 49 or self._byte(self.pos) > 57:
                raise JsonError("bad number", start)
            while self.pos < self._len():
                var c = self._byte(self.pos)
                if c >= 48 and c <= 57:
                    self.pos += 1
                else:
                    break
        var is_float = False
        if self.pos < self._len() and self._byte(self.pos) == 46:
            is_float = True
            self.pos += 1
            var any_d = False
            while self.pos < self._len():
                var c = self._byte(self.pos)
                if c >= 48 and c <= 57:
                    any_d = True
                    self.pos += 1
                else:
                    break
            if not any_d:
                raise JsonError("bad number", start)
        if self.pos < self._len():
            var c = self._byte(self.pos)
            if c == 101 or c == 69:
                is_float = True
                self.pos += 1
                if self.pos < self._len():
                    var s = self._byte(self.pos)
                    if s == 43 or s == 45:
                        self.pos += 1
                var any_e = False
                while self.pos < self._len():
                    var d = self._byte(self.pos)
                    if d >= 48 and d <= 57:
                        any_e = True
                        self.pos += 1
                    else:
                        break
                if not any_e:
                    raise JsonError("bad number", start)
        var slice = self.text.as_bytes()[start : self.pos]
        var token: String
        try:
            token = String(from_utf8=slice)
        except _:
            raise JsonError("bad number token", start)
        var n = JsonNode()
        if is_float:
            n.kind = JSON_FLOAT
            try:
                n.f = atof(token)
            except _:
                raise JsonError("bad float", start)
        else:
            n.kind = JSON_INT
            try:
                n.i = Int64(atol(token))
            except _:
                raise JsonError("bad int", start)
        return doc.add(n^)

    def _array(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        self._eat(91)
        var kids = List[Int]()
        self._skip()
        if self.pos < self._len() and self._byte(self.pos) == 93:
            self.pos += 1
            var n = JsonNode()
            n.kind = JSON_ARRAY
            n.first = -1
            n.count = 0
            return doc.add(n^)
        while True:
            kids.append(self.parse_value(doc))
            var c = self._peek()
            if c == 44:
                self.pos += 1
                continue
            if c == 93:
                self.pos += 1
                break
            raise JsonError("bad array", self.pos)
        var first = len(doc.refs)
        var ki = 0
        while ki < len(kids):
            doc.refs.append(kids[ki])
            ki += 1
        var n = JsonNode()
        n.kind = JSON_ARRAY
        n.first = first
        n.count = len(kids)
        return doc.add(n^)

    def _object(mut self, mut doc: JsonDoc) raises JsonError -> Int:
        self._eat(123)
        var pairs = List[Int]()
        self._skip()
        if self.pos < self._len() and self._byte(self.pos) == 125:
            self.pos += 1
            var n = JsonNode()
            n.kind = JSON_OBJECT
            n.first = -1
            n.count = 0
            return doc.add(n^)
        while True:
            if self._peek() != 34:
                raise JsonError("object key must be string", self.pos)
            var key_id = self._string(doc)
            self._eat(58)
            var val_id = self.parse_value(doc)
            pairs.append(key_id)
            pairs.append(val_id)
            var c = self._peek()
            if c == 44:
                self.pos += 1
                continue
            if c == 125:
                self.pos += 1
                break
            raise JsonError("bad object", self.pos)
        var first = len(doc.refs)
        var pi = 0
        while pi < len(pairs):
            doc.refs.append(pairs[pi])
            pi += 1
        var n = JsonNode()
        n.kind = JSON_OBJECT
        n.first = first
        n.count = len(pairs) // 2
        return doc.add(n^)


def parse_json(text: String) raises JsonError -> JsonDoc:
    var p = _Parser(text)
    var doc = JsonDoc()
    doc.root = p.parse_value(doc)
    p._skip()
    if p.pos != p._len():
        raise JsonError("trailing data", p.pos)
    return doc^
