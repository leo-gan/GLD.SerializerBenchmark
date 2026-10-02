from std.collections import List, Span

from ion_runtime.doc import (
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_DECIMAL,
    K_FLOAT,
    K_INT,
    K_HOLE,
    K_LIST,
    K_NULL,
    K_SEXP,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    IonDoc,
    IonNode,
    IonTime,
    PREC_DAY,
    PREC_FRAC,
    PREC_MIN,
    PREC_MONTH,
    PREC_SEC,
    PREC_YEAR,
)
from ion_runtime.error import DecodeError
from ion_runtime.intx import BigInt, big_from_digit_list
from ion_runtime.symtab import Catalog, LocalTab
from ion_runtime.utf8 import append_utf8, string_from_span, validate_utf8
from ion_wire.lst import apply_lst, is_local_table, sym_from_sid


def _ident(c: Int) -> Bool:
    if c >= 48 and c <= 57:
        return True
    if c >= 65 and c <= 90 or c >= 97 and c <= 122:
        return True
    return c == 95 or c == 36


def _op(c: Int) -> Bool:
    if c == 33 or c == 35 or c == 37 or c == 38 or c == 42 or c == 43:
        return True
    if c == 45 or c == 46 or c == 47 or c == 59 or c == 60 or c == 61 or c == 62:
        return True
    return c == 63 or c == 64 or c == 94 or c == 96 or c == 124 or c == 126


def _stop(c: Int) -> Bool:
    if c == 32 or c == 9 or c == 10 or c == 13 or c == 11 or c == 12:
        return True
    if c == 123 or c == 125 or c == 91 or c == 93 or c == 40 or c == 41 or c == 44:
        return True
    return c == 92 or c == 34 or c == 39


def _ws(c: Int) -> Bool:
    return c == 32 or c == 9 or c == 10 or c == 13 or c == 11 or c == 12


def _hex(c: Int) -> Int:
    if c >= 48 and c <= 57:
        return c - 48
    if c >= 65 and c <= 70:
        return c - 55
    if c >= 97 and c <= 102:
        return c - 87
    return -1


def _days(year: Int, month: Int) -> Int:
    if month == 2:
        var leap = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
        if leap:
            return 29
        return 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31


struct TextParser[origin: ImmOrigin]:
    var raw: Span[Byte, Self.origin]
    var i: Int
    var n: Int
    var depth: Int
    var sexp: Int
    var ver: Int
    var bare_ivm: Int
    var templ: Bool
    var cur_param0: Int
    var macro_name: List[String]
    var macro_root: List[Int]
    var macro_param_at: List[Int]
    var macro_nparam: List[Int]
    var param_kind: List[Int]
    var param_default: List[Int]
    var ident_cache0: String
    var ident_node0: Int
    var ident_cache1: String
    var ident_node1: Int
    var ident_hit: Int
    var str_cache: String
    var str_id: Int

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.n = len(raw)
        self.depth = 0
        self.sexp = 0
        self.ver = 10
        self.bare_ivm = 0
        self.templ = False
        self.cur_param0 = 0
        self.macro_name = List[String]()
        self.macro_root = List[Int]()
        self.macro_param_at = List[Int]()
        self.macro_nparam = List[Int]()
        self.param_kind = List[Int]()
        self.param_default = List[Int]()
        self.ident_cache0 = String()
        self.ident_node0 = -1
        self.ident_cache1 = String()
        self.ident_node1 = -1
        self.ident_hit = -1
        self.str_cache = String()
        self.str_id = -1

    def _b(self) -> Int:
        return Int(self.raw[self.i])

    def _at(self, k: Int) -> Int:
        return Int(self.raw[k])

    def skip_ws(mut self) raises DecodeError:
        while self.i < self.n:
            var c = self._b()
            if _ws(c):
                self.i += 1
                continue
            if c == 47 and self.i + 1 < self.n:
                var n = self._at(self.i + 1)
                if n == 47:
                    self.i += 2
                    while self.i < self.n and self._b() != 10 and self._b() != 13:
                        self.i += 1
                    continue
                if n == 42:
                    self.i += 2
                    var ok = False
                    while self.i + 1 < self.n:
                        if self._b() == 42 and self._at(self.i + 1) == 47:
                            self.i += 2
                            ok = True
                            break
                        self.i += 1
                    if not ok:
                        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                    continue
            return

    def _expect(mut self, c: Int) raises DecodeError:
        if self.i >= self.n or self._b() != c:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.i += 1

    def read_all(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError:
        while True:
            self.skip_ws()
            if self.i >= self.n:
                return
            self.bare_ivm = 0
            var id = self.parse_value(doc, tab, cat)
            if id < 0:
                continue
            if self.bare_ivm == 10:
                tab.reset_system()
                self._clear_macros()
                self.ver = 10
                continue
            if self.bare_ivm == 11:
                tab.reset_system()
                self._clear_macros()
                self.ver = 11
                continue
            if self._ivm_nop(doc, id):
                continue
            if self.ver == 10 and is_local_table(doc, id):
                apply_lst(doc, id, tab, cat, self.i)
                continue
            if self.ver == 11 and is_local_table(doc, id):
                continue
            doc.add_top(id)

    def _ivm_nop(self, doc: IonDoc, id: Int) -> Bool:
        var n = doc.nodes[id]
        if n.ann_n != 0 or n.kind != K_SYMBOL:
            return False
        var s = doc.syms[n.a]
        if s.text < 0:
            return False
        var t = doc.texts[s.text]
        if t == "$ion_1_0":
            return True
        return self.ver == 11 and t == "$ion_1_1"

    def parse_value(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        self.skip_ws()
        if self.depth == 0:
            var iv = self._bare_ivm(doc)
            if iv != 0:
                self.bare_ivm = iv
                if iv == 10:
                    return doc.add_symbol_text("$ion_1_0")
                return doc.add_symbol_text("$ion_1_1")
        if not self._ann_ahead():
            return self._one(doc, tab, cat)
        var anns = List[Int]()
        while self._ann_ahead():
            var quoted = self._b() == 39
            var sym = self.parse_symbol(doc, tab, quoted)
            self.skip_ws()
            self._expect(58)
            self._expect(58)
            anns.append(sym)
            self.skip_ws()
        var id = self._one(doc, tab, cat)
        if id < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        doc.set_anns(id, anns^)
        return id

    def _bare_ivm(mut self, doc: IonDoc) raises DecodeError -> Int:
        _ = doc
        if self.i >= self.n or not _ident(self._b()) or (self._b() >= 48 and self._b() <= 57):
            return 0
        var j = self.i
        while j < self.n and _ident(self._at(j)):
            j += 1
        var word = self._copy(self.i, j)
        var k = j
        while k < self.n and _ws(self._at(k)):
            k += 1
        if k + 1 < self.n and self._at(k) == 58 and self._at(k + 1) == 58:
            return 0
        var which = self._ivm_word(word)
        if which == 0:
            return 0
        self.i = j
        return which

    def _ivm_word(self, word: String) raises DecodeError -> Int:
        var b = word.as_bytes()
        if len(b) < 8 or Int(b[0]) != 36:
            return 0
        var prefix = String("$ion_")
        var pb = prefix.as_bytes()
        if len(b) <= len(pb):
            return 0
        var k = 0
        while k < len(pb):
            if Int(b[k]) != Int(pb[k]):
                return 0
            k += 1
        var major = 0
        var saw = False
        while k < len(b) and Int(b[k]) >= 48 and Int(b[k]) <= 57:
            saw = True
            major = major * 10 + Int(b[k]) - 48
            k += 1
        if not saw or k >= len(b) or Int(b[k]) != 95:
            return 0
        k += 1
        var minor = 0
        saw = False
        while k < len(b) and Int(b[k]) >= 48 and Int(b[k]) <= 57:
            saw = True
            minor = minor * 10 + Int(b[k]) - 48
            k += 1
        if not saw or k != len(b):
            return 0
        if major == 1 and minor == 0:
            return 10
        if major == 1 and minor == 1:
            return 11
        raise DecodeError(DecodeError.KIND_VERSION, self.i)

    def _ann_ahead(self) -> Bool:
        if self.i >= self.n:
            return False
        var c = self._b()
        if c != 39 and c != 36 and not (c >= 65 and c <= 90) and not (c >= 97 and c <= 122) and c != 95:
            return False
        var j = self.i
        if c == 39:
            j += 1
            while j < self.n:
                if self._at(j) == 92:
                    j += 2
                    continue
                if self._at(j) == 39:
                    j += 1
                    break
                j += 1
        else:
            while j < self.n and _ident(self._at(j)):
                j += 1
            var word = self._copy(self.i, j)
            if word == "null" or word == "true" or word == "false" or word == "nan":
                return False
        var k = j
        while k < self.n and _ws(self._at(k)):
            k += 1
        return k + 1 < self.n and self._at(k) == 58 and self._at(k + 1) == 58

    def _one(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        if self.i >= self.n:
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var c = self._b()
        if self.ver == 11 and c == 40 and self.i + 1 < self.n and self._at(self.i + 1) == 58:
            return self._colon(doc, tab, cat)
        if c == 91:
            return self._list(doc, tab, cat)
        if c == 40:
            return self._sexp(doc, tab, cat)
        if c == 123:
            if self.i + 1 < self.n and self._at(self.i + 1) == 123:
                return self._lob(doc)
            return self._struct(doc, tab, cat)
        if c == 34:
            return self._string(doc, False)
        if c == 39:
            if self.i + 2 < self.n and self._at(self.i + 1) == 39 and self._at(self.i + 2) == 39:
                return self._string(doc, True)
            var sym = self.parse_symbol(doc, tab, True)
            return doc.wrap_sym(sym)
        if c == 43 or c == 45 or (c >= 48 and c <= 57):
            return self._number(doc)
        if _ident(c):
            return self._keyword_or_symbol(doc, tab)
        if self.sexp > 0 and _op(c):
            var text = self._operator()
            return doc.add_symbol_text(text)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _copy(self, a: Int, b: Int) -> String:
        if a >= b:
            return String()
        return String(unsafe_from_utf8=self.raw[a:b])

    def _list(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        self._enter()
        self.i += 1
        var id = doc.start_container(K_LIST)
        self.skip_ws()
        if self.i < self.n and self._b() == 93:
            self.i += 1
            self.depth -= 1
            return id
        while True:
            var child = self.parse_value(doc, tab, cat)
            if child >= 0:
                doc.add_child(id, child, -1)
            self.skip_ws()
            if self.i < self.n and self._b() == 44:
                self.i += 1
                self.skip_ws()
                if self.i < self.n and self._b() == 93:
                    self.i += 1
                    break
                continue
            if self.i < self.n and self._b() == 93:
                self.i += 1
                break
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.depth -= 1
        return id

    def _sexp(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        self._enter()
        self.i += 1
        self.sexp += 1
        var id = doc.start_container(K_SEXP)
        while True:
            self.skip_ws()
            if self.i < self.n and self._b() == 41:
                self.i += 1
                break
            if self.i >= self.n:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            var child = self.parse_value(doc, tab, cat)
            if child >= 0:
                doc.add_child(id, child, -1)
        self.sexp -= 1
        self.depth -= 1
        return id

    def _struct(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        self._enter()
        self.i += 1
        var id = doc.start_container(K_STRUCT)
        self.skip_ws()
        if self.i < self.n and self._b() == 125:
            self.i += 1
            self.depth -= 1
            return id
        while True:
            var field = self._field_name(doc, tab)
            if self.i < self.n and self._b() == 58:
                self.i += 1
                if self.i < self.n and self._b() == 58:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            else:
                self.skip_ws()
                self._expect(58)
                if self.i < self.n and self._b() == 58:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            var child = self.parse_value(doc, tab, cat)
            if child >= 0:
                doc.add_child(id, child, field)
            if self.i >= self.n or (self._b() != 44 and self._b() != 125):
                self.skip_ws()
            if self.i < self.n and self._b() == 44:
                self.i += 1
                self.skip_ws()
                if self.i < self.n and self._b() == 125:
                    self.i += 1
                    break
                continue
            if self.i < self.n and self._b() == 125:
                self.i += 1
                break
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.depth -= 1
        return id

    def _enter(mut self) raises DecodeError:
        if self.depth >= 1024:
            raise DecodeError(DecodeError.KIND_DEPTH, self.i)
        self.depth += 1

    def _field_name(mut self, mut doc: IonDoc, mut tab: LocalTab) raises DecodeError -> Int:
        self.skip_ws()
        if self.i >= self.n:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var c = self._b()
        var long = c == 39 and self.i + 2 < self.n and self._at(self.i + 1) == 39 and self._at(self.i + 2) == 39
        if c == 34 or long:
            var node = self._string(doc, long)
            return self._string_as_sym(doc, node)
        if c == 39:
            return self.parse_symbol(doc, tab, True)
        if _ident(c) and not (c >= 48 and c <= 57):
            return self.parse_symbol(doc, tab, False)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _string_as_sym(mut self, mut doc: IonDoc, node: Int) -> Int:
        var text = doc.text_at(node)
        var sym = doc.add_symbol_text(text)
        return doc.nodes[sym].a

    def parse_symbol(mut self, mut doc: IonDoc, mut tab: LocalTab, quoted: Bool) raises DecodeError -> Int:
        if quoted:
            var text = self._quoted(39, False)
            var node = doc.add_symbol_text(String(unsafe_from_utf8=text))
            return doc.nodes[node].a
        self._take_ident()
        var fast = self._fast_symbol_node(doc)
        if fast >= 0:
            return doc.nodes[fast].a
        var text = self._hit_text()
        var text_bytes = text.as_bytes()
        if len(text_bytes) > 1 and Int(text_bytes[0]) == 36:
            var all_digit = True
            var k = 1
            while k < len(text_bytes):
                var ch = Int(text_bytes[k])
                if ch < 48 or ch > 57:
                    all_digit = False
                    break
                k += 1
            if all_digit:
                var sid = 0
                k = 1
                while k < len(text_bytes):
                    sid = sid * 10 + Int(text_bytes[k]) - 48
                    if sid > 2000000000:
                        raise DecodeError(DecodeError.KIND_RANGE, self.i)
                    k += 1
                var node = sym_from_sid(doc, tab, sid, self.i)
                return doc.nodes[node].a
        if text == "null" or text == "true" or text == "false" or text == "nan":
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var node = doc.add_symbol_text(text)
        return doc.nodes[node].a

    def _take_ident(mut self) raises DecodeError:
        if self.i >= self.n or not _ident(self._b()) or (self._b() >= 48 and self._b() <= 57):
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var start = self.i
        self.i += 1
        while self.i < self.n and _ident(self._b()):
            self.i += 1
        var n = self.i - start
        if self._same_ident(self.ident_cache0, start, n):
            self.ident_hit = 0
            return
        if self._same_ident(self.ident_cache1, start, n):
            self.ident_hit = 1
            return
        self.ident_cache1 = self.ident_cache0
        self.ident_node1 = self.ident_node0
        self.ident_cache0 = self._copy(start, self.i)
        self.ident_node0 = -1
        self.ident_hit = 0

    def _ident_text(mut self) raises DecodeError -> String:
        self._take_ident()
        return self._hit_text()

    def _hit_text(self) -> String:
        if self.ident_hit == 0:
            return self.ident_cache0
        return self.ident_cache1

    def _cached_sym_node(self) -> Int:
        if self.ident_hit == 0:
            return self.ident_node0
        if self.ident_hit == 1:
            return self.ident_node1
        return -1

    def _remember_node(mut self, node: Int):
        if self.ident_hit == 0:
            self.ident_node0 = node
        elif self.ident_hit == 1:
            self.ident_node1 = node

    def _cache_lead(self) -> Int:
        if self.ident_hit == 0:
            var raw = self.ident_cache0.as_bytes()
            if len(raw) == 0:
                return 0
            return Int(raw[0])
        var raw = self.ident_cache1.as_bytes()
        if len(raw) == 0:
            return 0
        return Int(raw[0])

    def _is_keyword_text(self, text: String) -> Bool:
        var raw = text.as_bytes()
        var n = len(raw)
        if n == 3:
            return Int(raw[0]) == 110 and Int(raw[1]) == 97 and Int(raw[2]) == 110
        if n == 4:
            if Int(raw[0]) == 110 and Int(raw[1]) == 117 and Int(raw[2]) == 108 and Int(raw[3]) == 108:
                return True
            return Int(raw[0]) == 116 and Int(raw[1]) == 114 and Int(raw[2]) == 117 and Int(raw[3]) == 101
        if n == 5:
            return (
                Int(raw[0]) == 102
                and Int(raw[1]) == 97
                and Int(raw[2]) == 108
                and Int(raw[3]) == 115
                and Int(raw[4]) == 101
            )
        return False

    def _cached_is_keyword(self) -> Bool:
        if self.ident_hit == 0:
            return self._is_keyword_text(self.ident_cache0)
        if self.ident_hit == 1:
            return self._is_keyword_text(self.ident_cache1)
        return False

    def _fast_symbol_node(mut self, mut doc: IonDoc) -> Int:
        """Symbol node for the ident just scanned. `-1` when it is a keyword or a `$` symbol."""
        if self._cached_is_keyword() or self._cache_lead() == 36:
            return -1
        var node = self._cached_sym_node()
        if node >= 0:
            return node
        node = doc.add_symbol_text(self._hit_text())
        self._remember_node(node)
        return node

    def _same_ident(self, cached: String, start: Int, n: Int) -> Bool:
        var raw = cached.as_bytes()
        if len(raw) != n:
            return False
        var k = 0
        while k < n:
            if Int(raw[k]) != self._at(start + k):
                return False
            k += 1
        return True

    def _operator(mut self) raises DecodeError -> String:
        var buf = List[Byte]()
        while self.i < self.n and _op(self._b()):
            if self._b() == 47 and self.i + 1 < self.n:
                var n = self._at(self.i + 1)
                if n == 47 or n == 42:
                    break
            buf.append(self.raw[self.i])
            self.i += 1
        if len(buf) == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        return String(unsafe_from_utf8=buf)

    def _keyword_or_symbol(mut self, mut doc: IonDoc, mut tab: LocalTab) raises DecodeError -> Int:
        self._take_ident()
        var fast = self._fast_symbol_node(doc)
        if fast >= 0:
            return fast
        var text = self._hit_text()
        if text == "null":
            return self._null(doc)
        if text == "true":
            return doc.add_bool(True)
        if text == "false":
            return doc.add_bool(False)
        if text == "nan":
            return doc.add_float(8, UInt64(0x7FF8000000000000))
        var bytes = text.as_bytes()
        if len(bytes) > 1 and Int(bytes[0]) == 36:
            var all_digit = True
            var k = 1
            while k < len(bytes):
                var ch = Int(bytes[k])
                if ch < 48 or ch > 57:
                    all_digit = False
                    break
                k += 1
            if all_digit:
                var sid = 0
                k = 1
                while k < len(bytes):
                    sid = sid * 10 + Int(bytes[k]) - 48
                    k += 1
                return sym_from_sid(doc, tab, sid, self.i)
        return doc.add_symbol_text(text)

    def _null(mut self, mut doc: IonDoc) raises DecodeError -> Int:
        if self.i >= self.n or self._b() != 46:
            return doc.add_null(0)
        self.i += 1
        var name = self._ident_text()
        if name == "null":
            return doc.add_null(0)
        if name == "bool":
            return doc.add_null(K_BOOL)
        if name == "int":
            return doc.add_null(K_INT)
        if name == "float":
            return doc.add_null(K_FLOAT)
        if name == "decimal":
            return doc.add_null(K_DECIMAL)
        if name == "timestamp":
            return doc.add_null(6)
        if name == "string":
            return doc.add_null(K_STRING)
        if name == "symbol":
            return doc.add_null(8)
        if name == "blob":
            return doc.add_null(K_BLOB)
        if name == "clob":
            return doc.add_null(K_CLOB)
        if name == "list":
            return doc.add_null(K_LIST)
        if name == "sexp":
            return doc.add_null(K_SEXP)
        if name == "struct":
            return doc.add_null(K_STRUCT)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _string(mut self, mut doc: IonDoc, long: Bool) raises DecodeError -> Int:
        if not long:
            var plain = self._plain_quote(34)
            if plain >= 0:
                var start = self.i + 1
                var n = plain - start
                var cached = self.str_cache.as_bytes()
                if len(cached) == n:
                    var same = True
                    var k = 0
                    while k < n:
                        if Int(cached[k]) != self._at(start + k):
                            same = False
                            break
                        k += 1
                    if same:
                        self.i = plain + 1
                        if self.str_id >= 0:
                            return doc.add_string_at(self.str_id)
                        var hit = doc.add_string(self.str_cache)
                        self.str_id = doc.nodes[hit].a
                        return hit
                self.str_cache = String(unsafe_from_utf8=self.raw[start:plain])
                self.i = plain + 1
                var made = doc.add_string(self.str_cache)
                self.str_id = doc.nodes[made].a
                return made
        var buf = List[Byte]()
        if long:
            self._read_long(buf, False)
            while True:
                var save = self.i
                self.skip_ws()
                if self._starts_long():
                    self._read_long(buf, False)
                else:
                    self.i = save
                    break
        else:
            self._read_short(buf, 34, False)
        return doc.add_string(String(unsafe_from_utf8=buf))

    def _plain_quote(self, end: Int) -> Int:
        """Index of the closing quote when the literal has no escapes. -1 otherwise."""
        if self.i >= self.n or self._b() != end:
            return -1
        var j = self.i + 1
        while j < self.n:
            var c = self._at(j)
            if c == end:
                return j
            if c == 92 or c < 32:
                return -1
            j += 1
        return -1

    def _quoted(mut self, end: Int, long: Bool) raises DecodeError -> List[Byte]:
        var buf = List[Byte]()
        if long:
            self._read_long(buf, False)
        else:
            self._read_short(buf, end, False)
        return buf^

    def _starts_long(self) -> Bool:
        return (
            self.i + 2 < self.n
            and self._b() == 39
            and self._at(self.i + 1) == 39
            and self._at(self.i + 2) == 39
        )

    def _read_short(mut self, mut buf: List[Byte], end: Int, clob: Bool) raises DecodeError:
        self._expect(end)
        while self.i < self.n:
            var c = self._b()
            if c == end:
                self.i += 1
                return
            if c < 32 and c != 9 and c != 11 and c != 12:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            if c == 92:
                self._escape(buf, clob)
                continue
            if clob and c >= 128:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            buf.append(Byte(c))
            self.i += 1
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _read_long(mut self, mut buf: List[Byte], clob: Bool) raises DecodeError:
        if not self._starts_long():
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.i += 3
        while self.i < self.n:
            if self._starts_long():
                self.i += 3
                return
            var c = self._b()
            if c < 32 and c != 9 and c != 10 and c != 11 and c != 12 and c != 13:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            if c == 92:
                self._escape(buf, clob)
                continue
            if c == 13:
                self.i += 1
                if self.i < self.n and self._b() == 10:
                    self.i += 1
                buf.append(Byte(10))
                continue
            if clob and c >= 128:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            buf.append(Byte(c))
            self.i += 1
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _escape(mut self, mut buf: List[Byte], clob: Bool) raises DecodeError:
        self.i += 1
        if self.i >= self.n:
            raise DecodeError(DecodeError.KIND_ESCAPE, self.i)
        var c = self._b()
        self.i += 1
        if c == 48:
            buf.append(Byte(0))
        elif c == 97:
            buf.append(Byte(7))
        elif c == 98:
            buf.append(Byte(8))
        elif c == 116:
            buf.append(Byte(9))
        elif c == 110:
            buf.append(Byte(10))
        elif c == 118:
            buf.append(Byte(11))
        elif c == 102:
            buf.append(Byte(12))
        elif c == 114:
            buf.append(Byte(13))
        elif c == 34 or c == 39 or c == 47 or c == 63 or c == 92:
            buf.append(Byte(c))
        elif c == 10:
            return
        elif c == 13:
            if self.i < self.n and self._b() == 10:
                self.i += 1
            return
        elif c == 120:
            self._u_escape(buf, 2)
        elif c == 117 or c == 85:
            if clob:
                raise DecodeError(DecodeError.KIND_ESCAPE, self.i)
            if c == 85:
                self._u_escape(buf, 8)
            else:
                var cp = self._hex_cp(4)
                if cp >= 0xD800 and cp <= 0xDBFF:
                    if self.i + 1 < self.n and self._b() == 92 and self._at(self.i + 1) == 117:
                        self.i += 2
                        var low = self._hex_cp(4)
                        if low < 0xDC00 or low > 0xDFFF:
                            raise DecodeError(DecodeError.KIND_ESCAPE, self.i)
                        cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                    else:
                        raise DecodeError(DecodeError.KIND_ESCAPE, self.i)
                append_utf8(buf, cp, self.i)
        else:
            raise DecodeError(DecodeError.KIND_ESCAPE, self.i)

    def _hex_cp(mut self, n: Int) raises DecodeError -> Int:
        if self.i + n > self.n:
            raise DecodeError(DecodeError.KIND_ESCAPE, self.i)
        var cp = 0
        var k = 0
        while k < n:
            var h = _hex(self._at(self.i + k))
            if h < 0:
                raise DecodeError(DecodeError.KIND_ESCAPE, self.i)
            cp = (cp << 4) | h
            k += 1
        self.i += n
        return cp

    def _u_escape(mut self, mut buf: List[Byte], n: Int) raises DecodeError:
        var cp = self._hex_cp(n)
        append_utf8(buf, cp, self.i)

    def _lob(mut self, mut doc: IonDoc) raises DecodeError -> Int:
        self._expect(123)
        self._expect(123)
        var j = self.i
        while j < self.n and _ws(self._at(j)):
            j += 1
        if j < self.n and (self._at(j) == 34 or self._at(j) == 39):
            return self._clob(doc)
        var chars = List[Byte]()
        while self.i < self.n:
            var c = self._b()
            if c == 125 and self.i + 1 < self.n and self._at(self.i + 1) == 125:
                self.i += 2
                var raw = _b64(chars, self.i)
                return doc.add_bytes(K_BLOB, raw^)
            if _ws(c):
                self.i += 1
                continue
            if _b64_char(c) < 0 and c != 61:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            chars.append(Byte(c))
            self.i += 1
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _clob(mut self, mut doc: IonDoc) raises DecodeError -> Int:
        while self.i < self.n and _ws(self._b()):
            self.i += 1
        var buf = List[Byte]()
        var long = self._starts_long()
        if long:
            self._read_long(buf, True)
        elif self.i < self.n and self._b() == 34:
            self._read_short(buf, 34, True)
        else:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if long:
            while True:
                var save = self.i
                while self.i < self.n and _ws(self._b()):
                    self.i += 1
                if self._starts_long():
                    self._read_long(buf, True)
                else:
                    self.i = save
                    break
        while self.i < self.n and _ws(self._b()):
            self.i += 1
        if self.i + 1 >= self.n or self._b() != 125 or self._at(self.i + 1) != 125:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.i += 2
        return doc.add_bytes(K_CLOB, buf^)

    def _number(mut self, mut doc: IonDoc) raises DecodeError -> Int:
        var neg = False
        if self._b() == 43:
            var save = self.i
            self.i += 1
            if self._word_at("inf"):
                self._need_stop()
                return doc.add_float(8, UInt64(0x7FF0000000000000))
            if self.sexp > 0:
                self.i = save
                return doc.add_symbol_text(self._operator())
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self._b() == 45:
            var save = self.i
            self.i += 1
            if self._word_at("inf"):
                self._need_stop()
                return doc.add_float(8, UInt64(0xFFF0000000000000))
            if self.i >= self.n or not (self._b() >= 48 and self._b() <= 57):
                if self.sexp > 0:
                    self.i = save
                    return doc.add_symbol_text(self._operator())
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            neg = True
        if self.i < self.n and self._b() == 48 and self.i + 1 < self.n:
            var n = self._at(self.i + 1)
            if n == 120 or n == 88 or n == 98 or n == 66:
                return self._radix(doc, neg, n == 98 or n == 66)
        var fast = self._fast_i64(doc, neg)
        if fast >= 0:
            return fast
        return self._real(doc, neg)

    def _fast_i64(mut self, mut doc: IonDoc, neg: Bool) raises DecodeError -> Int:
        """Parse a decimal integer that fits in Int64. Returns -1 when the token is not that simple."""
        if self.i >= self.n:
            return -1
        var c0 = self._b()
        if c0 < 48 or c0 > 57:
            return -1
        if c0 == 48:
            var nxt = self.i + 1
            if nxt < self.n:
                var n = self._at(nxt)
                if not _stop(n) and not _ws(n):
                    return -1
            self.i = nxt
            return doc.add_i64(Int64(0))
        var acc = Int64(0)
        var j = self.i
        var digits = 0
        while j < self.n:
            var c = self._at(j)
            if c < 48 or c > 57:
                break
            if acc > Int64(922337203685477580):
                return -1
            acc = acc * Int64(10) + Int64(c - 48)
            digits += 1
            j += 1
        if digits == 0:
            return -1
        if j < self.n:
            var n = self._at(j)
            if not _stop(n) and not _ws(n):
                return -1
        self.i = j
        if neg:
            return doc.add_i64(Int64(0) - acc)
        return doc.add_i64(acc)

    def _word_at(mut self, word: String) -> Bool:
        var b = word.as_bytes()
        if self.i + len(b) > self.n:
            return False
        var k = 0
        while k < len(b):
            if self._at(self.i + k) != Int(b[k]):
                return False
            k += 1
        var end = self.i + len(b)
        if end < self.n and _ident(self._at(end)):
            return False
        self.i = end
        return True

    def _need_stop(mut self) raises DecodeError:
        if self.i < self.n and not _stop(self._b()):
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _radix(mut self, mut doc: IonDoc, neg: Bool, binary: Bool) raises DecodeError -> Int:
        self.i += 2
        var base = 16
        if binary:
            base = 2
        var acc = BigInt()
        var any = False
        var prev_us = False
        while self.i < self.n:
            var c = self._b()
            if c == 95:
                if not any or prev_us:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                prev_us = True
                self.i += 1
                continue
            var d = _hex(c)
            if binary and (c == 48 or c == 49):
                d = c - 48
            elif binary:
                d = -1
            if d < 0 or (not binary and d > 15):
                break
            any = True
            prev_us = False
            acc.mul_small(UInt32(base))
            acc.add_small(UInt32(d))
            self.i += 1
        if not any or prev_us:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if neg and not acc.is_zero():
            acc.neg = True
        self._need_stop()
        return doc.add_int(acc^)

    def _real(mut self, mut doc: IonDoc, neg: Bool) raises DecodeError -> Int:
        var whole = List[Byte]()
        var under = False
        var nwhole = self._digits(whole, under)
        if nwhole == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self.i < self.n and (self._b() == 45 or self._b() == 84):
            if not neg and not under and nwhole >= 4:
                return self._timestamp(doc, whole^)
            if self._b() == 84 or self._b() == 45:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if len(whole) > 1 and Int(whole[0]) == 48:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var frac = List[Byte]()
        var saw_dot = False
        if self.i < self.n and self._b() == 46:
            _ = under
            saw_dot = True
            self.i += 1
            if self.i < self.n and self._b() == 95:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            if self.i < self.n and ((self._b() >= 48 and self._b() <= 57) or self._b() == 95):
                var frac_under = False
                _ = self._digits(frac, frac_under)
        var exp = 0
        var is_float = False
        var is_dec = saw_dot
        if self.i < self.n and (self._b() == 101 or self._b() == 69 or self._b() == 100 or self._b() == 68):
            is_float = self._b() == 101 or self._b() == 69
            is_dec = not is_float
            self.i += 1
            exp = self._exp()
        if not is_dec and not is_float:
            if under:
                pass
            var coef = big_from_digit_list(whole, False)
            if neg and not coef.is_zero():
                coef.neg = True
            self._need_stop()
            return doc.add_int(coef^)
        var all = List[Byte]()
        var p = 0
        while p < len(whole):
            all.append(whole[p])
            p += 1
        p = 0
        while p < len(frac):
            all.append(frac[p])
            p += 1
        if is_float:
            self._need_stop()
            return self._float_node(doc, neg, whole, frac, exp)
        var coef = big_from_digit_list(all, False)
        var dec_neg = neg
        self._need_stop()
        return doc.add_decimal(coef^, dec_neg, exp - len(frac))

    def _digits(mut self, mut out: List[Byte], mut under: Bool) raises DecodeError -> Int:
        var n = 0
        var prev = False
        while self.i < self.n:
            var c = self._b()
            if c >= 48 and c <= 57:
                out.append(Byte(c))
                n += 1
                prev = False
                self.i += 1
                continue
            if c == 95:
                if n == 0 or prev:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                prev = True
                under = True
                self.i += 1
                continue
            break
        if prev:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        return n

    def _exp(mut self) raises DecodeError -> Int:
        var sign = 1
        if self.i < self.n and (self._b() == 43 or self._b() == 45):
            if self._b() == 45:
                sign = -1
            self.i += 1
        var digits = List[Byte]()
        var under = False
        var n = self._digits(digits, under)
        if n == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var v = 0
        var k = 0
        while k < len(digits):
            if v > 922337203685477580:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            v = v * 10 + Int(digits[k]) - 48
            k += 1
        return sign * v

    def _float_node(mut self, mut doc: IonDoc, neg: Bool, whole: List[Byte], frac: List[Byte], exp: Int) raises DecodeError -> Int:
        var zero = True
        var k = 0
        while k < len(whole):
            if Int(whole[k]) != 48:
                zero = False
            k += 1
        k = 0
        while k < len(frac):
            if Int(frac[k]) != 48:
                zero = False
            k += 1
        if zero and neg:
            return doc.add_float(8, UInt64(1) << UInt64(63))
        if zero:
            return doc.add_float(0, UInt64(0))
        var sig = List[Byte]()
        k = 0
        var seen = False
        while k < len(whole):
            if seen or Int(whole[k]) != 48:
                seen = True
                sig.append(whole[k])
            k += 1
        var frac_kept = 0
        k = 0
        while k < len(frac):
            if seen or Int(frac[k]) != 48:
                seen = True
                sig.append(frac[k])
                frac_kept += 1
            elif seen:
                sig.append(frac[k])
                frac_kept += 1
            k += 1
        var power = exp - len(frac)
        if len(sig) > 17:
            var next = Int(sig[17])
            var extra = len(sig) - 17
            while len(sig) > 17:
                _ = sig.pop()
            if next >= 53:
                var p = len(sig) - 1
                var carry = 1
                while p >= 0 and carry == 1:
                    var d = Int(sig[p]) - 48 + carry
                    if d == 10:
                        sig[p] = Byte(48)
                        carry = 1
                    else:
                        sig[p] = Byte(d + 48)
                        carry = 0
                    p -= 1
                if carry == 1:
                    var grown = List[Byte]()
                    grown.append(Byte(49))
                    var q = 0
                    while q < len(sig) - 1:
                        grown.append(sig[q])
                        q += 1
                    sig = grown^
                    extra += 1
            power += extra
        var token = String()
        if neg:
            token += "-"
        k = 0
        while k < len(sig):
            token += String(chr(Int(sig[k])))
            k += 1
        token += "e"
        if power < 0:
            token += "-"
            token += String(0 - power)
        else:
            token += String(power)
        try:
            var f = Float64(token)
            return doc.add_float(8, UInt64(f.to_bits()))
        except _:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)

    def _timestamp(mut self, mut doc: IonDoc, var digits: List[Byte]) raises DecodeError -> Int:
        if len(digits) != 4:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var year = 0
        var k = 0
        while k < len(digits):
            year = year * 10 + Int(digits[k]) - 48
            if year > 999999999:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            k += 1
        if year < 1:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var prec = PREC_YEAR
        var month = 1
        var day = 1
        var hour = 0
        var minute = 0
        var second = 0
        var frac = List[Byte]()
        var unknown = True
        var off = 0
        if self.i < self.n and self._b() == 45:
            self.i += 1
            month = self._two()
            prec = PREC_MONTH
            if month < 1 or month > 12:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            if self.i < self.n and self._b() == 45:
                self.i += 1
                day = self._two()
                prec = PREC_DAY
                if day < 1 or day > _days(year, month):
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self.i < self.n and self._b() == 84:
            self.i += 1
            if self.i < self.n and self._b() >= 48 and self._b() <= 57:
                if prec != PREC_DAY:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                hour = self._two()
                self._expect(58)
                minute = self._two()
                prec = PREC_MIN
                if hour > 23 or minute > 59:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                if self.i < self.n and self._b() == 58:
                    self.i += 1
                    second = self._two()
                    prec = PREC_SEC
                    if second > 59:
                        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                    if self.i < self.n and self._b() == 46:
                        self.i += 1
                        var u = False
                        var nfrac = self._digits(frac, u)
                        if nfrac == 0:
                            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                        prec = PREC_FRAC
                if self.i >= self.n:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                var c = self._b()
                if c == 90:
                    self.i += 1
                    unknown = False
                    off = 0
                elif c == 43 or c == 45:
                    var sign = 1
                    if c == 45:
                        sign = -1
                    self.i += 1
                    var oh = self._two()
                    self._expect(58)
                    var om = self._two()
                    if oh > 23 or om > 59:
                        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                    if sign < 0 and oh == 0 and om == 0:
                        unknown = True
                        off = 0
                    else:
                        unknown = False
                        off = sign * (oh * 60 + om)
                else:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            elif prec != PREC_YEAR and prec != PREC_MONTH and prec != PREC_DAY:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        elif prec != PREC_DAY:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self._need_stop()
        var when = IonTime()
        when.prec = prec
        when.year = year
        when.month = month
        when.day = day
        when.hour = hour
        when.minute = minute
        when.second = second
        when.unknown = unknown
        when.off = off
        if prec == PREC_FRAC:
            when.frac_exp = 0 - len(frac)
            var coef = big_from_digit_list(frac, False)
            when.frac_at = len(doc.limbs)
            when.frac_len = len(coef.limbs)
            var t = 0
            while t < len(coef.limbs):
                doc.limbs.append(coef.limbs[t])
                t += 1
        return doc.add_time(when)

    def _two(mut self) raises DecodeError -> Int:
        if self.i + 1 >= self.n:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var a = self._b()
        var b = self._at(self.i + 1)
        if a < 48 or a > 57 or b < 48 or b > 57:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.i += 2
        return (a - 48) * 10 + (b - 48)


    def _clear_macros(mut self):
        self.macro_name = List[String]()
        self.macro_root = List[Int]()
        self.macro_param_at = List[Int]()
        self.macro_nparam = List[Int]()
        self.param_kind = List[Int]()
        self.param_default = List[Int]()

    def _colon(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        """Ion 1.1 `(:...)` form: a directive, an e-expression, or a template placeholder."""
        self.i += 2
        self.skip_ws()
        if self.i < self.n and self._b() == 63:
            return self._placeholder(doc, tab, cat)
        if self.i < self.n and self._b() == 41:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var name = self._ident_text()
        if name == "$ion":
            if self.depth != 0:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            return self._directive11(doc, tab, cat)
        if self.templ:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        return self._invoke(doc, tab, cat, name)

    def _placeholder(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        if not self.templ:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.i += 1
        self.skip_ws()
        var default_id = -1
        if self.i < self.n and self._b() != 41:
            if self._b() == 123 and self.i + 1 < self.n and self._at(self.i + 1) == 35:
                self._skip_group(123, 125)
            else:
                var saved = self.templ
                self.templ = False
                default_id = self.parse_value(doc, tab, cat)
                self.templ = saved
                if default_id < 0:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.skip_ws()
        self._expect(41)
        var rel = len(self.param_kind) - self.cur_param0
        self.param_kind.append(0)
        self.param_default.append(default_id)
        var hole = IonNode(K_HOLE)
        hole.a = rel
        hole.b = default_id
        return doc._add(hole)

    def _skip_group(mut self, open: Int, close: Int) raises DecodeError:
        if self.i >= self.n or self._b() != open:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var depth = 0
        while self.i < self.n:
            var c = self._b()
            if c == 34 or c == 39:
                var long = self._starts_long()
                _ = self._quoted(c, long)
                continue
            self.i += 1
            if c == open:
                depth += 1
            elif c == close:
                depth -= 1
                if depth == 0:
                    return
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _directive11(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        self.skip_ws()
        var op = self._ident_text()
        if op == "set_symbols":
            tab.reset_system()
            self._add_symbol_texts(doc, tab)
        elif op == "add_symbols":
            self._add_symbol_texts(doc, tab)
        elif op == "set_macros" or op == "add_macros":
            if op == "set_macros":
                self._clear_macros()
            var saved = self.templ
            self.templ = True
            while True:
                self.skip_ws()
                if self.i < self.n and self._b() == 41:
                    break
                var param0 = len(self.param_kind)
                self.cur_param0 = param0
                var node = self._sexp(doc, tab, cat)
                self._define_macro(doc, node, param0)
            self.templ = saved
        elif op == "use":
            self._use_module(doc, tab, cat)
        elif op == "module" or op == "import" or op == "encoding":
            self._skip_directive_rest()
        else:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.skip_ws()
        self._expect(41)
        return -1

    def _add_symbol_texts(mut self, mut doc: IonDoc, mut tab: LocalTab) raises DecodeError:
        while True:
            self.skip_ws()
            if self.i < self.n and self._b() == 41:
                return
            var text = self._symbol_text(doc)
            _ = tab.add_text(text)

    def _symbol_text(mut self, mut doc: IonDoc) raises DecodeError -> String:
        self.skip_ws()
        if self.i >= self.n:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var c = self._b()
        var long = self._starts_long()
        if c == 34 or long:
            var node = self._string(doc, long)
            return doc.text_at(node)
        if c == 39:
            var raw = self._quoted(39, False)
            return String(unsafe_from_utf8=raw)
        return self._ident_text()

    def _use_module(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError:
        self.skip_ws()
        var name_node = self._string(doc, self._starts_long())
        var name = doc.text_at(name_node)
        var version = 1
        self.skip_ws()
        if self.i < self.n and self._b() >= 48 and self._b() <= 57:
            var num = self.parse_value(doc, tab, cat)
            version = _doc_int(doc, num, self.i)
        var idx = cat.exact(name, version)
        if idx < 0:
            raise DecodeError(DecodeError.KIND_SYMBOL, self.i)
        var n = len(cat.tables[idx].texts)
        var k = 0
        while k < n:
            if cat.tables[idx].gap[k]:
                _ = tab.add_gap()
            else:
                _ = tab.add_text(cat.tables[idx].texts[k])
            k += 1

    def _skip_directive_rest(mut self) raises DecodeError:
        var depth = 1
        while self.i < self.n and depth > 0:
            var c = self._b()
            if c == 34 or c == 39:
                var long = self._starts_long()
                _ = self._quoted(c, long)
                continue
            self.i += 1
            if c == 40:
                depth += 1
            elif c == 41:
                depth -= 1
        if depth != 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.i -= 1

    def _define_macro(mut self, doc: IonDoc, id: Int, param0: Int) raises DecodeError:
        var n = doc.nodes[id]
        if n.kind != K_SEXP or n.nchild != 2:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var name_id = doc.child_at(id, 0)
        var body = doc.child_at(id, 1)
        if doc.nodes[name_id].kind != K_SYMBOL or doc.nodes[body].kind == K_HOLE:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.macro_name.append(doc.sym_text(doc.nodes[name_id].a))
        self.macro_root.append(body)
        self.macro_param_at.append(param0)
        self.macro_nparam.append(len(self.param_kind) - param0)

    def _invoke(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog, name: String) raises DecodeError -> Int:
        var addr = self._macro_addr(name)
        var nparam = self.macro_nparam[addr]
        var args = List[Int]()
        var p = 0
        while p < nparam:
            self.skip_ws()
            if self._at_absent():
                self._eat_absent()
                args.append(-1)
            else:
                var arg = self.parse_value(doc, tab, cat)
                if arg < 0:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                args.append(arg)
            p += 1
        self.skip_ws()
        self._expect(41)
        return self._expand(doc, self.macro_root[addr], args)

    def _macro_addr(self, name: String) raises DecodeError -> Int:
        var bytes = name.as_bytes()
        if len(bytes) > 1 and Int(bytes[0]) == 36:
            var addr = 0
            var k = 1
            while k < len(bytes):
                var ch = Int(bytes[k])
                if ch < 48 or ch > 57:
                    addr = -1
                    break
                addr = addr * 10 + ch - 48
                k += 1
            if addr >= 0:
                if addr >= len(self.macro_root):
                    raise DecodeError(DecodeError.KIND_SYMBOL, self.i)
                return addr
        var i = 0
        while i < len(self.macro_name):
            if self.macro_name[i] == name:
                return i
            i += 1
        raise DecodeError(DecodeError.KIND_SYMBOL, self.i)

    def _at_absent(self) -> Bool:
        if self.i + 2 >= self.n or self._b() != 40 or self._at(self.i + 1) != 58:
            return False
        var k = self.i + 2
        while k < self.n and _ws(self._at(k)):
            k += 1
        return k < self.n and self._at(k) == 41

    def _eat_absent(mut self) raises DecodeError:
        self.i += 2
        self.skip_ws()
        self._expect(41)

    def _expand(mut self, mut doc: IonDoc, id: Int, args: List[Int]) raises DecodeError -> Int:
        var n = doc.nodes[id]
        if n.kind == K_HOLE:
            var out = -1
            if n.a < len(args) and args[n.a] >= 0:
                out = args[n.a]
            elif n.b >= 0:
                out = self._expand(doc, n.b, args)
            if out < 0:
                return -1
            if n.ann_n == 0:
                return out
            var node = doc.nodes[out]
            var cloned = doc._add(node)
            var anns = List[Int]()
            var k = 0
            while k < n.ann_n:
                anns.append(doc.anns[n.ann + k])
                k += 1
            doc.set_anns(cloned, anns^)
            return cloned
        if n.kind == K_LIST or n.kind == K_SEXP or n.kind == K_STRUCT:
            var nid = doc.start_container(n.kind)
            if n.ann_n > 0:
                var anns = List[Int]()
                var k = 0
                while k < n.ann_n:
                    anns.append(doc.anns[n.ann + k])
                    k += 1
                doc.set_anns(nid, anns^)
            var e = n.child
            var seen = 0
            while seen < n.nchild:
                var edge = doc.edges[e]
                var child = self._expand(doc, edge.child, args)
                if child >= 0:
                    doc.add_child(nid, child, edge.field)
                e = edge.next
                seen += 1
            return nid
        return id


def _doc_int(doc: IonDoc, id: Int, offset: Int) raises DecodeError -> Int:
    var n = doc.nodes[id]
    if n.kind != K_INT or n.c != 0 or n.b > 1:
        raise DecodeError(DecodeError.KIND_RANGE, offset)
    if n.b == 0:
        return 0
    return Int(doc.limbs[n.a])


def _clob_ok(c: Int) -> Bool:
    if c >= 32 and c <= 127:
        return True
    return c == 9 or c == 10 or c == 11 or c == 12 or c == 13


def _b64_char(c: Int) -> Int:
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


def _b64(chars: List[Byte], offset: Int) raises DecodeError -> List[Byte]:
    var n = len(chars)
    var out = List[Byte]()
    if n == 0:
        return out^
    var pad = 0
    var i = n - 1
    while i >= 0 and Int(chars[i]) == 61:
        pad += 1
        i -= 1
    if pad > 2 or (n % 4) != 0:
        raise DecodeError(DecodeError.KIND_SYNTAX, offset)
    i = 0
    while i < n - pad:
        if Int(chars[i]) == 61 or _b64_char(Int(chars[i])) < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, offset)
        i += 1
    var k = 0
    while k < n:
        var c0 = _b64_char(Int(chars[k]))
        var c1 = _b64_char(Int(chars[k + 1]))
        var c2 = 0
        var c3 = 0
        if Int(chars[k + 2]) != 61:
            c2 = _b64_char(Int(chars[k + 2]))
        if Int(chars[k + 3]) != 61:
            c3 = _b64_char(Int(chars[k + 3]))
        if c0 < 0 or c1 < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, offset)
        var v = (c0 << 18) | (c1 << 12) | (c2 << 6) | c3
        out.append(Byte((v >> 16) & 255))
        if Int(chars[k + 2]) != 61:
            out.append(Byte((v >> 8) & 255))
        if Int(chars[k + 3]) != 61:
            out.append(Byte(v & 255))
        k += 4
    return out^


def _utf8_from_wide[origin: ImmOrigin](raw: Span[Byte, origin]) raises DecodeError -> List[Byte]:
    var out = List[Byte]()
    var width = 1
    var be = True
    if len(raw) >= 4 and Int(raw[0]) == 0 and Int(raw[1]) == 0 and Int(raw[2]) == 0:
        width = 4
    elif len(raw) >= 4 and Int(raw[0]) != 0 and Int(raw[1]) == 0 and Int(raw[2]) == 0 and Int(raw[3]) == 0:
        width = 4
        be = False
    elif len(raw) >= 2 and Int(raw[0]) == 0 and Int(raw[1]) != 0:
        width = 2
    elif len(raw) >= 2 and Int(raw[0]) != 0 and Int(raw[1]) == 0:
        width = 2
        be = False
    if width == 1:
        var i = 0
        while i < len(raw):
            out.append(raw[i])
            i += 1
        return out^
    if len(raw) % width != 0:
        raise DecodeError(DecodeError.KIND_UTF8, 0)
    var i = 0
    while i < len(raw):
        var cp = 0
        var b = 0
        while b < width:
            var idx = i + b
            if not be:
                idx = i + width - 1 - b
            cp = (cp << 8) | Int(raw[idx])
            b += 1
        i += width
        if width == 2 and cp >= 0xD800 and cp <= 0xDBFF and i + 1 < len(raw):
            var low = (Int(raw[i + 1]) << 8) | Int(raw[i])
            if be:
                low = (Int(raw[i]) << 8) | Int(raw[i + 1])
            if low >= 0xDC00 and low <= 0xDFFF:
                cp = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                i += 2
        append_utf8(out, cp, i)
    return out^


def _is_wide[origin: ImmOrigin](raw: Span[Byte, origin]) -> Bool:
    if len(raw) >= 4 and Int(raw[0]) == 0 and Int(raw[1]) == 0 and Int(raw[2]) == 0:
        return True
    if len(raw) >= 4 and Int(raw[0]) != 0 and Int(raw[1]) == 0 and Int(raw[2]) == 0 and Int(raw[3]) == 0:
        return True
    if len(raw) >= 2 and Int(raw[0]) == 0 and Int(raw[1]) != 0:
        return True
    if len(raw) >= 2 and Int(raw[0]) != 0 and Int(raw[1]) == 0:
        return True
    return False


def _ascii[origin: ImmOrigin](raw: Span[Byte, origin]) -> Bool:
    var i = 0
    var n = len(raw)
    var bits = 0
    while i + 4 <= n:
        bits = bits | Int(raw[i]) | Int(raw[i + 1]) | Int(raw[i + 2]) | Int(raw[i + 3])
        i += 4
    while i < n:
        bits = bits | Int(raw[i])
        i += 1
    return (bits & 128) == 0


def decode_text[origin: ImmOrigin](raw: Span[Byte, origin], cat: Catalog) raises DecodeError -> IonDoc:
    if len(raw) >= 3 and Int(raw[0]) == 0xEF and Int(raw[1]) == 0xBB and Int(raw[2]) == 0xBF:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    var doc = IonDoc()
    doc.reserve(len(raw) // 2 + 8)
    var tab = LocalTab()
    if _is_wide(raw):
        var utf = _utf8_from_wide(raw)
        validate_utf8(Span(utf), 0)
        var parser = TextParser(Span(utf))
        parser.read_all(doc, tab, cat)
        return doc^
    if not _ascii(raw):
        validate_utf8(raw, 0)
    var parser = TextParser(raw)
    parser.read_all(doc, tab, cat)
    return doc^


def adopt_text(mut doc: IonDoc, text: String) raises DecodeError -> Int:
    """Parse one Ion text value into `doc` and return its node id."""
    var raw = text.as_bytes()
    var tab = LocalTab()
    var cat = Catalog()
    var parser = TextParser(raw)
    var id = parser.parse_value(doc, tab, cat)
    if id < 0:
        raise DecodeError(DecodeError.KIND_SYNTAX, 0)
    return id
