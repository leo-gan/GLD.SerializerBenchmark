from std.collections import List, Optional, Span

from yaml_runtime.error import DecodeError
from yaml_runtime.options import DecodeOptions
from yaml_wire.indent import IndentStack
from yaml_wire.number import hex_val, is_digit
from yaml_wire.scalar import parse_double_quoted, parse_single_quoted
from yaml_wire.simdscan import scan_comment_or_break, scan_plain_stop
from yaml_wire.utf8 import string_from_utf8


comptime CTX_BLOCK = 0
comptime CTX_FLOW = 1
comptime VAL_INLINE = 0
comptime VAL_NESTED = 1
comptime VAL_EMPTY = 2
comptime TAG_NONE = 0
comptime TAG_NULL = 1
comptime TAG_BOOL = 2
comptime TAG_INT = 3
comptime TAG_FLOAT = 4
comptime TAG_STR = 5
comptime TAG_SEQ = 6
comptime TAG_MAP = 7
comptime TAG_BINARY = 8
comptime TAG_NONSPEC = 9


struct MapState(Copyable, ImplicitlyCopyable):
    var ctx: Int
    var indent: Int

    def __init__(out self, ctx: Int = 0, indent: Int = 0):
        self.ctx = ctx
        self.indent = indent


struct SeqState(Copyable, ImplicitlyCopyable):
    var ctx: Int
    var indent: Int

    def __init__(out self, ctx: Int = 0, indent: Int = 0):
        self.ctx = ctx
        self.indent = indent


struct WireReader[origin: ImmOrigin](Movable):
    var data: Span[Byte, Self.origin]
    var pos: Int
    var depth: Int
    var options: DecodeOptions
    var indents: IndentStack
    var line_start: Int
    var at_line_start: Bool
    var last_tag: Int
    var last_anchor: String
    var anchor_names: List[String]
    var anchor_starts: List[Int]
    var anchor_nodes: List[Int]
    var expand_stack: List[Int]

    def __init__(
        out self,
        data: Span[Byte, Self.origin],
        *,
        options: DecodeOptions = DecodeOptions.default,
        depth: Int = 0,
    ):
        self.data = data
        self.pos = 0
        self.depth = depth
        self.options = options
        self.indents = IndentStack()
        self.line_start = 0
        self.at_line_start = True
        self.last_tag = TAG_NONE
        self.last_anchor = String()
        self.anchor_names = List[String]()
        self.anchor_starts = List[Int]()
        self.anchor_nodes = List[Int]()
        self.expand_stack = List[Int]()
        if len(data) >= 3:
            if Int(data[0]) == 0xEF and Int(data[1]) == 0xBB and Int(data[2]) == 0xBF:
                self.pos = 3
                self.line_start = 3

    def remaining(self) -> Int:
        return len(self.data) - self.pos

    def position(self) -> Int:
        return self.pos

    def _at_end(self) -> Bool:
        return self.pos >= len(self.data)

    def _cur(self) -> Int:
        if self.pos >= len(self.data):
            return -1
        return Int(self.data[self.pos])

    def _eat_break(mut self):
        if self.pos >= len(self.data):
            return
        if Int(self.data[self.pos]) == 13:
            self.pos += 1
            if self.pos < len(self.data) and Int(self.data[self.pos]) == 10:
                self.pos += 1
        elif Int(self.data[self.pos]) == 10:
            self.pos += 1
        self.line_start = self.pos
        self.at_line_start = True

    def skip_separation(mut self) raises DecodeError:
        if self.pos < len(self.data) and not self.at_line_start:
            var c0 = Int(self.data[self.pos])
            if c0 != 32 and c0 != 9 and c0 != 35 and c0 != 10 and c0 != 13:
                return
        while self.pos < len(self.data):
            if self.at_line_start:
                var i = self.pos
                while i < len(self.data):
                    var c = Int(self.data[i])
                    if c == 32:
                        i += 1
                        continue
                    if c == 9:
                        var j = i
                        while j < len(self.data):
                            var d = Int(self.data[j])
                            if d == 32 or d == 9:
                                j += 1
                                continue
                            if d == 10 or d == 13 or d == 35 or j == len(self.data):
                                break
                            raise DecodeError(DecodeError.KIND_INDENT, i)
                        i = j
                        continue
                    break
                if i >= len(self.data):
                    self.pos = i
                    return
                var n = Int(self.data[i])
                if n == 35:
                    self.pos = i
                    self._skip_to_break()
                    self._eat_break()
                    continue
                if n == 10 or n == 13:
                    self.pos = i
                    self._eat_break()
                    continue
                return
            var c = self._cur()
            if c == 32 or c == 9:
                self.pos += 1
                continue
            if c == 35:
                self._skip_to_break()
                continue
            if c == 10 or c == 13:
                self._eat_break()
                continue
            return

    def _skip_to_break(mut self):
        var n = scan_comment_or_break(self.data, self.pos)
        while n < len(self.data) and Int(self.data[n]) == 35:
            n = scan_comment_or_break(self.data, n + 1)
        if n < len(self.data) and (Int(self.data[n]) == 10 or Int(self.data[n]) == 13):
            self.pos = n
        else:
            self.pos = len(self.data)

    def line_indent(self) -> Int:
        var i = self.line_start
        var n = 0
        while i < len(self.data):
            var c = Int(self.data[i])
            if c == 32:
                n += 1
                i += 1
                continue
            break
        return n

    def at_dedent(self) raises DecodeError -> Bool:
        if self.pos >= len(self.data):
            return True
        if self._is_doc_mark():
            return True
        return False

    def at_document_end(self) raises DecodeError -> Bool:
        if self.pos >= len(self.data):
            return True
        return self._is_doc_mark()

    def _is_doc_mark(self) -> Bool:
        if not self.at_line_start:
            return False
        if self.line_indent() != 0:
            return False
        if self.pos + 3 > len(self.data):
            return False
        var a = Int(self.data[self.pos])
        var b = Int(self.data[self.pos + 1])
        var c = Int(self.data[self.pos + 2])
        if not ((a == 45 and b == 45 and c == 45) or (a == 46 and b == 46 and c == 46)):
            return False
        if self.pos + 3 == len(self.data):
            return True
        var d = Int(self.data[self.pos + 3])
        return d == 10 or d == 13 or d == 32 or d == 9 or d == 35

    def consume_props(mut self) raises DecodeError:
        self.last_tag = TAG_NONE
        self.last_anchor = String()
        var c0 = self._cur()
        if c0 != 38 and c0 != 33:
            return
        var i = 0
        while i < 2:
            self._skip_inline_ws()
            var c = self._cur()
            if c == 38:
                self._read_anchor()
                i += 1
                continue
            if c == 33:
                self._read_tag()
                i += 1
                continue
            break
        self._skip_inline_ws()

    def _skip_inline_ws(mut self):
        while self.pos < len(self.data):
            var c = Int(self.data[self.pos])
            if c == 32 or c == 9:
                self.pos += 1
                self.at_line_start = False
                continue
            break

    def _read_anchor(mut self) raises DecodeError:
        self.pos += 1
        self.at_line_start = False
        var start = self.pos
        while self.pos < len(self.data):
            var c = Int(self.data[self.pos])
            if _is_anchor_char(c):
                self.pos += 1
                continue
            break
        if self.pos == start:
            raise DecodeError(DecodeError.KIND_SYNTAX, start)
        if self.pos - start > 256:
            raise DecodeError(DecodeError.KIND_RANGE, start)
        var name = string_from_utf8(self.data[start : self.pos], start)
        var k = 0
        while k < len(self.anchor_names):
            if self.anchor_names[k] == name:
                raise DecodeError(DecodeError.KIND_ALIAS, start)
            k += 1
        self.last_anchor = name
        self.anchor_names.append(name)
        self.anchor_starts.append(self.pos)
        self.anchor_nodes.append(-1)

    def _read_tag(mut self) raises DecodeError:
        self.pos += 1
        self.at_line_start = False
        if self._cur() == 33:
            self.pos += 1
            var start = self.pos
            while self.pos < len(self.data) and _is_tag_char(Int(self.data[self.pos])):
                self.pos += 1
            var name = string_from_utf8(self.data[start : self.pos], start)
            self.last_tag = _core_tag(name)
            if self.last_tag == TAG_NONE:
                raise DecodeError(DecodeError.KIND_TAG, start)
            return
        if self._cur() == 60:
            raise DecodeError(DecodeError.KIND_TAG, self.pos)
        if self.pos < len(self.data) and _is_tag_char(self._cur()):
            raise DecodeError(DecodeError.KIND_TAG, self.pos)
        self.last_tag = TAG_NONSPEC

    def take_alias(mut self) raises DecodeError -> Optional[Int]:
        if len(self.anchor_names) == 0:
            if self.pos < len(self.data) and Int(self.data[self.pos]) != 42:
                return Optional[Int]()
        self.skip_separation()
        self._skip_inline_ws()
        if self._cur() != 42:
            return Optional[Int]()
        self.pos += 1
        self.at_line_start = False
        var start = self.pos
        while self.pos < len(self.data) and _is_anchor_char(Int(self.data[self.pos])):
            self.pos += 1
        if self.pos == start:
            raise DecodeError(DecodeError.KIND_SYNTAX, start)
        var name = string_from_utf8(self.data[start : self.pos], start)
        var i = 0
        while i < len(self.anchor_names):
            if self.anchor_names[i] == name:
                var tgt = self.anchor_starts[i]
                var k = 0
                while k < len(self.expand_stack):
                    if self.expand_stack[k] == tgt:
                        raise DecodeError(DecodeError.KIND_ALIAS, start)
                    k += 1
                self.expand_stack.append(tgt)
                var saved = self.pos
                self.pos = tgt
                self.at_line_start = False
                return Optional[Int](saved)
            i += 1
        raise DecodeError(DecodeError.KIND_ALIAS, start)

    def end_alias(mut self, saved: Int):
        if len(self.expand_stack) > 0:
            _ = self.expand_stack.pop()
        self.pos = saved
        self.at_line_start = False

    def begin_map(mut self) raises DecodeError -> MapState:
        self._enter()
        self.skip_separation()
        var saved = self.take_alias()
        if saved:
            self.end_alias(saved.value())
        self.consume_props()
        if self._cur() == 123:
            self.pos += 1
            self.at_line_start = False
            return MapState(CTX_FLOW, 0)
        if self.at_line_start:
            self.pos = self.line_start + self.line_indent()
        return MapState(CTX_BLOCK, self.pos - self.line_start)

    def next_key(mut self, state: MapState) raises DecodeError -> Bool:
        if state.ctx == CTX_BLOCK and not self.at_line_start and not self._at_end():
            var c = self._cur()
            if c != 10 and c != 13 and c != 35:
                return True
        self.skip_separation()
        if state.ctx == CTX_FLOW:
            self._skip_inline_ws()
            if self._cur() == 125:
                self.pos += 1
                self.at_line_start = False
                return False
            if self._cur() == 44:
                self.pos += 1
                self.at_line_start = False
                self.skip_separation()
                self._skip_inline_ws()
            if self._cur() == 125:
                self.pos += 1
                self.at_line_start = False
                return False
            if self._at_end():
                raise DecodeError(DecodeError.KIND_EOF, self.pos)
            return True
        if self._at_end() or self._is_doc_mark():
            return False
        if not self.at_line_start:
            var c = self._cur()
            if c != 10 and c != 13 and c != 35 and c >= 0:
                return True
            self.skip_separation()
            if self._at_end() or self._is_doc_mark():
                return False
        var col = self.line_indent()
        if self._cur() == 45 and col < state.indent:
            return False
        if col < state.indent:
            return False
        if col > state.indent:
            raise DecodeError(DecodeError.KIND_INDENT, self.pos)
        self.pos = self.line_start + col
        return True

    def try_key[o: ImmOrigin](mut self, lit: Span[Byte, o]) -> Bool:
        var start = self.pos
        if self.at_line_start:
            start = self.line_start + self.line_indent()
        if start + len(lit) + 1 <= len(self.data):
            var i = 0
            var ok = True
            while i < len(lit):
                if Int(self.data[start + i]) != Int(lit[i]):
                    ok = False
                    break
                i += 1
            if ok and Int(self.data[start + len(lit)]) == 58:
                self.pos = start + len(lit) + 1
                self.at_line_start = False
                self._skip_inline_ws()
                return True
        var saved = self.pos
        var saved_ls = self.line_start
        var saved_als = self.at_line_start
        try:
            self.skip_separation()
        except _:
            self.pos = saved
            self.line_start = saved_ls
            self.at_line_start = saved_als
            return False
        start = self.pos
        if self.at_line_start:
            start = self.line_start + self.line_indent()
            self.pos = start
        if start + len(lit) > len(self.data):
            self.pos = saved
            self.line_start = saved_ls
            self.at_line_start = saved_als
            return False
        var i = 0
        while i < len(lit):
            if Int(self.data[start + i]) != Int(lit[i]):
                self.pos = saved
                self.line_start = saved_ls
                self.at_line_start = saved_als
                return False
            i += 1
        var after = start + len(lit)
        if after >= len(self.data):
            self.pos = saved
            return False
        var c = Int(self.data[after])
        if c != 58:
            self.pos = saved
            self.line_start = saved_ls
            self.at_line_start = saved_als
            return False
        self.pos = after + 1
        self.at_line_start = False
        self._skip_inline_ws()
        return True

    def skip_pair(mut self) raises DecodeError:
        self._skip_key()
        self._expect_colon()
        self.skip_value()

    def end_map(mut self, state: MapState) raises DecodeError:
        if state.ctx == CTX_FLOW:
            self.skip_separation()
            if self._cur() == 125:
                self.pos += 1
                self.at_line_start = False
        self._leave()

    def begin_seq(mut self) raises DecodeError -> SeqState:
        self._enter()
        self.skip_separation()
        var saved = self.take_alias()
        if saved:
            self.end_alias(saved.value())
        self.consume_props()
        if self._cur() == 91:
            self.pos += 1
            self.at_line_start = False
            return SeqState(CTX_FLOW, 0)
        if self.at_line_start:
            self.pos = self.line_start + self.line_indent()
        return SeqState(CTX_BLOCK, self.pos - self.line_start)

    def next_item(mut self, state: SeqState) raises DecodeError -> Bool:
        self.skip_separation()
        if state.ctx == CTX_FLOW:
            self._skip_inline_ws()
            if self._cur() == 93:
                self.pos += 1
                self.at_line_start = False
                return False
            if self._cur() == 44:
                self.pos += 1
                self.at_line_start = False
                self.skip_separation()
                self._skip_inline_ws()
            if self._cur() == 93:
                self.pos += 1
                self.at_line_start = False
                return False
            if self._at_end():
                raise DecodeError(DecodeError.KIND_EOF, self.pos)
            return True
        if self._at_end() or self._is_doc_mark():
            return False
        var col = self.line_indent()
        if col < state.indent:
            return False
        if self.pos < len(self.data) and Int(self.data[self.pos]) != 45 and col == state.indent:
            if self._cur() != 45:
                if col == state.indent and self._cur() != 45:
                    return False
        self.pos = self.line_start + state.indent
        if self._cur() != 45:
            if col > state.indent:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
            return False
        self.pos += 1
        self.at_line_start = False
        if self._cur() == 32 or self._cur() == 9:
            self.pos += 1
        return True

    def end_seq(mut self, state: SeqState) raises DecodeError:
        if state.ctx == CTX_FLOW:
            self.skip_separation()
            if self._cur() == 93:
                self.pos += 1
                self.at_line_start = False
        self._leave()

    def after_colon(mut self) raises DecodeError -> Int:
        self._skip_inline_ws()
        var c = self._cur()
        if c == 10 or c == 13 or c < 0 or c == 35:
            var saved = self.pos
            var saved_ls = self.line_start
            var saved_als = self.at_line_start
            self.skip_separation()
            if self._at_end() or self._is_doc_mark():
                self.pos = saved
                self.line_start = saved_ls
                self.at_line_start = saved_als
                return VAL_EMPTY
            var col = self.line_indent()
            var key_col = 0
            if saved_ls <= saved:
                var i = saved_ls
                while i < saved and Int(self.data[i]) == 32:
                    key_col += 1
                    i += 1
            if col > key_col:
                return VAL_NESTED
            self.pos = saved
            self.line_start = saved_ls
            self.at_line_start = saved_als
            return VAL_EMPTY
        return VAL_INLINE

    def peek(mut self) raises DecodeError -> Int:
        self.skip_separation()
        if self._at_end():
            raise DecodeError(DecodeError.KIND_EOF, self.pos)
        return self._cur()

    def read_null(mut self) raises DecodeError:
        var s = self._read_plain_or_quoted()
        if not _is_null_word(s):
            raise DecodeError(DecodeError.KIND_TYPE, self.position())

    def read_bool(mut self) raises DecodeError -> Bool:
        var saved = self.take_alias()
        if self.at_line_start:
            self.skip_separation()
        self.consume_props()
        var c = self._cur()
        if c == 116 and self._match("true"):
            self.at_line_start = False
            if saved:
                self.end_alias(saved.value())
            return True
        if c == 102 and self._match("false"):
            self.at_line_start = False
            if saved:
                self.end_alias(saved.value())
            return False
        var s2 = self._read_plain_or_quoted()
        if saved:
            self.end_alias(saved.value())
        if _is_true_word(s2):
            return True
        if _is_false_word(s2):
            return False
        raise DecodeError(DecodeError.KIND_TYPE, self.position())

    def read_int(mut self) raises DecodeError -> Int64:
        var saved = self.take_alias()
        if self.at_line_start:
            self.skip_separation()
        self.consume_props()
        var c = self._cur()
        if c == 34 or c == 39 or c == 124 or c == 62:
            var s = self._read_plain_or_quoted()
            if saved:
                self.end_alias(saved.value())
            return _parse_core_int(s, self.position())
        var start = self.pos
        var neg = False
        if c == 45:
            neg = True
            self.pos += 1
            c = self._cur()
        elif c == 43:
            self.pos += 1
            c = self._cur()
        if not is_digit(c):
            self.pos = start
            var s = self._read_plain()
            if saved:
                self.end_alias(saved.value())
            return _parse_core_int(s, start)
        var acc = Int64(0)
        while is_digit(self._cur()):
            acc = acc * Int64(10) + Int64(self._cur() - 48)
            self.pos += 1
        self.at_line_start = False
        if saved:
            self.end_alias(saved.value())
        if neg:
            return -acc
        return acc

    def read_float(mut self) raises DecodeError -> Float64:
        return self.read_as_f64()

    def read_as_f64(mut self) raises DecodeError -> Float64:
        var saved = self.take_alias()
        if self.at_line_start:
            self.skip_separation()
        self.consume_props()
        var c = self._cur()
        if is_digit(c) or c == 45 or c == 43 or c == 46:
            var start = self.pos
            var s = self._read_plain()
            if saved:
                self.end_alias(saved.value())
            try:
                return _parse_core_float(s, start)
            except _:
                return Float64(_parse_core_int(s, start))
        var s2 = self._read_plain_or_quoted()
        if saved:
            self.end_alias(saved.value())
        try:
            return _parse_core_float(s2, self.position())
        except _:
            pass
        try:
            return Float64(_parse_core_int(s2, self.position()))
        except _:
            raise DecodeError(DecodeError.KIND_TYPE, self.position())

    def read_string(mut self) raises DecodeError -> String:
        var saved = self.take_alias()
        var s = self._read_plain_or_quoted()
        if saved:
            self.end_alias(saved.value())
        return s^

    def read_binary(mut self) raises DecodeError -> List[Byte]:
        var saved = self.take_alias()
        self.skip_separation()
        self.consume_props()
        var s = self._read_plain_or_quoted()
        if saved:
            self.end_alias(saved.value())
        return _decode_b64(s, self.position())

    def skip_value(mut self) raises DecodeError:
        self.skip_separation()
        var saved = self.take_alias()
        if saved:
            self.end_alias(saved.value())
            return
        self.consume_props()
        var c = self._cur()
        if c == 123:
            var st = self.begin_map()
            while self.next_key(st):
                self.skip_pair()
            self.end_map(st)
            return
        if c == 91:
            var st = self.begin_seq()
            while self.next_item(st):
                self.skip_value()
            self.end_seq(st)
            return
        if c == 124 or c == 62:
            _ = self._read_block_scalar()
            return
        if c == 34 or c == 39:
            _ = self._read_plain_or_quoted()
            return
        if c == 45 and self._dash_is_seq():
            var st = self.begin_seq()
            while self.next_item(st):
                self.skip_value()
            self.end_seq(st)
            return
        if self._looks_like_map():
            var st = self.begin_map()
            while self.next_key(st):
                self.skip_pair()
            self.end_map(st)
            return
        _ = self._read_plain_or_quoted()

    def peek_is_null(mut self) raises DecodeError -> Bool:
        var saved = self.pos
        var saved_ls = self.line_start
        var saved_als = self.at_line_start
        self.skip_separation()
        var is_null = False
        try:
            var s = self._peek_plain_word()
            is_null = _is_null_word(s)
        except _:
            is_null = False
        self.pos = saved
        self.line_start = saved_ls
        self.at_line_start = saved_als
        return is_null

    def peek_is_map(mut self) raises DecodeError -> Bool:
        var saved = self.pos
        var saved_ls = self.line_start
        var saved_als = self.at_line_start
        self.skip_separation()
        self.consume_props()
        var c = self._cur()
        var ok = c == 123 or self._looks_like_map()
        self.pos = saved
        self.line_start = saved_ls
        self.at_line_start = saved_als
        return ok

    def peek_is_seq(mut self) raises DecodeError -> Bool:
        var saved = self.pos
        var saved_ls = self.line_start
        var saved_als = self.at_line_start
        self.skip_separation()
        self.consume_props()
        var c = self._cur()
        var ok = c == 91 or self._dash_is_seq()
        self.pos = saved
        self.line_start = saved_ls
        self.at_line_start = saved_als
        return ok

    def skip_document_start(mut self) raises DecodeError:
        self.skip_separation()
        while self.pos < len(self.data) and self.at_line_start and self.line_indent() == 0:
            if self._cur() == 37:
                self._directive()
                self.skip_separation()
                continue
            if self._is_doc_mark() and self._cur() == 45:
                self.pos += 3
                self.at_line_start = False
                self.skip_separation()
                continue
            break

    def expect_colon(mut self) raises DecodeError:
        self._expect_colon()

    def looks_map(self) -> Bool:
        if self._dash_is_seq():
            return False
        return self._cur() == 123 or self._looks_like_map()

    def looks_seq(self) -> Bool:
        return self._cur() == 91 or self._dash_is_seq()

    def skip_document_end(mut self) raises DecodeError:
        self.skip_separation()
        if self._is_doc_mark() and self._cur() == 46:
            self.pos += 3
            self.at_line_start = False

    def _directive(mut self) raises DecodeError:
        var start = self.pos
        self.pos += 1
        if self._match("YAML"):
            self._skip_inline_ws()
            if not self._match("1.2"):
                raise DecodeError(DecodeError.KIND_SYNTAX, start)
            self._skip_to_break()
            self._eat_break()
            return
        if self._match("TAG"):
            raise DecodeError(DecodeError.KIND_TAG, start)
        raise DecodeError(DecodeError.KIND_SYNTAX, start)

    def _match(mut self, lit: String) -> Bool:
        var b = lit.as_bytes()
        if self.pos + len(b) > len(self.data):
            return False
        var i = 0
        while i < len(b):
            if Int(self.data[self.pos + i]) != Int(b[i]):
                return False
            i += 1
        self.pos += len(b)
        return True

    def _enter(mut self) raises DecodeError:
        if self.depth >= self.options.max_depth:
            raise DecodeError(DecodeError.KIND_DEPTH, self.pos)
        self.depth += 1

    def _leave(mut self):
        if self.depth > 0:
            self.depth -= 1

    def _expect_colon(mut self) raises DecodeError:
        self._skip_inline_ws()
        if self._cur() != 58:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.pos)
        self.pos += 1
        self.at_line_start = False
        self._skip_inline_ws()

    def _skip_key(mut self) raises DecodeError:
        self.skip_separation()
        if self._cur() == 63:
            self.pos += 1
            self.at_line_start = False
            self.skip_value()
            return
        _ = self._read_plain_or_quoted()

    def _dash_is_seq(self) -> Bool:
        if self._cur() != 45:
            return False
        if self.pos + 1 >= len(self.data):
            return True
        var n = Int(self.data[self.pos + 1])
        return n == 32 or n == 9 or n == 10 or n == 13

    def _looks_like_map(self) -> Bool:
        if self._cur() == 63:
            return True
        var i = self.pos
        var in_q = 0
        while i < len(self.data):
            var c = Int(self.data[i])
            if in_q == 34:
                if c == 92:
                    i += 2
                    continue
                if c == 34:
                    in_q = 0
                i += 1
                continue
            if in_q == 39:
                if c == 39:
                    in_q = 0
                i += 1
                continue
            if c == 34 or c == 39:
                in_q = c
                i += 1
                continue
            if c == 10 or c == 13:
                return False
            if c == 58:
                if i + 1 >= len(self.data):
                    return True
                var n = Int(self.data[i + 1])
                if n == 32 or n == 9 or n == 10 or n == 13 or n == 35:
                    return True
            i += 1
        return False

    def _peek_plain_word(mut self) raises DecodeError -> String:
        var start = self.pos
        var stop = scan_plain_stop(self.data, self.pos)
        var end = stop
        while end > start:
            var c = Int(self.data[end - 1])
            if c == 32 or c == 9:
                end -= 1
                continue
            break
        return string_from_utf8(self.data[start:end], start)

    def _read_plain_or_quoted(mut self) raises DecodeError -> String:
        if self.at_line_start or (
            self.pos < len(self.data)
            and (
                Int(self.data[self.pos]) == 32
                or Int(self.data[self.pos]) == 35
                or Int(self.data[self.pos]) == 10
            )
        ):
            self.skip_separation()
        self.consume_props()
        var c = self._cur()
        if c == 34:
            self.at_line_start = False
            return parse_double_quoted(self.data, self.pos)
        if c == 39:
            self.at_line_start = False
            return parse_single_quoted(self.data, self.pos)
        if c == 124 or c == 62:
            return self._read_block_scalar()
        return self._read_plain()

    def _read_plain(mut self) raises DecodeError -> String:
        var start = self.pos
        if self._at_end():
            return String()
        var min_indent = self.line_indent()
        var out = List[Byte]()
        var first = True
        var blanks = 0
        while self.pos < len(self.data):
            if not first:
                self.skip_separation()
                if self._at_end() or self._is_doc_mark():
                    break
                var col = self.line_indent()
                if col <= min_indent:
                    break
                if self._looks_like_map() or self._dash_is_seq():
                    break
                if blanks == 0:
                    out.append(Byte(32))
                else:
                    var b = 0
                    while b < blanks:
                        out.append(Byte(10))
                        b += 1
                blanks = 0
            var line_end = scan_plain_stop(self.data, self.pos)
            if line_end < len(self.data) and Int(self.data[line_end]) == 35:
                var j = line_end
                if j > self.pos and Int(self.data[j - 1]) == 32:
                    line_end = j
                else:
                    line_end = scan_plain_stop(self.data, line_end + 1)
            var end = line_end
            while end > self.pos:
                var ch = Int(self.data[end - 1])
                if ch == 32 or ch == 9:
                    end -= 1
                    continue
                break
            var k = self.pos
            var stop_colon = False
            while k < end:
                var ch = Int(self.data[k])
                if ch == 58:
                    var nxt = -1
                    if k + 1 < len(self.data):
                        nxt = Int(self.data[k + 1])
                    if nxt < 0 or nxt == 32 or nxt == 9 or nxt == 10 or nxt == 13 or nxt == 35:
                        if first and len(out) == 0:
                            raise DecodeError(DecodeError.KIND_SYNTAX, k)
                        stop_colon = True
                        break
                out.append(self.data[k])
                k += 1
            if stop_colon:
                self.pos = k
                self.at_line_start = False
                break
            self.pos = line_end
            if self.pos < len(self.data) and (
                Int(self.data[self.pos]) == 10 or Int(self.data[self.pos]) == 13
            ):
                self._eat_break()
                first = False
                continue
            break
        if len(out) == 0:
            return String()
        return string_from_utf8(Span(out), start)

    def _read_block_scalar(mut self) raises DecodeError -> String:
        var folded = self._cur() == 62
        self.pos += 1
        self.at_line_start = False
        var chomp = 0
        var indent_ind = -1
        while self.pos < len(self.data):
            var c = self._cur()
            if c == 43:
                chomp = 1
                self.pos += 1
            elif c == 45:
                chomp = -1
                self.pos += 1
            elif c >= 49 and c <= 57:
                indent_ind = c - 48
                self.pos += 1
            else:
                break
        self._skip_to_break()
        if self.pos < len(self.data) and (
            Int(self.data[self.pos]) == 10 or Int(self.data[self.pos]) == 13
        ):
            self._eat_break()
        var parent = self.line_indent()
        var content_indent = indent_ind
        if content_indent < 0:
            content_indent = -1
        var lines = List[String]()
        while self.pos < len(self.data):
            if self._is_doc_mark():
                break
            var col = 0
            var i = self.pos
            while i < len(self.data) and Int(self.data[i]) == 32:
                col += 1
                i += 1
            if i < len(self.data) and Int(self.data[i]) == 9 and col == 0:
                raise DecodeError(DecodeError.KIND_INDENT, i)
            if i >= len(self.data) or Int(self.data[i]) == 10 or Int(self.data[i]) == 13:
                lines.append(String())
                self.pos = i
                if self.pos < len(self.data):
                    self._eat_break()
                continue
            if content_indent < 0:
                if col <= parent:
                    break
                content_indent = col
            if col < content_indent:
                break
            self.pos = i
            var extra = col - content_indent
            var end = scan_comment_or_break(self.data, self.pos)
            if end < len(self.data) and Int(self.data[end]) == 35:
                end = len(self.data)
                var j = self.pos
                while j < len(self.data):
                    if Int(self.data[j]) == 10 or Int(self.data[j]) == 13:
                        end = j
                        break
                    j += 1
            var piece = string_from_utf8(self.data[self.pos:end], self.pos)
            var prefix = String()
            var p = 0
            while p < extra:
                prefix += " "
                p += 1
            lines.append(prefix + piece)
            self.pos = end
            if self.pos < len(self.data) and (
                Int(self.data[self.pos]) == 10 or Int(self.data[self.pos]) == 13
            ):
                self._eat_break()
        return _join_block(lines, folded, chomp)


def _is_anchor_char(c: Int) -> Bool:
    if c <= 32:
        return False
    if c == 91 or c == 93 or c == 123 or c == 125 or c == 44:
        return False
    return True


def _is_tag_char(c: Int) -> Bool:
    if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
        return True
    return c == 45 or c == 95


def _core_tag(name: String) -> Int:
    if name == "null":
        return TAG_NULL
    if name == "bool":
        return TAG_BOOL
    if name == "int":
        return TAG_INT
    if name == "float":
        return TAG_FLOAT
    if name == "str":
        return TAG_STR
    if name == "seq":
        return TAG_SEQ
    if name == "map":
        return TAG_MAP
    if name == "binary":
        return TAG_BINARY
    return TAG_NONE


def _is_null_word(s: String) -> Bool:
    return s == "null" or s == "Null" or s == "NULL" or s == "~" or s.byte_length() == 0


def _is_true_word(s: String) -> Bool:
    return s == "true" or s == "True" or s == "TRUE"


def _is_false_word(s: String) -> Bool:
    return s == "false" or s == "False" or s == "FALSE"


def _parse_core_int(s: String, offset: Int) raises DecodeError -> Int64:
    var b = s.as_bytes()
    var n = len(b)
    if n == 0:
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    var i = 0
    var neg = False
    var c0 = Int(b[0])
    if c0 == 43:
        i = 1
    elif c0 == 45:
        neg = True
        i = 1
    if i >= n:
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    if i + 1 < n and Int(b[i]) == 48 and Int(b[i + 1]) == 120:
        return _parse_hex(b, i + 2, neg, offset)
    if i + 1 < n and Int(b[i]) == 48 and Int(b[i + 1]) == 111:
        return _parse_oct(b, i + 2, neg, offset)
    var acc = Int64(0)
    if i >= n or not is_digit(Int(b[i])):
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    while i < n:
        var c = Int(b[i])
        if not is_digit(c):
            raise DecodeError(DecodeError.KIND_TYPE, offset)
        var d = Int64(c - 48)
        if acc > (Int64.MAX - d) // Int64(10):
            raise DecodeError(DecodeError.KIND_RANGE, offset)
        acc = acc * Int64(10) + d
        i += 1
    if neg:
        return -acc
    return acc


def _parse_hex[origin: ImmOrigin](b: Span[Byte, origin], start: Int, neg: Bool, offset: Int) raises DecodeError -> Int64:
    var i = start
    if i >= len(b):
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    var acc = UInt64(0)
    while i < len(b):
        var h = hex_val(Int(b[i]))
        if h < 0:
            raise DecodeError(DecodeError.KIND_TYPE, offset)
        acc = (acc << UInt64(4)) + UInt64(h)
        i += 1
    var v = Int64(acc)
    if neg:
        return -v
    return v


def _parse_oct[origin: ImmOrigin](b: Span[Byte, origin], start: Int, neg: Bool, offset: Int) raises DecodeError -> Int64:
    var i = start
    if i >= len(b):
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    var acc = Int64(0)
    while i < len(b):
        var c = Int(b[i])
        if c < 48 or c > 55:
            raise DecodeError(DecodeError.KIND_TYPE, offset)
        acc = acc * Int64(8) + Int64(c - 48)
        i += 1
    if neg:
        return -acc
    return acc


def _parse_core_float(s: String, offset: Int) raises DecodeError -> Float64:
    if s == ".nan" or s == ".NaN" or s == ".NAN":
        return Float64(from_bits=UInt64(0x7FF8000000000000))
    if s == ".inf" or s == ".Inf" or s == ".INF" or s == "+.inf" or s == "+.Inf" or s == "+.INF":
        return Float64(from_bits=UInt64(0x7FF0000000000000))
    if s == "-.inf" or s == "-.Inf" or s == "-.INF":
        return Float64(from_bits=UInt64(0xFFF0000000000000))
    var b = s.as_bytes()
    var n = len(b)
    var i = 0
    if n == 0:
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    var c0 = Int(b[0])
    if c0 == 43 or c0 == 45:
        i = 1
    var saw_digit = False
    var saw_dot = False
    var saw_exp = False
    while i < n:
        var c = Int(b[i])
        if is_digit(c):
            saw_digit = True
        elif c == 46 and not saw_dot and not saw_exp:
            saw_dot = True
        elif (c == 101 or c == 69) and saw_digit and not saw_exp:
            saw_exp = True
            if i + 1 < n and (Int(b[i + 1]) == 43 or Int(b[i + 1]) == 45):
                i += 1
        else:
            raise DecodeError(DecodeError.KIND_TYPE, offset)
        i += 1
    if not saw_digit or (not saw_dot and not saw_exp):
        raise DecodeError(DecodeError.KIND_TYPE, offset)
    return _parse_decimal_float(s, offset)


def _parse_decimal_float(s: String, offset: Int) raises DecodeError -> Float64:
    var b = s.as_bytes()
    var i = 0
    var sign = 1.0
    if len(b) == 0:
        raise DecodeError(DecodeError.KIND_NUMBER, offset)
    if Int(b[0]) == 45:
        sign = -1.0
        i = 1
    elif Int(b[0]) == 43:
        i = 1
    var acc = 0.0
    var frac = 0.0
    var scale = 1.0
    var in_frac = False
    var saw = False
    while i < len(b):
        var c = Int(b[i])
        if is_digit(c):
            saw = True
            if in_frac:
                scale = scale * 0.1
                frac = frac + Float64(c - 48) * scale
            else:
                acc = acc * 10.0 + Float64(c - 48)
        elif c == 46 and not in_frac:
            in_frac = True
        elif c == 101 or c == 69:
            i += 1
            var es = 1
            if i < len(b) and Int(b[i]) == 45:
                es = -1
                i += 1
            elif i < len(b) and Int(b[i]) == 43:
                i += 1
            var ev = 0
            if i >= len(b):
                raise DecodeError(DecodeError.KIND_NUMBER, offset)
            while i < len(b):
                var d = Int(b[i])
                if not is_digit(d):
                    raise DecodeError(DecodeError.KIND_NUMBER, offset)
                ev = ev * 10 + (d - 48)
                i += 1
            var p = 1.0
            var k = 0
            while k < ev:
                p = p * 10.0
                k += 1
            var mag = acc + frac
            if es < 0:
                return sign * (mag / p)
            return sign * (mag * p)
        else:
            raise DecodeError(DecodeError.KIND_NUMBER, offset)
        i += 1
    if not saw:
        raise DecodeError(DecodeError.KIND_NUMBER, offset)
    return sign * (acc + frac)


def _decode_b64(s: String, offset: Int) raises DecodeError -> List[Byte]:
    var b = s.as_bytes()
    var out = List[Byte]()
    var acc = 0
    var bits = 0
    var i = 0
    while i < len(b):
        var c = Int(b[i])
        i += 1
        if c == 32 or c == 10 or c == 13 or c == 9:
            continue
        if c == 61:
            break
        var v = _b64_val(c)
        if v < 0:
            raise DecodeError(DecodeError.KIND_BINARY, offset)
        acc = (acc << 6) | v
        bits += 6
        if bits >= 8:
            bits -= 8
            out.append(Byte((acc >> bits) & 255))
    return out^


def _b64_val(c: Int) -> Int:
    if c >= 65 and c <= 90:
        return c - 65
    if c >= 97 and c <= 122:
        return c - 71
    if c >= 48 and c <= 57:
        return c + 4
    if c == 43:
        return 62
    if c == 47:
        return 63
    return -1


def _join_block(lines: List[String], folded: Bool, chomp: Int) -> String:
    var out = String()
    var i = 0
    var last_more = False
    while i < len(lines):
        var line = lines[i]
        var empty = line.byte_length() == 0
        var more = False
        if line.byte_length() > 0:
            more = Int(line.as_bytes()[0]) == 32
        if i == 0:
            out += line
        elif folded and not empty and not more and not last_more:
            if lines[i - 1].byte_length() == 0:
                out += "\n"
            else:
                out += " "
            out += line
        else:
            out += "\n"
            out += line
        last_more = more
        i += 1
    if chomp > 0:
        out += "\n"
    elif chomp == 0:
        out += "\n"
    return out^

