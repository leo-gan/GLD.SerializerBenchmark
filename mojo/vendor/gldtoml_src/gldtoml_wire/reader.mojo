from std.collections import List, Span

from gldtoml_runtime.error import DecodeError
from gldtoml_runtime.options import DecodeOptions
from gldtoml_wire.doc import (
    FLAG_EXPLICIT,
    FLAG_FROZEN,
    MAX_DEPTH,
    TK_ARRAY,
    TK_TABLE,
    TomlDateTime,
    TomlDoc,
    bytes_to_string,
)
from gldtoml_wire.utf8 import append_scalar, trusted_utf8, validate_utf8


def decode_toml(
    text: String, options: DecodeOptions = DecodeOptions.default
) raises DecodeError -> TomlDoc:
    return decode_bytes(text.as_bytes(), options)


def decode_bytes[
    origin: ImmOrigin
](data: Span[Byte, origin], options: DecodeOptions = DecodeOptions.default) raises DecodeError -> TomlDoc:
    if len(data) >= 3 and Int(data[0]) == 0xEF and Int(data[1]) == 0xBB and Int(data[2]) == 0xBF:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    validate_utf8(data)
    var doc = TomlDoc()
    var p = Parser[origin](data, options)
    p.run(doc)
    return doc^


struct Parser[origin: ImmOrigin]:
    var data: Span[Byte, Self.origin]
    var n: Int
    var i: Int
    var options: DecodeOptions
    var header: Int
    var header_keys: List[String]
    var pending: List[Int]

    def __init__(out self, data: Span[Byte, Self.origin], options: DecodeOptions):
        self.data = data
        self.n = len(data)
        self.i = 0
        self.options = options
        self.header = 0
        self.header_keys = List[String]()
        self.pending = List[Int]()

    def eof(self) -> Bool:
        return self.i >= self.n

    def peek(self) -> Int:
        if self.i >= self.n:
            return -1
        return Int(self.data[self.i])

    def peek_at(self, k: Int) -> Int:
        var j = self.i + k
        if j < 0 or j >= self.n:
            return -1
        return Int(self.data[j])

    def err(self, kind: Int) raises DecodeError -> None:
        raise DecodeError(kind, self.i)

    def is_ws(self, c: Int) -> Bool:
        return c == 32 or c == 9

    def is_digit(self, c: Int) -> Bool:
        return c >= 48 and c <= 57

    def is_hex(self, c: Int) -> Bool:
        return self.is_digit(c) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102)

    def hex_val(self, c: Int) -> Int:
        if self.is_digit(c):
            return c - 48
        if c >= 65 and c <= 70:
            return c - 55
        if c >= 97 and c <= 102:
            return c - 87
        return -1

    def is_bare(self, c: Int) -> Bool:
        return (
            (c >= 65 and c <= 90)
            or (c >= 97 and c <= 122)
            or self.is_digit(c)
            or c == 95
            or c == 45
        )

    def is_nl_at(self, j: Int) -> Bool:
        if j >= self.n:
            return False
        var c = Int(self.data[j])
        if c == 10:
            return True
        if c == 13 and j + 1 < self.n and Int(self.data[j + 1]) == 10:
            return True
        return False

    def skip_nl(mut self) raises DecodeError:
        if self.eof():
            self.err(DecodeError.KIND_EOF)
        var c = self.peek()
        if c == 10:
            self.i += 1
            return
        if c == 13 and self.peek_at(1) == 10:
            self.i += 2
            return
        self.err(DecodeError.KIND_SYNTAX)

    def skip_ws(mut self):
        while True:
            var c = self.peek()
            if not self.is_ws(c):
                return
            self.i += 1

    def skip_comment(mut self) raises DecodeError:
        if self.peek() != 35:
            return
        self.i += 1
        while not self.eof() and not self.is_nl_at(self.i):
            var c = self.peek()
            if c == 13 or c < 32 or c == 127:
                if c != 9:
                    self.err(DecodeError.KIND_SYNTAX)
            self.i += 1

    def skip_ws_and_comments(mut self) raises DecodeError:
        while True:
            var before = self.i
            while True:
                var c = self.peek()
                if self.is_ws(c):
                    self.i += 1
                    continue
                if self.is_nl_at(self.i):
                    self.skip_nl()
                    continue
                break
            self.skip_comment()
            if self.i == before:
                return

    def expect_end(mut self) raises DecodeError:
        if self.eof():
            return
        if self.is_nl_at(self.i):
            self.skip_nl()
            return
        self.err(DecodeError.KIND_SYNTAX)

    def expect(mut self, c: Int) raises DecodeError:
        if self.peek() != c:
            self.err(DecodeError.KIND_SYNTAX)
        self.i += 1

    def finalize(mut self, mut doc: TomlDoc):
        var i = 0
        while i < len(self.pending):
            doc.set_flag(self.pending[i], FLAG_EXPLICIT)
            i += 1
        self.pending = List[Int]()

    def run(mut self, mut doc: TomlDoc) raises DecodeError:
        self.header = doc.root
        while True:
            self.skip_ws()
            if self.eof():
                return
            var c = self.peek()
            if self.is_nl_at(self.i):
                self.skip_nl()
                continue
            if c == 35:
                self.skip_comment()
                self.expect_end()
                continue
            if self.is_bare(c):
                if not self.try_fast_eq(doc):
                    self.key_value(doc)
                self.skip_ws()
                self.skip_comment()
                self.expect_end()
                continue
            if c == 34 or c == 39:
                self.key_value(doc)
                self.skip_ws()
                self.skip_comment()
                self.expect_end()
                continue
            if c == 91:
                self.finalize(doc)
                if self.peek_at(1) == 91:
                    self.create_aot(doc)
                else:
                    self.create_table(doc)
                self.skip_ws()
                self.skip_comment()
                self.expect_end()
                continue
            self.err(DecodeError.KIND_SYNTAX)

    def parse_key(mut self) raises DecodeError -> List[String]:
        var parts = List[String]()
        var part = self.parse_key_part()
        parts.append(part^)
        while True:
            self.skip_ws()
            if self.peek() != 46:
                return parts^
            self.i += 1
            self.skip_ws()
            if len(parts) >= MAX_DEPTH:
                self.err(DecodeError.KIND_DEPTH)
            part = self.parse_key_part()
            parts.append(part^)

    def parse_key_part(mut self) raises DecodeError -> String:
        var c = self.peek()
        if self.is_bare(c):
            var start = self.i
            while self.is_bare(self.peek()):
                self.i += 1
            return trusted_utf8(self.data[start : self.i])
        if c == 39:
            if self.peek_at(1) == 39 and self.peek_at(2) == 39:
                self.err(DecodeError.KIND_SYNTAX)
            return self.parse_literal(False)
        if c == 34:
            if self.peek_at(1) == 34 and self.peek_at(2) == 34:
                self.err(DecodeError.KIND_SYNTAX)
            return self.parse_basic(False)
        self.err(DecodeError.KIND_SYNTAX)
        return String()

    def copy_keys(self, keys: List[String], n: Int) -> List[String]:
        var out = List[String]()
        var i = 0
        while i < n and i < len(keys):
            out.append(String(keys[i]))
            i += 1
        return out^

    def join_keys(self, head: List[String], tail: List[String], n: Int) -> List[String]:
        var out = List[String]()
        var i = 0
        while i < len(head):
            out.append(String(head[i]))
            i += 1
        i = 0
        while i < n and i < len(tail):
            out.append(String(tail[i]))
            i += 1
        return out^

    def resolve(
        mut self,
        mut doc: TomlDoc,
        start: Int,
        keys: List[String],
        create: Bool,
        access_lists: Bool,
    ) raises DecodeError -> Int:
        var cur = start
        var i = 0
        while i < len(keys):
            if doc.kind(cur) == TK_ARRAY:
                if not access_lists or doc.child_count(cur) == 0:
                    self.err(DecodeError.KIND_DUP_KEY)
                cur = doc.edges[doc.nodes[cur].tail].child
            if doc.kind(cur) != TK_TABLE:
                self.err(DecodeError.KIND_DUP_KEY)
            if create and doc.frozen(cur):
                self.err(DecodeError.KIND_DUP_KEY)
            var child = doc.find_key(cur, keys[i])
            if child < 0:
                if not create:
                    return -1
                var table = doc.make_table(cur)
                var owned = String(keys[i])
                var ti = doc.add_text(owned^)
                doc.append_child(cur, ti, table)
                cur = table
            else:
                cur = child
            i += 1
        return cur

    def nest(
        mut self,
        mut doc: TomlDoc,
        start: Int,
        keys: List[String],
        create: Bool,
        access_lists: Bool,
    ) raises DecodeError -> Int:
        var cur = self.resolve(doc, start, keys, create, access_lists)
        if cur < 0:
            return -1
        if doc.kind(cur) == TK_ARRAY:
            if not access_lists or doc.child_count(cur) == 0:
                self.err(DecodeError.KIND_DUP_KEY)
            cur = doc.edges[doc.nodes[cur].tail].child
        if doc.kind(cur) != TK_TABLE:
            self.err(DecodeError.KIND_DUP_KEY)
        return cur

    def path_frozen(mut self, mut doc: TomlDoc, keys: List[String]) raises DecodeError -> Bool:
        var cur = doc.root
        if doc.frozen(cur):
            return True
        var i = 0
        while i < len(keys):
            if doc.kind(cur) == TK_ARRAY:
                if doc.child_count(cur) == 0:
                    return False
                cur = doc.edges[doc.nodes[cur].tail].child
            if doc.kind(cur) != TK_TABLE:
                return False
            if doc.frozen(cur):
                return True
            var child = doc.find_key(cur, keys[i])
            if child < 0:
                return False
            cur = child
            if doc.frozen(cur):
                return True
            i += 1
        return False

    def flag_on(mut self, mut doc: TomlDoc, keys: List[String], bit: Int) raises DecodeError -> Bool:
        if bit == FLAG_FROZEN:
            return self.path_frozen(doc, keys)
        var node = self.resolve(doc, doc.root, keys, False, True)
        if node < 0:
            return False
        return doc.has_flag(node, bit)

    def create_table(mut self, mut doc: TomlDoc) raises DecodeError:
        self.i += 1
        self.skip_ws()
        var key = self.parse_key()
        if self.flag_on(doc, key, FLAG_EXPLICIT) or self.flag_on(doc, key, FLAG_FROZEN):
            self.err(DecodeError.KIND_DUP_KEY)
        var node = self.resolve(doc, doc.root, key, True, True)
        if doc.kind(node) != TK_TABLE:
            self.err(DecodeError.KIND_DUP_KEY)
        doc.set_flag(node, FLAG_EXPLICIT)
        self.skip_ws()
        self.expect(93)
        self.header = node
        self.header_keys = key^

    def create_aot(mut self, mut doc: TomlDoc) raises DecodeError:
        self.i += 2
        self.skip_ws()
        var key = self.parse_key()
        if len(key) == 0:
            self.err(DecodeError.KIND_SYNTAX)
        if self.flag_on(doc, key, FLAG_FROZEN):
            self.err(DecodeError.KIND_DUP_KEY)
        var parent_keys = self.copy_keys(key, len(key) - 1)
        var stem = String(key[len(key) - 1])
        var parent = self.nest(doc, doc.root, parent_keys, True, True)
        var existing = doc.find_key(parent, stem)
        var elem: Int
        if existing < 0:
            var arr = doc.make_array(parent)
            var ti = doc.add_text(stem^)
            doc.append_child(parent, ti, arr)
            doc.set_flag(arr, FLAG_EXPLICIT)
            elem = doc.make_table(arr)
            doc.append_child(arr, -1, elem)
        elif doc.kind(existing) == TK_ARRAY:
            elem = doc.make_table(existing)
            doc.append_child(existing, -1, elem)
        else:
            self.err(DecodeError.KIND_DUP_KEY)
            elem = -1
        self.skip_ws()
        self.expect(93)
        self.expect(93)
        self.header = elem
        self.header_keys = key^

    def try_fast_eq(mut self, mut doc: TomlDoc) raises DecodeError -> Bool:
        """Bare `key = value` with no dotted name. Returns false to use the general parser."""
        var start = self.i
        while self.is_bare(self.peek()):
            self.i += 1
        var key_end = self.i
        self.skip_ws()
        if self.peek() != 61:
            self.i = start
            return False
        self.i += 1
        self.skip_ws()
        if doc.frozen(self.header):
            self.err(DecodeError.KIND_DUP_KEY)
        var key = trusted_utf8(self.data[start:key_end])
        if doc.find_key(self.header, key) >= 0:
            self.err(DecodeError.KIND_DUP_KEY)
        var val = self.parse_value(doc, 0)
        var ti = doc.add_text(key^)
        doc.append_child(self.header, ti, val)
        var k = doc.kind(val)
        if k == TK_TABLE or k == TK_ARRAY:
            doc.set_flag(val, FLAG_FROZEN)
        return True

    def key_value(mut self, mut doc: TomlDoc) raises DecodeError:
        var key = self.parse_key()
        self.skip_ws()
        self.expect(61)
        self.skip_ws()
        var i = 1
        while i < len(key):
            var prefix = self.join_keys(self.header_keys, key, i)
            if self.flag_on(doc, prefix, FLAG_EXPLICIT):
                self.err(DecodeError.KIND_DUP_KEY)
            var node = self.resolve(doc, doc.root, prefix, True, True)
            self.pending.append(node)
            i += 1
        var parent_keys = self.join_keys(self.header_keys, key, len(key) - 1)
        if self.flag_on(doc, parent_keys, FLAG_FROZEN):
            self.err(DecodeError.KIND_DUP_KEY)
        var parent = self.nest(doc, doc.root, parent_keys, True, True)
        var stem = key.pop()
        if doc.find_key(parent, stem) >= 0:
            self.err(DecodeError.KIND_DUP_KEY)
        var val = self.parse_value(doc, 0)
        var ti = doc.add_text(stem^)
        doc.append_child(parent, ti, val)
        var k = doc.kind(val)
        if k == TK_TABLE or k == TK_ARRAY:
            doc.set_flag(val, FLAG_FROZEN)

    def parse_value(mut self, mut doc: TomlDoc, depth: Int) raises DecodeError -> Int:
        if depth > self.options.max_depth or depth > MAX_DEPTH:
            self.err(DecodeError.KIND_DEPTH)
        var c = self.peek()
        if c == 34:
            var text: String
            if self.peek_at(1) == 34 and self.peek_at(2) == 34:
                text = self.parse_multiline(False)
            else:
                text = self.parse_basic(False)
            return doc.make_string(text^, -1)
        if c == 39:
            var text: String
            if self.peek_at(1) == 39 and self.peek_at(2) == 39:
                text = self.parse_multiline(True)
            else:
                text = self.parse_literal(False)
            return doc.make_string(text^, -1)
        if c == 116 and self.starts("true"):
            self.i += 4
            return doc.make_bool(True, -1)
        if c == 102 and self.starts("false"):
            self.i += 5
            return doc.make_bool(False, -1)
        if c == 91:
            return self.parse_array(doc, depth + 1)
        if c == 123:
            return self.parse_inline(doc, depth + 1)
        if c == 43 or c == 45 or self.is_digit(c) or c == 105 or c == 110:
            return self.parse_scalar(doc)
        self.err(DecodeError.KIND_SYNTAX)
        return -1

    def starts(self, lit: String) -> Bool:
        var b = lit.as_bytes()
        var k = 0
        while k < len(b):
            if self.peek_at(k) != Int(b[k]):
                return False
            k += 1
        return True

    def parse_array(mut self, mut doc: TomlDoc, depth: Int) raises DecodeError -> Int:
        if depth > MAX_DEPTH:
            self.err(DecodeError.KIND_DEPTH)
        self.i += 1
        var arr = doc.make_array(-1)
        self.skip_ws_and_comments()
        if self.peek() == 93:
            self.i += 1
            return arr
        while True:
            var val = self.parse_value(doc, depth)
            doc.append_child(arr, -1, val)
            self.skip_ws_and_comments()
            var c = self.peek()
            if c == 93:
                self.i += 1
                return arr
            if c != 44:
                self.err(DecodeError.KIND_SYNTAX)
            self.i += 1
            self.skip_ws_and_comments()
            if self.peek() == 93:
                self.i += 1
                return arr

    def parse_inline(mut self, mut doc: TomlDoc, depth: Int) raises DecodeError -> Int:
        if depth > MAX_DEPTH:
            self.err(DecodeError.KIND_DEPTH)
        self.i += 1
        var table = doc.make_table(-1)
        self.skip_ws_and_comments()
        if self.peek() == 125:
            self.i += 1
            return table
        while True:
            var key = self.parse_key()
            if len(key) == 0:
                self.err(DecodeError.KIND_SYNTAX)
            var i = 1
            while i < len(key):
                var prefix = self.copy_keys(key, i)
                var node = self.resolve(doc, table, prefix, False, False)
                if node >= 0 and doc.frozen(node):
                    self.err(DecodeError.KIND_DUP_KEY)
                i += 1
            var parent_keys = self.copy_keys(key, len(key) - 1)
            var parent = self.nest(doc, table, parent_keys, True, False)
            if doc.frozen(parent):
                self.err(DecodeError.KIND_DUP_KEY)
            var stem = String(key[len(key) - 1])
            if doc.find_key(parent, stem) >= 0:
                self.err(DecodeError.KIND_DUP_KEY)
            self.skip_ws_and_comments()
            self.expect(61)
            self.skip_ws_and_comments()
            var val = self.parse_value(doc, depth)
            var ti = doc.add_text(stem^)
            doc.append_child(parent, ti, val)
            var vk = doc.kind(val)
            if vk == TK_TABLE or vk == TK_ARRAY:
                doc.set_flag(val, FLAG_FROZEN)
            self.skip_ws_and_comments()
            var c = self.peek()
            if c == 125:
                self.i += 1
                return table
            if c != 44:
                self.err(DecodeError.KIND_SYNTAX)
            self.i += 1
            self.skip_ws_and_comments()
            if self.peek() == 125:
                self.i += 1
                return table

    def parse_literal(mut self, multiline: Bool) raises DecodeError -> String:
        if not multiline:
            var start_i = self.i
            var j = self.i + 1
            while j < self.n:
                var c = Int(self.data[j])
                if c == 39:
                    var text = trusted_utf8(self.data[start_i + 1 : j])
                    self.i = j + 1
                    return text^
                if c < 32 or c == 127:
                    break
                j += 1
            self.i = start_i
        var buf = List[Byte]()
        if multiline:
            self.i += 3
            if self.is_nl_at(self.i):
                self.skip_nl()
            while True:
                if self.eof():
                    self.err(DecodeError.KIND_SYNTAX)
                if self.peek() == 39 and self.peek_at(1) == 39 and self.peek_at(2) == 39:
                    self.i += 3
                    break
                self.append_literal_char(buf, True)
            self.take_extra_quotes(buf, 39)
        else:
            self.i += 1
            while True:
                if self.eof():
                    self.err(DecodeError.KIND_SYNTAX)
                if self.peek() == 39:
                    self.i += 1
                    break
                self.append_literal_char(buf, False)
        return bytes_to_string(buf^, self.i)

    def append_literal_char(mut self, mut buf: List[Byte], multiline: Bool) raises DecodeError:
        var c = self.peek()
        if c == 13:
            if self.peek_at(1) != 10:
                self.err(DecodeError.KIND_SYNTAX)
            if not multiline:
                self.err(DecodeError.KIND_SYNTAX)
            buf.append(Byte(10))
            self.i += 2
            return
        if c == 10:
            if not multiline:
                self.err(DecodeError.KIND_SYNTAX)
            buf.append(Byte(10))
            self.i += 1
            return
        if c < 32 or c == 127:
            if c != 9:
                self.err(DecodeError.KIND_SYNTAX)
        if c < 128:
            buf.append(Byte(c))
            self.i += 1
            return
        var cp = self.read_utf8()
        append_scalar(buf, cp, self.i)

    def parse_basic(mut self, multiline: Bool) raises DecodeError -> String:
        if not multiline:
            var start_i = self.i
            var j = self.i + 1
            while j < self.n:
                var c = Int(self.data[j])
                if c == 34:
                    var text = trusted_utf8(self.data[start_i + 1 : j])
                    self.i = j + 1
                    return text^
                if c == 92 or c < 32 or c == 127:
                    break
                j += 1
            self.i = start_i
        self.i += 1
        return self.parse_basic_body(multiline)

    def parse_basic_body(mut self, multiline: Bool) raises DecodeError -> String:
        var buf = List[Byte]()
        while True:
            if self.eof():
                self.err(DecodeError.KIND_SYNTAX)
            var c = self.peek()
            if c == 34:
                if not multiline:
                    self.i += 1
                    return bytes_to_string(buf^, self.i)
                if self.peek_at(1) == 34 and self.peek_at(2) == 34:
                    self.i += 3
                    return bytes_to_string(buf^, self.i)
                buf.append(Byte(34))
                self.i += 1
                continue
            if c == 92:
                self.parse_escape(buf, multiline)
                continue
            if c == 13:
                if self.peek_at(1) != 10 or not multiline:
                    self.err(DecodeError.KIND_SYNTAX)
                buf.append(Byte(10))
                self.i += 2
                continue
            if c == 10:
                if not multiline:
                    self.err(DecodeError.KIND_SYNTAX)
                buf.append(Byte(10))
                self.i += 1
                continue
            if (c < 32 or c == 127) and c != 9:
                self.err(DecodeError.KIND_SYNTAX)
            if c < 128:
                buf.append(Byte(c))
                self.i += 1
                continue
            var cp = self.read_utf8()
            append_scalar(buf, cp, self.i)

    def parse_multiline(mut self, literal: Bool) raises DecodeError -> String:
        if literal:
            return self.parse_literal(True)
        self.i += 3
        if self.is_nl_at(self.i):
            self.skip_nl()
        var text = self.parse_basic_body(True)
        var buf = List[Byte]()
        var raw = text.as_bytes()
        var k = 0
        while k < len(raw):
            buf.append(raw[k])
            k += 1
        self.take_extra_quotes(buf, 34)
        return bytes_to_string(buf^, self.i)

    def take_extra_quotes(mut self, mut buf: List[Byte], delim: Int):
        if self.peek() != delim:
            return
        self.i += 1
        buf.append(Byte(delim))
        if self.peek() != delim:
            return
        self.i += 1
        buf.append(Byte(delim))

    def parse_escape(mut self, mut buf: List[Byte], multiline: Bool) raises DecodeError:
        self.i += 1
        if self.eof():
            self.err(DecodeError.KIND_ESCAPE)
        var e = self.peek()
        if multiline and (e == 32 or e == 9 or e == 10 or e == 13):
            if e != 10 and e != 13:
                self.i += 1
                self.skip_ws()
                if not self.is_nl_at(self.i):
                    self.err(DecodeError.KIND_ESCAPE)
            if self.is_nl_at(self.i):
                self.skip_nl()
            while True:
                if self.is_ws(self.peek()):
                    self.i += 1
                    continue
                if self.is_nl_at(self.i):
                    self.skip_nl()
                    continue
                return
        self.i += 1
        if e == 98:
            buf.append(Byte(8))
        elif e == 116:
            buf.append(Byte(9))
        elif e == 110:
            buf.append(Byte(10))
        elif e == 102:
            buf.append(Byte(12))
        elif e == 114:
            buf.append(Byte(13))
        elif e == 101:
            buf.append(Byte(27))
        elif e == 34:
            buf.append(Byte(34))
        elif e == 92:
            buf.append(Byte(92))
        elif e == 120:
            append_scalar(buf, self.read_hex(2), self.i)
        elif e == 117:
            append_scalar(buf, self.read_hex(4), self.i)
        elif e == 85:
            append_scalar(buf, self.read_hex(8), self.i)
        else:
            self.err(DecodeError.KIND_ESCAPE)

    def read_hex(mut self, n: Int) raises DecodeError -> Int:
        var v = 0
        var k = 0
        while k < n:
            var d = self.hex_val(self.peek())
            if d < 0:
                self.err(DecodeError.KIND_ESCAPE)
            v = (v << 4) | d
            self.i += 1
            k += 1
        return v

    def read_utf8(mut self) raises DecodeError -> Int:
        var c = self.peek()
        self.i += 1
        var need = 0
        var cp = 0
        if c < 128:
            return c
        if (c & 0xE0) == 0xC0:
            need = 1
            cp = c & 0x1F
        elif (c & 0xF0) == 0xE0:
            need = 2
            cp = c & 0x0F
        elif (c & 0xF8) == 0xF0:
            need = 3
            cp = c & 0x07
        else:
            self.err(DecodeError.KIND_UTF8)
        var k = 0
        while k < need:
            var cc = self.peek()
            if (cc & 0xC0) != 0x80:
                self.err(DecodeError.KIND_UTF8)
            cp = (cp << 6) | (cc & 0x3F)
            self.i += 1
            k += 1
        return cp

    def parse_scalar(mut self, mut doc: TomlDoc) raises DecodeError -> Int:
        var fast = self.try_plain_int(doc)
        if fast >= 0:
            return fast
        if self.looks_like_datetime():
            var dt = self.parse_datetime()
            return doc.make_datetime(dt, -1)
        return self.parse_number(doc)

    def looks_like_datetime(self) -> Bool:
        if not self.is_digit(self.peek()):
            return False
        if (
            self.is_digit(self.peek_at(0))
            and self.is_digit(self.peek_at(1))
            and self.is_digit(self.peek_at(2))
            and self.is_digit(self.peek_at(3))
            and self.peek_at(4) == 45
        ):
            return True
        if self.is_digit(self.peek_at(0)) and self.is_digit(self.peek_at(1)) and self.peek_at(2) == 58:
            return True
        return False

    def read_n_digits(mut self, n: Int) raises DecodeError -> Int:
        var v = 0
        var k = 0
        while k < n:
            if not self.is_digit(self.peek()):
                self.err(DecodeError.KIND_SYNTAX)
            v = v * 10 + (self.peek() - 48)
            self.i += 1
            k += 1
        return v

    def valid_date(self, y: Int, m: Int, d: Int) -> Bool:
        if m < 1 or m > 12 or d < 1:
            return False
        var md = 31
        if m == 4 or m == 6 or m == 9 or m == 11:
            md = 30
        elif m == 2:
            var leap = (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)
            if leap:
                md = 29
            else:
                md = 28
        return d <= md

    def parse_datetime(mut self) raises DecodeError -> TomlDateTime:
        var dt = TomlDateTime()
        if self.peek_at(2) == 58:
            dt.sub = 4
            self.read_time(dt)
            return dt^
        dt.year = self.read_n_digits(4)
        self.expect(45)
        dt.month = self.read_n_digits(2)
        self.expect(45)
        dt.day = self.read_n_digits(2)
        if not self.valid_date(dt.year, dt.month, dt.day):
            self.err(DecodeError.KIND_RANGE)
        var c = self.peek()
        var timed = False
        if c == 84 or c == 116:
            timed = True
        elif c == 32 and self.is_digit(self.peek_at(1)):
            timed = True
        if not timed:
            dt.sub = 3
            return dt^
        self.i += 1
        self.read_time(dt)
        c = self.peek()
        if c == 90 or c == 122:
            self.i += 1
            dt.offset_z = True
            dt.sub = 1
            return dt^
        if c == 43 or c == 45:
            var sign = 1
            if c == 45:
                sign = -1
            self.i += 1
            var hh = self.read_n_digits(2)
            self.expect(58)
            var mm = self.read_n_digits(2)
            if hh > 23 or mm > 59:
                self.err(DecodeError.KIND_RANGE)
            dt.offset_minutes = sign * (hh * 60 + mm)
            dt.offset_z = False
            dt.sub = 1
            return dt^
        dt.sub = 2
        return dt^

    def read_time(mut self, mut dt: TomlDateTime) raises DecodeError:
        dt.hour = self.read_n_digits(2)
        self.expect(58)
        dt.minute = self.read_n_digits(2)
        dt.has_second = False
        dt.second = 0
        dt.nanos = 0
        if self.peek() == 58:
            self.i += 1
            dt.has_second = True
            dt.second = self.read_n_digits(2)
            if self.peek() == 46:
                self.i += 1
                if not self.is_digit(self.peek()):
                    self.err(DecodeError.KIND_SYNTAX)
                var digits = 0
                var nanos = 0
                while self.is_digit(self.peek()):
                    var d = self.peek() - 48
                    if digits < 9:
                        nanos = nanos * 10 + d
                    digits += 1
                    self.i += 1
                while digits < 9:
                    nanos = nanos * 10
                    digits += 1
                dt.nanos = nanos
        if dt.hour > 23 or dt.minute > 59 or dt.second > 59:
            self.err(DecodeError.KIND_RANGE)

    def _int_terminator(self) -> Bool:
        var c = self.peek()
        if c < 0:
            return True
        return (
            c == 32
            or c == 9
            or c == 10
            or c == 13
            or c == 44
            or c == 93
            or c == 125
            or c == 35
        )

    def try_plain_int(mut self, mut doc: TomlDoc) -> Int:
        """Node index of a plain decimal integer, or -1 when the token needs the general number parser."""
        var start = self.i
        var neg = False
        var c = self.peek()
        if c == 43:
            self.i += 1
        elif c == 45:
            neg = True
            self.i += 1
        elif not self.is_digit(c):
            return -1
        c = self.peek()
        if not self.is_digit(c):
            self.i = start
            return -1
        if c == 48:
            var n1 = self.peek_at(1)
            if (
                self.is_digit(n1)
                or n1 == 46
                or n1 == 69
                or n1 == 95
                or n1 == 98
                or n1 == 101
                or n1 == 111
                or n1 == 120
            ):
                self.i = start
                return -1
            self.i += 1
            if not self._int_terminator():
                self.i = start
                return -1
            return doc.make_int(Int64(0), -1)
        var acc = UInt64(0)
        var limit = UInt64(9223372036854775807)
        if neg:
            limit = limit + UInt64(1)
        while True:
            c = self.peek()
            if not self.is_digit(c):
                break
            var d = UInt64(c - 48)
            if acc > (limit - d) // UInt64(10):
                self.i = start
                return -1
            acc = acc * UInt64(10) + d
            self.i += 1
        c = self.peek()
        if c == 46 or c == 69 or c == 95 or c == 101:
            self.i = start
            return -1
        if not self._int_terminator():
            self.i = start
            return -1
        if neg:
            if acc == UInt64(9223372036854775808):
                return doc.make_int(Int64.MIN, -1)
            return doc.make_int(Int64(0) - Int64(acc), -1)
        return doc.make_int(Int64(acc), -1)

    def parse_number(mut self, mut doc: TomlDoc) raises DecodeError -> Int:
        var save = self.i
        if self.starts("inf") or self.starts("+inf") or self.starts("-inf") or self.starts("nan") or self.starts("+nan") or self.starts("-nan"):
            var neg = self.peek() == 45
            if self.peek() == 43 or self.peek() == 45:
                self.i += 1
            var nan = self.peek() == 110
            if nan:
                self.expect(110)
                self.expect(97)
                self.expect(110)
                _ = neg
                return doc.make_float(UInt64(0x7FF8000000000000), -1)
            self.expect(105)
            self.expect(110)
            self.expect(102)
            if neg:
                return doc.make_float(UInt64(0xFFF0000000000000), -1)
            return doc.make_float(UInt64(0x7FF0000000000000), -1)
        self.i = save
        var neg = False
        var saw_plus = False
        if self.peek() == 43:
            saw_plus = True
            self.i += 1
        elif self.peek() == 45:
            neg = True
            self.i += 1
        if self.peek() == 48 and (self.peek_at(1) == 120 or self.peek_at(1) == 111 or self.peek_at(1) == 98):
            if neg or saw_plus:
                self.err(DecodeError.KIND_SYNTAX)
            var basec = self.peek_at(1)
            self.i += 2
            var base = 16
            if basec == 111:
                base = 8
            elif basec == 98:
                base = 2
            var v = self.read_int_digits(base, False)
            return doc.make_int(v, -1)
        var is_float = False
        var clean = List[Byte]()
        if neg:
            clean.append(Byte(45))
        if not self.is_digit(self.peek()):
            self.err(DecodeError.KIND_SYNTAX)
        if self.peek() == 48:
            clean.append(Byte(48))
            self.i += 1
            if self.is_digit(self.peek()) or self.peek() == 95:
                self.err(DecodeError.KIND_SYNTAX)
        else:
            self.take_digits(clean, False)
        if self.peek() == 46:
            is_float = True
            clean.append(Byte(46))
            self.i += 1
            if not self.is_digit(self.peek()):
                self.err(DecodeError.KIND_SYNTAX)
            self.take_digits(clean, False)
        if self.peek() == 101 or self.peek() == 69:
            is_float = True
            clean.append(Byte(101))
            self.i += 1
            if self.peek() == 43 or self.peek() == 45:
                clean.append(Byte(self.peek()))
                self.i += 1
            if not self.is_digit(self.peek()):
                self.err(DecodeError.KIND_SYNTAX)
            self.take_digits(clean, True)
        var lit = bytes_to_string(clean^, self.i)
        if not is_float:
            var v = self.int_from_literal(lit, neg)
            return doc.make_int(v, -1)
        try:
            var f = Float64(lit)
            return doc.make_float(UInt64(f.to_bits()), -1)
        except _:
            self.err(DecodeError.KIND_RANGE)
            return -1

    def take_digits(mut self, mut clean: List[Byte], allow_leading_zero: Bool) raises DecodeError:
        _ = allow_leading_zero
        var prev_us = True
        var any = False
        while True:
            var c = self.peek()
            if self.is_digit(c):
                clean.append(Byte(c))
                self.i += 1
                prev_us = False
                any = True
                continue
            if c == 95:
                if prev_us:
                    self.err(DecodeError.KIND_SYNTAX)
                self.i += 1
                prev_us = True
                continue
            break
        if not any or prev_us:
            self.err(DecodeError.KIND_SYNTAX)

    def read_int_digits(mut self, base: Int, neg: Bool) raises DecodeError -> Int64:
        var acc = UInt64(0)
        var limit = UInt64(9223372036854775807)
        if neg:
            limit = limit + UInt64(1)
        var prev_us = True
        var any = False
        while True:
            var c = self.peek()
            var d = -1
            if base == 16:
                d = self.hex_val(c)
            elif self.is_digit(c):
                d = c - 48
                if d >= base:
                    d = -1
            if d >= 0:
                if acc > (limit - UInt64(d)) // UInt64(base):
                    self.err(DecodeError.KIND_RANGE)
                acc = acc * UInt64(base) + UInt64(d)
                self.i += 1
                prev_us = False
                any = True
                continue
            if c == 95:
                if prev_us:
                    self.err(DecodeError.KIND_SYNTAX)
                self.i += 1
                prev_us = True
                continue
            break
        if not any or prev_us:
            self.err(DecodeError.KIND_SYNTAX)
        if neg:
            if acc == UInt64(9223372036854775808):
                return Int64.MIN
            return Int64(0) - Int64(acc)
        return Int64(acc)

    def int_from_literal(mut self, lit: String, neg: Bool) raises DecodeError -> Int64:
        var b = lit.as_bytes()
        var k = 0
        if len(b) > 0 and (Int(b[0]) == 43 or Int(b[0]) == 45):
            k = 1
        var acc = UInt64(0)
        var limit = UInt64(9223372036854775807)
        if neg:
            limit = limit + UInt64(1)
        if k >= len(b):
            self.err(DecodeError.KIND_SYNTAX)
        while k < len(b):
            var d = Int(b[k]) - 48
            if acc > (limit - UInt64(d)) // UInt64(10):
                self.err(DecodeError.KIND_RANGE)
            acc = acc * UInt64(10) + UInt64(d)
            k += 1
        if neg:
            if acc == UInt64(9223372036854775808):
                return Int64.MIN
            return Int64(0) - Int64(acc)
        return Int64(acc)
