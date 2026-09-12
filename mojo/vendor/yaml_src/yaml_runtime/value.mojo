from std.collections import List, Span

from yaml_runtime.error import DecodeError
from yaml_runtime.options import DecodeOptions, EncodeOptions
from yaml_wire.number import encoded_float_len, encoded_int_len
from yaml_wire.reader import (
    TAG_BINARY,
    TAG_BOOL,
    TAG_FLOAT,
    TAG_INT,
    TAG_MAP,
    TAG_NONE,
    TAG_NONSPEC,
    TAG_NULL,
    TAG_SEQ,
    TAG_STR,
    WireReader,
)
from yaml_wire.scalar import encoded_string_len
from yaml_wire.writer import WireWriter


comptime YK_NULL = 1
comptime YK_FALSE = 2
comptime YK_TRUE = 3
comptime YK_INT = 4
comptime YK_FLOAT = 5
comptime YK_STRING = 6
comptime YK_SEQ = 7
comptime YK_MAP = 8
comptime YK_BINARY = 9


struct YamlNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int64
    var b: UInt64
    var c: Int

    def __init__(out self, kind: Int, a: Int64 = 0, b: UInt64 = 0, c: Int = 0):
        self.kind = kind
        self.a = a
        self.b = b
        self.c = c


struct YamlValue(Copyable, Movable):
    """Arena of YAML values. Nested containers use `kids` as a child-index table."""

    var nodes: List[YamlNode]
    var kids: List[Int]
    var texts: List[String]
    var bytes: List[List[Byte]]
    var anchors: List[Int]
    var root: Int

    def __init__(out self):
        self.nodes = List[YamlNode]()
        self.kids = List[Int]()
        self.texts = List[String]()
        self.bytes = List[List[Byte]]()
        self.anchors = List[Int]()
        self.root = 0

    def copy(self) -> Self:
        var out = YamlValue()
        out.root = self.root
        var i = 0
        while i < len(self.nodes):
            out.nodes.append(self.nodes[i])
            i += 1
        i = 0
        while i < len(self.kids):
            out.kids.append(self.kids[i])
            i += 1
        i = 0
        while i < len(self.texts):
            out.texts.append(self.texts[i])
            i += 1
        i = 0
        while i < len(self.bytes):
            var row = List[Byte]()
            var j = 0
            while j < len(self.bytes[i]):
                row.append(self.bytes[i][j])
                j += 1
            out.bytes.append(row^)
            i += 1
        i = 0
        while i < len(self.anchors):
            out.anchors.append(self.anchors[i])
            i += 1
        return out^

    def add(mut self, node: YamlNode) -> Int:
        var idx = len(self.nodes)
        self.nodes.append(node)
        return idx

    def kind(self) -> Int:
        return self.nodes[self.root].kind

    def is_null(self) -> Bool:
        return self.kind() == YK_NULL

    def is_bool(self) -> Bool:
        var k = self.kind()
        return k == YK_TRUE or k == YK_FALSE

    def is_int(self) -> Bool:
        return self.kind() == YK_INT

    def is_float(self) -> Bool:
        return self.kind() == YK_FLOAT

    def is_string(self) -> Bool:
        return self.kind() == YK_STRING

    def is_seq(self) -> Bool:
        return self.kind() == YK_SEQ

    def is_map(self) -> Bool:
        return self.kind() == YK_MAP

    def is_binary(self) -> Bool:
        return self.kind() == YK_BINARY

    def as_bool(self) raises DecodeError -> Bool:
        var k = self.kind()
        if k == YK_TRUE:
            return True
        if k == YK_FALSE:
            return False
        raise DecodeError(DecodeError.KIND_TYPE, 0)

    def as_int(self) raises DecodeError -> Int64:
        if self.kind() != YK_INT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].a

    def as_float(self) raises DecodeError -> Float64:
        var k = self.kind()
        if k == YK_INT:
            return Float64(self.nodes[self.root].a)
        if k == YK_FLOAT:
            return Float64(from_bits=self.nodes[self.root].b)
        raise DecodeError(DecodeError.KIND_TYPE, 0)

    def as_str(self) raises DecodeError -> String:
        if self.kind() != YK_STRING:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.texts[Int(self.nodes[self.root].a)]

    def as_bytes(self) raises DecodeError -> List[Byte]:
        if self.kind() != YK_BINARY:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var src = self.bytes[Int(self.nodes[self.root].a)].copy()
        var out = List[Byte]()
        var i = 0
        while i < len(src):
            out.append(src[i])
            i += 1
        return out^

    def count(self) -> Int:
        var k = self.kind()
        if k == YK_SEQ or k == YK_MAP:
            return Int(self.nodes[self.root].b)
        return 0

    def at(self, i: Int) raises DecodeError -> YamlValue:
        if self.kind() != YK_SEQ:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = self.count()
        if i < 0 or i >= n:
            raise DecodeError(DecodeError.KIND_RANGE, 0)
        var idx = self.kids[Int(self.nodes[self.root].a) + i]
        return self._view(idx)

    def pair(self, i: Int) raises DecodeError -> Tuple[YamlValue, YamlValue]:
        if self.kind() != YK_MAP:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = self.count()
        if i < 0 or i >= n:
            raise DecodeError(DecodeError.KIND_RANGE, 0)
        var base = Int(self.nodes[self.root].a) + i * 2
        return (self._view(self.kids[base]), self._view(self.kids[base + 1]))

    def get(self, key: String) raises DecodeError -> YamlValue:
        if self.kind() != YK_MAP:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = self.count()
        var i = 0
        while i < n:
            var kidx = self.kids[Int(self.nodes[self.root].a) + i * 2]
            var kn = self.nodes[kidx]
            if kn.kind == YK_STRING:
                if self.texts[Int(kn.a)] == key:
                    return self._view(self.kids[Int(self.nodes[self.root].a) + i * 2 + 1])
            i += 1
        raise DecodeError(DecodeError.KIND_TYPE, 0)

    def _view(self, idx: Int) -> YamlValue:
        var out = self.copy()
        out.root = idx
        return out^


def yaml_null() -> YamlValue:
    var v = YamlValue()
    v.root = v.add(YamlNode(YK_NULL))
    return v^


def yaml_bool(x: Bool) -> YamlValue:
    var v = YamlValue()
    if x:
        v.root = v.add(YamlNode(YK_TRUE))
    else:
        v.root = v.add(YamlNode(YK_FALSE))
    return v^


def yaml_int(x: Int64) -> YamlValue:
    var v = YamlValue()
    v.root = v.add(YamlNode(YK_INT, x))
    return v^


def yaml_float(x: Float64) -> YamlValue:
    var v = YamlValue()
    v.root = v.add(YamlNode(YK_FLOAT, 0, UInt64(x.to_bits())))
    return v^


def yaml_string(s: String) -> YamlValue:
    var v = YamlValue()
    var ti = len(v.texts)
    v.texts.append(s)
    v.root = v.add(YamlNode(YK_STRING, Int64(ti)))
    return v^


def yaml_seq(items: List[YamlValue]) -> YamlValue:
    var v = YamlValue()
    var base = len(v.kids)
    var i = 0
    while i < len(items):
        var idx = _graft(items[i], v)
        v.kids.append(idx)
        i += 1
    v.root = v.add(YamlNode(YK_SEQ, Int64(base), UInt64(len(items))))
    return v^


def yaml_map(keys: List[String], vals: List[YamlValue]) -> YamlValue:
    var v = YamlValue()
    var base = len(v.kids)
    var i = 0
    while i < len(keys):
        var k = yaml_string(keys[i])
        v.kids.append(_graft(k, v))
        v.kids.append(_graft(vals[i], v))
        i += 1
    v.root = v.add(YamlNode(YK_MAP, Int64(base), UInt64(len(keys))))
    return v^


def _graft(src: YamlValue, mut dest: YamlValue) -> Int:
    return _graft_node(src, src.root, dest)


def _graft_node(src: YamlValue, idx: Int, mut dest: YamlValue) -> Int:
    var n = src.nodes[idx]
    if n.kind == YK_STRING:
        var ti = len(dest.texts)
        dest.texts.append(src.texts[Int(n.a)])
        return dest.add(YamlNode(YK_STRING, Int64(ti)))
    if n.kind == YK_BINARY:
        var bi = len(dest.bytes)
        var row = List[Byte]()
        var j = 0
        var srcb = src.bytes[Int(n.a)].copy()
        while j < len(srcb):
            row.append(srcb[j])
            j += 1
        dest.bytes.append(row^)
        return dest.add(YamlNode(YK_BINARY, Int64(bi)))
    if n.kind == YK_SEQ:
        var base = len(dest.kids)
        var c = Int(n.b)
        var i = 0
        while i < c:
            dest.kids.append(_graft_node(src, src.kids[Int(n.a) + i], dest))
            i += 1
        return dest.add(YamlNode(YK_SEQ, Int64(base), UInt64(c)))
    if n.kind == YK_MAP:
        var base = len(dest.kids)
        var c = Int(n.b)
        var i = 0
        while i < c:
            dest.kids.append(_graft_node(src, src.kids[Int(n.a) + i * 2], dest))
            dest.kids.append(_graft_node(src, src.kids[Int(n.a) + i * 2 + 1], dest))
            i += 1
        return dest.add(YamlNode(YK_MAP, Int64(base), UInt64(c)))
    return dest.add(n)


def decode_value[
    origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> YamlValue:
    var r = WireReader[origin](buf, options=options)
    var v = decode_one(r)
    r.skip_separation()
    if r.remaining() > 0 and not r.at_document_end():
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return v^


def decode_one[
    origin: ImmOrigin
](mut r: WireReader[origin]) raises DecodeError -> YamlValue:
    r.skip_document_start()
    var v = YamlValue()
    v.root = _decode_node(r, v)
    r.skip_document_end()
    return v^


def encode_value(
    value: YamlValue, options: EncodeOptions = EncodeOptions.block
) raises DecodeError -> List[Byte]:
    var w = WireWriter(capacity=256, exact=True)
    _encode_node(value, value.root, w, options, 0, False)
    if w.pos == 0 or Int(w.buf[w.pos - 1]) != 10:
        w.write_lf()
    return w^.finish()


def _decode_node[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: YamlValue) raises DecodeError -> Int:
    r.skip_separation()
    var al = r.take_alias()
    if al:
        r.end_alias(al.value())
        return v.root
    if r.looks_seq():
        var st = r.begin_seq()
        var items = List[Int]()
        while r.next_item(st):
            items.append(_decode_node(r, v))
        r.end_seq(st)
        var base = len(v.kids)
        var i = 0
        while i < len(items):
            v.kids.append(items[i])
            i += 1
        return v.add(YamlNode(YK_SEQ, Int64(base), UInt64(len(items))))
    if r.looks_map():
        var st = r.begin_map()
        var ks = List[Int]()
        var vs = List[Int]()
        while r.next_key(st):
            var key = r.read_string()
            var ti = len(v.texts)
            v.texts.append(key^)
            ks.append(v.add(YamlNode(YK_STRING, Int64(ti))))
            r.expect_colon()
            vs.append(_decode_node(r, v))
        r.end_map(st)
        var base = len(v.kids)
        var j = 0
        while j < len(ks):
            v.kids.append(ks[j])
            v.kids.append(vs[j])
            j += 1
        return v.add(YamlNode(YK_MAP, Int64(base), UInt64(len(ks))))
    var s = r.read_string()
    var tag = r.last_tag
    if tag == TAG_BINARY:
        var raw = List[Byte]()
        var bb = s.as_bytes()
        var i = 0
        while i < len(bb):
            raw.append(bb[i])
            i += 1
        var bi = len(v.bytes)
        v.bytes.append(raw^)
        return v.add(YamlNode(YK_BINARY, Int64(bi)))
    if tag == TAG_STR or tag == TAG_NONSPEC:
        var ti = len(v.texts)
        v.texts.append(s^)
        return v.add(YamlNode(YK_STRING, Int64(ti)))
    if tag == TAG_NULL or (tag == TAG_NONE and _plain_null(s)):
        return v.add(YamlNode(YK_NULL))
    if tag == TAG_BOOL or (tag == TAG_NONE and _plain_bool(s)):
        if s == "true" or s == "True" or s == "TRUE":
            return v.add(YamlNode(YK_TRUE))
        return v.add(YamlNode(YK_FALSE))
    if tag == TAG_INT or (tag == TAG_NONE and _plain_int(s)):
        return v.add(YamlNode(YK_INT, _as_int(s)))
    if tag == TAG_FLOAT or (tag == TAG_NONE and _plain_float(s)):
        var f = _as_float(s)
        return v.add(YamlNode(YK_FLOAT, 0, UInt64(f.to_bits())))
    var ti = len(v.texts)
    v.texts.append(s^)
    return v.add(YamlNode(YK_STRING, Int64(ti)))


def _plain_null(s: String) -> Bool:
    return s == "null" or s == "Null" or s == "NULL" or s == "~" or s.byte_length() == 0


def _plain_bool(s: String) -> Bool:
    return (
        s == "true"
        or s == "True"
        or s == "TRUE"
        or s == "false"
        or s == "False"
        or s == "FALSE"
    )


def _plain_int(s: String) -> Bool:
    try:
        _ = _as_int(s)
        return True
    except _:
        return False


def _plain_float(s: String) -> Bool:
    if (
        s == ".inf"
        or s == ".Inf"
        or s == ".INF"
        or s == "-.inf"
        or s == "-.Inf"
        or s == "-.INF"
        or s == "+.inf"
        or s == "+.Inf"
        or s == "+.INF"
        or s == ".nan"
        or s == ".NaN"
        or s == ".NAN"
    ):
        return True
    var b = s.as_bytes()
    var i = 0
    if len(b) == 0:
        return False
    if Int(b[0]) == 43 or Int(b[0]) == 45:
        i = 1
    var saw_digit = False
    var saw_dot = False
    var saw_exp = False
    while i < len(b):
        var c = Int(b[i])
        if c >= 48 and c <= 57:
            saw_digit = True
        elif c == 46 and not saw_dot:
            saw_dot = True
        elif (c == 101 or c == 69) and saw_digit:
            saw_exp = True
        else:
            return False
        i += 1
    return saw_digit and (saw_dot or saw_exp)


def _as_int(s: String) raises DecodeError -> Int64:
    var r = WireReader(s.as_bytes())
    return r.read_int()


def _as_float(s: String) raises DecodeError -> Float64:
    var r = WireReader(s.as_bytes())
    return r.read_as_f64()


def _encode_node(
    v: YamlValue,
    idx: Int,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline: Bool,
) raises DecodeError:
    var n = v.nodes[idx]
    if n.kind == YK_NULL:
        w.write_null()
        return
    if n.kind == YK_TRUE:
        w.write_bool(True)
        return
    if n.kind == YK_FALSE:
        w.write_bool(False)
        return
    if n.kind == YK_INT:
        w.write_int(n.a)
        return
    if n.kind == YK_FLOAT:
        w.write_float(Float64(from_bits=n.b))
        return
    if n.kind == YK_STRING:
        w.write_string(v.texts[Int(n.a)], options)
        return
    if n.kind == YK_BINARY:
        w.write_binary(Span(v.bytes[Int(n.a)]))
        return
    if n.kind == YK_SEQ:
        _encode_seq(v, idx, w, options, depth, inline)
        return
    _encode_map(v, idx, w, options, depth, inline)


def _encode_seq(
    v: YamlValue,
    idx: Int,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    inline: Bool,
) raises DecodeError:
    var n = v.nodes[idx]
    var count = Int(n.b)
    if options.is_flow() or count == 0:
        w.write_byte(Byte(91))
        var i = 0
        while i < count:
            if i > 0:
                w.write_ascii(", ")
            _encode_node(v, v.kids[Int(n.a) + i], w, options, depth, True)
            i += 1
        w.write_byte(Byte(93))
        return
    var i = 0
    while i < count:
        if i > 0 or not inline:
            if i > 0:
                w.write_lf()
            w.indent_depth = depth
            w.write_indent(options)
        w.write_ascii("- ")
        var child = v.nodes[v.kids[Int(n.a) + i]]
        if child.kind == YK_MAP:
            _encode_map(v, v.kids[Int(n.a) + i], w, options, depth, True)
        else:
            _encode_node(v, v.kids[Int(n.a) + i], w, options, depth + 1, True)
        i += 1


def _encode_map(
    v: YamlValue,
    idx: Int,
    mut w: WireWriter,
    options: EncodeOptions,
    depth: Int,
    compact: Bool,
) raises DecodeError:
    var n = v.nodes[idx]
    var count = Int(n.b)
    if options.is_flow() or count == 0:
        w.write_byte(Byte(123))
        var i = 0
        while i < count:
            if i > 0:
                w.write_ascii(", ")
            _encode_node(v, v.kids[Int(n.a) + i * 2], w, options, depth, True)
            w.write_ascii(": ")
            _encode_node(v, v.kids[Int(n.a) + i * 2 + 1], w, options, depth, True)
            i += 1
        w.write_byte(Byte(125))
        return
    var i = 0
    while i < count:
        if i > 0 or not compact:
            if i > 0:
                w.write_lf()
            if compact:
                w.indent_depth = depth + 1
            else:
                w.indent_depth = depth
            w.write_indent(options)
        _encode_node(v, v.kids[Int(n.a) + i * 2], w, options, depth, True)
        w.write_ascii(": ")
        var vi = v.kids[Int(n.a) + i * 2 + 1]
        var child = v.nodes[vi]
        if child.kind == YK_MAP:
            w.write_lf()
            _encode_map(v, vi, w, options, depth + 1, False)
        elif child.kind == YK_SEQ:
            w.write_lf()
            _encode_seq(v, vi, w, options, depth, False)
        else:
            _encode_node(v, vi, w, options, depth + 1, True)
        i += 1
