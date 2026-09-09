from std.collections import List, Span

from gldjson_runtime.error import DecodeError
from gldjson_runtime.options import DecodeOptions, EncodeOptions
from gldjson_wire.classify import MAX_COUNT
from gldjson_wire.number import encoded_float_len, encoded_int_len
from gldjson_wire.reader import WireReader
from gldjson_wire.string import encoded_string_len
from gldjson_wire.writer import WireWriter


comptime JK_NULL = 1
comptime JK_FALSE = 2
comptime JK_TRUE = 3
comptime JK_INT = 4
comptime JK_FLOAT = 5
comptime JK_STRING = 6
comptime JK_ARRAY = 7
comptime JK_OBJECT = 8


struct JsonNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var a: Int64
    var b: UInt64
    var c: Int

    def __init__(out self, kind: Int, a: Int64 = 0, b: UInt64 = 0, c: Int = 0):
        self.kind = kind
        self.a = a
        self.b = b
        self.c = c


struct JsonValue(Copyable, Movable):
    """Arena of JSON values. Nested containers use `kids` as a child-index table."""

    var nodes: List[JsonNode]
    var kids: List[Int]
    var texts: List[String]
    var root: Int

    def __init__(out self):
        self.nodes = List[JsonNode]()
        self.kids = List[Int]()
        self.texts = List[String]()
        self.root = 0

    def copy(self) -> Self:
        var out = JsonValue()
        out.root = _copy_into(self, self.root, out)
        return out^

    def add(mut self, node: JsonNode) -> Int:
        var idx = len(self.nodes)
        self.nodes.append(node)
        return idx

    def kind(self) -> Int:
        return self.nodes[self.root].kind

    def is_null(self) -> Bool:
        return self.kind() == JK_NULL

    def is_bool(self) -> Bool:
        var k = self.kind()
        return k == JK_TRUE or k == JK_FALSE

    def is_int(self) -> Bool:
        return self.kind() == JK_INT

    def is_float(self) -> Bool:
        return self.kind() == JK_FLOAT

    def is_string(self) -> Bool:
        return self.kind() == JK_STRING

    def is_array(self) -> Bool:
        return self.kind() == JK_ARRAY

    def is_object(self) -> Bool:
        return self.kind() == JK_OBJECT

    def as_bool(self) raises DecodeError -> Bool:
        var k = self.kind()
        if k == JK_TRUE:
            return True
        if k == JK_FALSE:
            return False
        raise DecodeError(DecodeError.KIND_TYPE, 0)

    def as_int(self) raises DecodeError -> Int64:
        if self.kind() != JK_INT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.nodes[self.root].a

    def as_float(self) raises DecodeError -> Float64:
        var k = self.kind()
        if k == JK_INT:
            return Float64(self.nodes[self.root].a)
        if k == JK_FLOAT:
            return Float64(from_bits=self.nodes[self.root].b)
        raise DecodeError(DecodeError.KIND_TYPE, 0)

    def as_str(self) raises DecodeError -> String:
        if self.kind() != JK_STRING:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return self.texts[Int(self.nodes[self.root].a)]

    def count(self) -> Int:
        var k = self.kind()
        if k == JK_ARRAY or k == JK_OBJECT:
            return Int(self.nodes[self.root].b)
        return 0

    def at(self, i: Int) raises DecodeError -> JsonValue:
        if self.kind() != JK_ARRAY:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = self.count()
        if i < 0 or i >= n:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var first = Int(self.nodes[self.root].a)
        return _copy_node(self, self.kids[first + i])

    def pair(self, i: Int) raises DecodeError -> Tuple[String, JsonValue]:
        if self.kind() != JK_OBJECT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = self.count()
        if i < 0 or i >= n:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var first_key = Int(self.nodes[self.root].a)
        var first_val = self.nodes[self.root].c
        var kn = self.kids[first_key + i]
        var vn = self.kids[first_val + i]
        var key = self.texts[Int(self.nodes[kn].a)]
        return (key, _copy_node(self, vn))

    def get(self, key: String) raises DecodeError -> JsonValue:
        if self.kind() != JK_OBJECT:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        var n = self.count()
        var first_key = Int(self.nodes[self.root].a)
        var first_val = self.nodes[self.root].c
        var found = -1
        var i = 0
        while i < n:
            var kn = self.kids[first_key + i]
            if self.texts[Int(self.nodes[kn].a)] == key:
                found = self.kids[first_val + i]
            i += 1
        if found < 0:
            raise DecodeError(DecodeError.KIND_TYPE, 0)
        return _copy_node(self, found)


def _copy_node(src: JsonValue, idx: Int) -> JsonValue:
    var out = JsonValue()
    out.root = _copy_into(src, idx, out)
    return out^


def _copy_into(src: JsonValue, idx: Int, mut dest: JsonValue) -> Int:
    var node = src.nodes[idx]
    if node.kind == JK_STRING:
        var start = len(dest.texts)
        dest.texts.append(src.texts[Int(node.a)])
        return dest.add(JsonNode(JK_STRING, a=Int64(start), b=node.b))
    if node.kind == JK_ARRAY:
        var n = Int(node.b)
        var first = Int(node.a)
        var ids = List[Int]()
        var i = 0
        while i < n:
            ids.append(_copy_into(src, src.kids[first + i], dest))
            i += 1
        var kids_start = len(dest.kids)
        i = 0
        while i < n:
            dest.kids.append(ids[i])
            i += 1
        return dest.add(JsonNode(JK_ARRAY, a=Int64(kids_start), b=UInt64(n)))
    if node.kind == JK_OBJECT:
        var n = Int(node.b)
        var first_key = Int(node.a)
        var first_val = node.c
        var key_ids = List[Int]()
        var val_ids = List[Int]()
        var i = 0
        while i < n:
            key_ids.append(_copy_into(src, src.kids[first_key + i], dest))
            val_ids.append(_copy_into(src, src.kids[first_val + i], dest))
            i += 1
        var keys_start = len(dest.kids)
        i = 0
        while i < n:
            dest.kids.append(key_ids[i])
            i += 1
        var vals_start = len(dest.kids)
        i = 0
        while i < n:
            dest.kids.append(val_ids[i])
            i += 1
        return dest.add(JsonNode(JK_OBJECT, a=Int64(keys_start), b=UInt64(n), c=vals_start))
    return dest.add(JsonNode(node.kind, a=node.a, b=node.b, c=node.c))


def json_null() -> JsonValue:
    var v = JsonValue()
    v.root = v.add(JsonNode(JK_NULL))
    return v^


def json_bool(flag: Bool) -> JsonValue:
    var v = JsonValue()
    if flag:
        v.root = v.add(JsonNode(JK_TRUE))
    else:
        v.root = v.add(JsonNode(JK_FALSE))
    return v^


def json_int(n: Int64) -> JsonValue:
    var v = JsonValue()
    v.root = v.add(JsonNode(JK_INT, a=n))
    return v^


def json_float(n: Float64) -> JsonValue:
    var v = JsonValue()
    v.root = v.add(JsonNode(JK_FLOAT, b=UInt64(n.to_bits())))
    return v^


def json_string(s: String) -> JsonValue:
    var v = JsonValue()
    v.texts.append(s)
    v.root = v.add(JsonNode(JK_STRING, a=Int64(0), b=UInt64(s.byte_length())))
    return v^


def json_array(items: List[JsonValue]) -> JsonValue:
    var v = JsonValue()
    var n = len(items)
    var first = len(v.kids)
    var i = 0
    while i < n:
        v.kids.append(0)
        i += 1
    i = 0
    while i < n:
        v.kids[first + i] = _copy_into(items[i], items[i].root, v)
        i += 1
    v.root = v.add(JsonNode(JK_ARRAY, a=Int64(first), b=UInt64(n)))
    return v^


def json_object(pairs: List[Tuple[String, JsonValue]]) -> JsonValue:
    var v = JsonValue()
    var n = len(pairs)
    var keys_start = len(v.kids)
    var i = 0
    while i < n:
        v.kids.append(0)
        i += 1
    var vals_start = len(v.kids)
    i = 0
    while i < n:
        v.kids.append(0)
        i += 1
    i = 0
    while i < n:
        var key = pairs[i][0]
        var t = len(v.texts)
        v.texts.append(key)
        v.kids[keys_start + i] = v.add(
            JsonNode(JK_STRING, a=Int64(t), b=UInt64(key.byte_length()))
        )
        v.kids[vals_start + i] = _copy_into(pairs[i][1], pairs[i][1].root, v)
        i += 1
    v.root = v.add(JsonNode(JK_OBJECT, a=Int64(keys_start), b=UInt64(n), c=vals_start))
    return v^


def decode_item[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: JsonValue) raises DecodeError -> Int:
    var c = r.peek()
    if c == 110:
        r.read_null()
        return v.add(JsonNode(JK_NULL))
    if c == 116:
        r.read_true()
        return v.add(JsonNode(JK_TRUE))
    if c == 102:
        r.read_false()
        return v.add(JsonNode(JK_FALSE))
    if c == 34:
        var s = r.read_string()
        var slen = s.byte_length()
        var t = len(v.texts)
        v.texts.append(s^)
        return v.add(JsonNode(JK_STRING, a=Int64(t), b=UInt64(slen)))
    if c == 91:
        return _decode_array(r, v)
    if c == 123:
        return _decode_object(r, v)
    if c == 45 or (c >= 48 and c <= 57):
        var tok = r.read_number()
        if tok.is_int:
            return v.add(JsonNode(JK_INT, a=tok.i))
        return v.add(JsonNode(JK_FLOAT, b=UInt64(tok.f.to_bits())))
    raise DecodeError(DecodeError.KIND_SYNTAX, r.position())


def _decode_array[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: JsonValue) raises DecodeError -> Int:
    r.enter()
    r.eat(91)
    if r.peek() == 93:
        r.eat(93)
        r.leave()
        return v.add(JsonNode(JK_ARRAY, a=Int64(len(v.kids)), b=UInt64(0)))
    var ids = List[Int]()
    while True:
        if len(ids) >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, r.position())
        ids.append(decode_item(r, v))
        var s = r.peek()
        if s == 93:
            r.eat(93)
            r.leave()
            var kids_start = len(v.kids)
            var j = 0
            while j < len(ids):
                v.kids.append(ids[j])
                j += 1
            return v.add(JsonNode(JK_ARRAY, a=Int64(kids_start), b=UInt64(len(ids))))
        if s != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
        r.eat(44)
        if r.peek() == 93:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())


def _decode_object[
    origin: ImmOrigin
](mut r: WireReader[origin], mut v: JsonValue) raises DecodeError -> Int:
    r.enter()
    r.eat(123)
    if r.peek() == 125:
        r.eat(125)
        r.leave()
        return v.add(JsonNode(JK_OBJECT, a=Int64(len(v.kids)), b=UInt64(0), c=len(v.kids)))
    var keys = List[Int]()
    var vals = List[Int]()
    var seen = List[String]()
    while True:
        if len(keys) >= MAX_COUNT:
            raise DecodeError(DecodeError.KIND_RANGE, r.position())
        if r.peek() != 34:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
        var key = r.read_string()
        if r.options.strict_keys:
            var i = 0
            while i < len(seen):
                if seen[i] == key:
                    raise DecodeError(DecodeError.KIND_DUP_KEY, r.position())
                i += 1
            seen.append(key)
        r.eat(58)
        var kn = len(v.texts)
        var klen = key.byte_length()
        v.texts.append(key^)
        keys.append(v.add(JsonNode(JK_STRING, a=Int64(kn), b=UInt64(klen))))
        vals.append(decode_item(r, v))
        var s = r.peek()
        if s == 125:
            r.eat(125)
            r.leave()
            var keys_start = len(v.kids)
            var i = 0
            while i < len(keys):
                v.kids.append(keys[i])
                i += 1
            var vals_start = len(v.kids)
            i = 0
            while i < len(vals):
                v.kids.append(vals[i])
                i += 1
            return v.add(
                JsonNode(JK_OBJECT, a=Int64(keys_start), b=UInt64(len(keys)), c=vals_start)
            )
        if s != 44:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())
        r.eat(44)
        if r.peek() == 125:
            raise DecodeError(DecodeError.KIND_SYNTAX, r.position())


def decode_value[
    origin: ImmOrigin
](
    buf: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> JsonValue:
    var v = JsonValue()
    var r = WireReader[origin](buf, options)
    v.root = decode_item(r, v)
    r.skip_ws()
    if r.remaining() > 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.position())
    return v^


def encode_value(
    value: JsonValue, options: EncodeOptions = EncodeOptions.compact
) -> List[Byte]:
    var cap = _encoded_len_at(value, value.root, options, 0)
    if cap < 1:
        cap = 1
    var w = WireWriter(capacity=cap, exact=True)
    _encode_node(value, value.root, w, options)
    return w^.finish()


def _encoded_len_at(v: JsonValue, idx: Int, options: EncodeOptions, depth: Int) -> Int:
    var node = v.nodes[idx]
    if node.kind == JK_NULL:
        return 4
    if node.kind == JK_TRUE:
        return 4
    if node.kind == JK_FALSE:
        return 5
    if node.kind == JK_INT:
        return encoded_int_len(node.a)
    if node.kind == JK_FLOAT:
        return encoded_float_len(Float64(from_bits=node.b))
    if node.kind == JK_STRING:
        return encoded_string_len(v.texts[Int(node.a)])
    var pretty = options.mode == EncodeOptions.PRETTY
    var n = 1
    var count = Int(node.b)
    if node.kind == JK_ARRAY:
        var first = Int(node.a)
        var i = 0
        while i < count:
            if pretty:
                n += 1 + (depth + 1) * options.indent
                if i > 0:
                    n += 1
            elif i > 0:
                n += 1
            n += _encoded_len_at(v, v.kids[first + i], options, depth + 1)
            i += 1
        if pretty and count > 0:
            n += 1 + depth * options.indent
        n += 1
        return n
    var first_key = Int(node.a)
    var first_val = node.c
    var i = 0
    while i < count:
        if pretty:
            n += 1 + (depth + 1) * options.indent
            if i > 0:
                n += 1
            n += 1
        elif i > 0:
            n += 1
        var kn = v.kids[first_key + i]
        n += encoded_string_len(v.texts[Int(v.nodes[kn].a)])
        n += 1
        if pretty:
            n += 1
        n += _encoded_len_at(v, v.kids[first_val + i], options, depth + 1)
        i += 1
    if pretty and count > 0:
        n += 1 + depth * options.indent
    n += 1
    return n


def _encode_node(
    v: JsonValue, idx: Int, mut w: WireWriter, options: EncodeOptions
):
    var node = v.nodes[idx]
    if node.kind == JK_NULL:
        w.write_null()
        return
    if node.kind == JK_TRUE:
        w.write_bool(True)
        return
    if node.kind == JK_FALSE:
        w.write_bool(False)
        return
    if node.kind == JK_INT:
        w.write_int(node.a)
        return
    if node.kind == JK_FLOAT:
        try:
            w.write_float(Float64(from_bits=node.b))
        except _:
            w.write_literal("0")
        return
    if node.kind == JK_STRING:
        w.write_string(v.texts[Int(node.a)])
        return
    var pretty = options.mode == EncodeOptions.PRETTY
    if node.kind == JK_ARRAY:
        w.write_byte(Byte(91))
        if pretty:
            w.pretty_depth += 1
        var first_c = Int(node.a)
        var count = Int(node.b)
        var i = 0
        while i < count:
            w.write_member_sep(options, i == 0)
            _encode_node(v, v.kids[first_c + i], w, options)
            i += 1
        if pretty:
            w.pretty_depth -= 1
            if count > 0:
                w.write_byte(Byte(10))
                w.write_indent(options)
        w.write_byte(Byte(93))
        return
    w.write_byte(Byte(123))
    if pretty:
        w.pretty_depth += 1
    var first_key = Int(node.a)
    var first_val = node.c
    var count = Int(node.b)
    var i = 0
    while i < count:
        w.write_member_sep(options, i == 0)
        var kn = v.kids[first_key + i]
        w.write_string(v.texts[Int(v.nodes[kn].a)])
        w.write_colon(options)
        _encode_node(v, v.kids[first_val + i], w, options)
        i += 1
    if pretty:
        w.pretty_depth -= 1
        if count > 0:
            w.write_byte(Byte(10))
            w.write_indent(options)
    w.write_byte(Byte(125))
