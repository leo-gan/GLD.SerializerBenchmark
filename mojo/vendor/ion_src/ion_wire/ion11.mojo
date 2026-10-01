from std.collections import List, Span

from ion_runtime.doc import (
    K_BLOB,
    K_BOOL,
    K_CLOB,
    K_DECIMAL,
    K_FLOAT,
    K_INT,
    K_LIST,
    K_NULL,
    K_SEXP,
    K_STRING,
    K_STRUCT,
    K_SYMBOL,
    K_HOLE,
    K_TIMESTAMP,
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
from ion_runtime.intx import BigInt, big_from_u64
from ion_runtime.symtab import Catalog, LocalTab
from ion_runtime.utf8 import string_from_span
from ion_wire.lst import sym_from_sid


def flex_uint[origin: ImmOrigin](raw: Span[Byte, origin], mut i: Int) raises DecodeError -> Int:
    """Ion 1.1 FlexUInt. The low bits are `N-1` zeros followed by a one; the rest is the magnitude."""
    var start = i
    var acc = UInt64(0)
    var shift = UInt64(0)
    var nread = 0
    while nread < 8:
        if i >= len(raw):
            raise DecodeError(DecodeError.KIND_EOF, start)
        var b = UInt64(Int(raw[i]))
        i += 1
        nread += 1
        acc = acc | (b << shift)
        shift += 8
        if acc == 0:
            continue
        var low = 0
        var probe = acc
        while (probe & 1) == 0:
            probe = probe >> 1
            low += 1
        var width = low + 1
        if nread >= width:
            return Int(acc >> UInt64(width))
    raise DecodeError(DecodeError.KIND_RANGE, start)


def flex_int[origin: ImmOrigin](raw: Span[Byte, origin], mut i: Int) raises DecodeError -> Int:
    var start = i
    var acc = UInt64(0)
    var shift = UInt64(0)
    var nread = 0
    while nread < 8:
        if i >= len(raw):
            raise DecodeError(DecodeError.KIND_EOF, start)
        var b = UInt64(Int(raw[i]))
        i += 1
        nread += 1
        acc = acc | (b << shift)
        shift += 8
        if acc == 0:
            continue
        var low = 0
        var probe = acc
        while (probe & 1) == 0:
            probe = probe >> 1
            low += 1
        var width = low + 1
        if nread >= width:
            var mag_bits = 7 * width
            var mag = acc >> UInt64(width)
            var signbit = UInt64(1) << UInt64(mag_bits - 1)
            if (mag & signbit) != 0:
                var full = (UInt64(1) << UInt64(mag_bits)) - mag
                return 0 - Int(full)
            return Int(mag)
    raise DecodeError(DecodeError.KIND_RANGE, start)


def write_flex_int(mut buf: List[Byte], v: Int):
    """Ion 1.1 FlexInt. The magnitude bits are a 7*N-bit two's-complement value."""
    var n = 1
    while n < 8:
        var half = UInt64(1) << UInt64(7 * n - 1)
        var min_n = 0 - Int(half)
        var max_n = Int(half - UInt64(1))
        if v >= min_n and v <= max_n:
            break
        n += 1
    var mask = (UInt64(1) << UInt64(7 * n)) - UInt64(1)
    var pattern = UInt64(v) & mask
    var bits = pattern << UInt64(n)
    bits = bits | (UInt64(1) << UInt64(n - 1))
    var k = 0
    while k < n:
        buf.append(Byte(Int((bits >> UInt64(k * 8)) & UInt64(255))))
        k += 1


def write_flex_uint(mut buf: List[Byte], v: Int):
    var n = 1
    var limit = 128
    var x = v
    if x < 0:
        x = 0
    while x >= limit and n < 8:
        n += 1
        limit = limit * 128
    var bits = UInt64(x) << UInt64(n)
    bits = bits | (UInt64(1) << UInt64(n - 1))
    var k = 0
    while k < n:
        buf.append(Byte(Int((bits >> UInt64(k * 8)) & UInt64(255))))
        k += 1


def _fixed_int[origin: ImmOrigin](raw: Span[Byte, origin], mut i: Int, n: Int) raises DecodeError -> Int:
    if n == 0:
        return 0
    if i + n > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, i)
    var acc = 0
    var k = 0
    while k < n:
        acc = acc | (Int(raw[i + k]) << (k * 8))
        k += 1
    i += n
    var sign = 1 << (n * 8 - 1)
    if (acc & sign) != 0:
        var mod = 1 << (n * 8)
        return acc - mod
    return acc


def _take_utf[origin: ImmOrigin](raw: Span[Byte, origin], mut i: Int, n: Int) raises DecodeError -> String:
    if i + n > len(raw):
        raise DecodeError(DecodeError.KIND_EOF, i)
    var start = i
    i += n
    return string_from_span(raw[start:i], start)


struct Macro:
    var name: String
    var template: Int

    def __init__(out self):
        self.name = String()
        self.template = -1


struct Ion11[origin: ImmOrigin]:
    """Ion 1.1 binary reader. Macro templates live in the caller's document and are not top-level values."""

    var raw: Span[Byte, Self.origin]
    var i: Int
    var templ: Bool
    var cur_param0: Int
    var macro_name: List[String]
    var macro_root: List[Int]
    var macro_param_at: List[Int]
    var macro_nparam: List[Int]
    var param_kind: List[Int]
    var param_default: List[Int]

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.templ = False
        self.cur_param0 = 0
        self.macro_name = List[String]()
        self.macro_root = List[Int]()
        self.macro_param_at = List[Int]()
        self.macro_nparam = List[Int]()
        self.param_kind = List[Int]()
        self.param_default = List[Int]()

    def read_top(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError:
        while self.i < len(self.raw):
            if self._bvm():
                tab.reset_system()
                self._clear_macros()
                continue
            var id = self.value(doc, tab, False, cat)
            if id >= 0:
                doc.add_top(id)

    def _clear_macros(mut self):
        self.macro_name = List[String]()
        self.macro_root = List[Int]()
        self.macro_param_at = List[Int]()
        self.macro_nparam = List[Int]()
        self.param_kind = List[Int]()
        self.param_default = List[Int]()

    def _bvm(mut self) -> Bool:
        if self.i + 3 >= len(self.raw):
            return False
        if Int(self.raw[self.i]) != 0xE0 or Int(self.raw[self.i + 3]) != 0xEA:
            return False
        if Int(self.raw[self.i + 1]) != 1:
            return False
        self.i += 4
        return True

    def value(mut self, mut doc: IonDoc, mut tab: LocalTab, in_e: Bool, cat: Catalog) raises DecodeError -> Int:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var op = Int(self.raw[self.i])
        self.i += 1
        if op == 0xEC:
            return -1
        if op == 0xED:
            var n = flex_uint(self.raw, self.i)
            if self.i + n > len(self.raw):
                raise DecodeError(DecodeError.KIND_EOF, self.i)
            self.i += n
            return -1
        if op == 0xEF:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if op == 0x8E:
            return doc.add_null(0)
        if op == 0x8F:
            return self._typed_null(doc)
        if op >= 0x60 and op <= 0x68:
            if op == 0x60:
                return doc.add_i64(0)
            var v = _fixed_int(self.raw, self.i, op - 0x60)
            return doc.add_i64(Int64(v))
        if op == 0xF5:
            var n = flex_uint(self.raw, self.i)
            var v = _fixed_int(self.raw, self.i, n)
            return doc.add_i64(Int64(v))
        if op == 0x6E:
            return doc.add_bool(True)
        if op == 0x6F:
            return doc.add_bool(False)
        if op == 0x6A:
            return doc.add_float(0, 0)
        if op >= 0x6B and op <= 0x6D:
            var n = 2
            if op == 0x6C:
                n = 4
            if op == 0x6D:
                n = 8
            return self._float(doc, n)
        if op >= 0x70 and op <= 0x7F:
            return self._decimal(doc, op - 0x70)
        if op == 0xF6:
            var n = flex_uint(self.raw, self.i)
            return self._decimal(doc, n)
        if op >= 0x90 and op <= 0x9F:
            return doc.add_string(self._text(op - 0x90))
        if op == 0xF8:
            var n = flex_uint(self.raw, self.i)
            return doc.add_string(self._text(n))
        if op >= 0xA0 and op <= 0xAF:
            return doc.add_symbol_text(self._text(op - 0xA0))
        if op == 0xF9:
            var n = flex_uint(self.raw, self.i)
            return doc.add_symbol_text(self._text(n))
        if op >= 0x50 and op <= 0x57:
            var hi = flex_uint(self.raw, self.i)
            var sid = (hi << 3) | (op - 0x50)
            return sym_from_sid(doc, tab, sid, self.i)
        if op == 0x58 or op == 0x59:
            self.i -= 1
            return self._annotated(doc, tab, cat)
        if op >= 0xB0 and op <= 0xBF:
            return self._container(doc, tab, K_LIST, op - 0xB0, False, cat)
        if op == 0xFA:
            var n = flex_uint(self.raw, self.i)
            return self._container(doc, tab, K_LIST, n, False, cat)
        if op == 0xF0:
            return self._container(doc, tab, K_LIST, -1, True, cat)
        if op >= 0xC0 and op <= 0xCF:
            return self._container(doc, tab, K_SEXP, op - 0xC0, False, cat)
        if op == 0xFB:
            var n = flex_uint(self.raw, self.i)
            return self._container(doc, tab, K_SEXP, n, False, cat)
        if op == 0xF1:
            return self._container(doc, tab, K_SEXP, -1, True, cat)
        if op == 0xD0:
            return doc.start_container(K_STRUCT)
        if (op >= 0xD2 and op <= 0xDF) or op == 0xFC or op == 0xFD:
            var n = op - 0xD0
            var flex = False
            if op == 0xFC or op == 0xFD:
                n = flex_uint(self.raw, self.i)
            if op == 0xFD:
                flex = True
            return self._struct(doc, tab, n, False, flex or op == 0xFD, cat)
        if op == 0xF2 or op == 0xF3:
            return self._struct(doc, tab, -1, True, op == 0xF3, cat)
        if op == 0xFE or op == 0xFF:
            var n = flex_uint(self.raw, self.i)
            var kind = K_BLOB
            if op == 0xFF:
                kind = K_CLOB
            return self._bytes(doc, kind, n)
        if op >= 0x80 and op <= 0x8C:
            return self._short_time(doc, op)
        if op == 0xF7:
            return self._long_time(doc)
        if op == 0xE0:
            if in_e:
                return -2
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if op == 0xE9 or op == 0xEA or op == 0xEB:
            return self._placeholder(doc, tab, op, cat)
        if op >= 0xE1 and op <= 0xE8:
            self._directive(doc, tab, op, cat)
            return -1
        if self.templ and (op < 0x48 or (op >= 0x48 and op <= 0x4F) or op == 0xF4):
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if op < 0x48 or (op >= 0x48 and op <= 0x4F) or op == 0xF4:
            return self._eexp(doc, tab, op, cat)
        _ = big_from_u64
        raise DecodeError(DecodeError.KIND_VERSION, self.i)

    def _text(mut self, n: Int) raises DecodeError -> String:
        return _take_utf(self.raw, self.i, n)

    def _typed_null(mut self, mut doc: IonDoc) raises DecodeError -> Int:
        if self.i >= len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var t = Int(self.raw[self.i])
        self.i += 1
        if t == 1:
            return doc.add_null(K_BOOL)
        if t == 2:
            return doc.add_null(K_INT)
        if t == 3:
            return doc.add_null(K_FLOAT)
        if t == 4:
            return doc.add_null(K_DECIMAL)
        if t == 5:
            return doc.add_null(K_TIMESTAMP)
        if t == 6:
            return doc.add_null(K_STRING)
        if t == 7:
            return doc.add_null(K_SYMBOL)
        if t == 8:
            return doc.add_null(K_BLOB)
        if t == 9:
            return doc.add_null(K_CLOB)
        if t == 10:
            return doc.add_null(K_LIST)
        if t == 11:
            return doc.add_null(K_SEXP)
        if t == 12:
            return doc.add_null(K_STRUCT)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _float(mut self, mut doc: IonDoc, n: Int) raises DecodeError -> Int:
        if self.i + n > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var bits = UInt64(0)
        var k = 0
        while k < n:
            bits = bits | (UInt64(Int(self.raw[self.i + k])) << UInt64(k * 8))
            k += 1
        self.i += n
        var width = n
        if n == 2:
            width = 2
        return doc.add_float(width, bits)

    def _decimal(mut self, mut doc: IonDoc, n: Int) raises DecodeError -> Int:
        if n == 0:
            return doc.add_decimal(BigInt(), False, 0)
        var end = self.i + n
        if end > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var exp = flex_int(self.raw, self.i)
        var coef = BigInt()
        var neg = False
        if self.i < end:
            var v = _fixed_int(self.raw, self.i, end - self.i)
            if v < 0:
                neg = True
                v = 0 - v
            else:
                neg = True
                if v != 0:
                    neg = False
            coef = big_from_u64(UInt64(v), False)
        return doc.add_decimal(coef^, neg, exp)

    def _bytes(mut self, mut doc: IonDoc, kind: Int, n: Int) raises DecodeError -> Int:
        if self.i + n > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var buf = List[Byte]()
        var k = 0
        while k < n:
            buf.append(self.raw[self.i + k])
            k += 1
        self.i += n
        return doc.add_bytes(kind, buf^)

    def _container(mut self, mut doc: IonDoc, mut tab: LocalTab, kind: Int, n: Int, delim: Bool, cat: Catalog) raises DecodeError -> Int:
        var id = doc.start_container(kind)
        var end = len(self.raw)
        if not delim:
            end = self.i + n
            if end > len(self.raw):
                raise DecodeError(DecodeError.KIND_EOF, self.i)
        while self.i < end:
            if delim and self.i < len(self.raw) and Int(self.raw[self.i]) == 0xEF:
                self.i += 1
                return id
            var child = self.value(doc, tab, False, cat)
            if child >= 0:
                doc.add_child(id, child, -1)
        return id

    def _field_id(mut self, mut doc: IonDoc, mut tab: LocalTab, mode: Bool, cat: Catalog) raises DecodeError -> Int:
        if mode:
            var iv = flex_int(self.raw, self.i)
            if iv >= 0:
                var sym = sym_from_sid(doc, tab, iv, self.i)
                return doc.nodes[sym].a
            var nbytes = -1 - iv
            return doc.nodes[doc.add_symbol_text(self._text(nbytes))].a
        var sid = flex_uint(self.raw, self.i)
        var sym = sym_from_sid(doc, tab, sid, self.i)
        _ = cat
        return doc.nodes[sym].a

    def _struct(mut self, mut doc: IonDoc, mut tab: LocalTab, n: Int, delim: Bool, flex: Bool, cat: Catalog) raises DecodeError -> Int:
        var id = doc.start_container(K_STRUCT)
        var end = len(self.raw)
        var mode = flex
        if not delim:
            end = self.i + n
        while self.i < end:
            if delim and Int(self.raw[self.i]) == 0xEF:
                self.i += 1
                return id
            var field = self._field_id(doc, tab, mode, cat)
            if self.i < len(self.raw) and (Int(self.raw[self.i]) == 0xEE or Int(self.raw[self.i]) == 0xEC or Int(self.raw[self.i]) == 0xEF):
                var marker = Int(self.raw[self.i])
                self.i += 1
                if marker == 0xEE:
                    mode = not mode
                if marker == 0xEF:
                    return id
                continue
            var child = self.value(doc, tab, False, cat)
            if child >= 0:
                doc.add_child(id, child, field)
        return id

    def _annotated(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        var anns = List[Int]()
        while self.i < len(self.raw):
            var op = Int(self.raw[self.i])
            if op == 0x58:
                self.i += 1
                var sid = flex_uint(self.raw, self.i)
                var sym = sym_from_sid(doc, tab, sid, self.i)
                anns.append(doc.nodes[sym].a)
            elif op == 0x59:
                self.i += 1
                var n = flex_uint(self.raw, self.i)
                var sym = doc.add_symbol_text(self._text(n))
                anns.append(doc.nodes[sym].a)
            else:
                break
        if len(anns) == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var id = self.value(doc, tab, False, cat)
        if id < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        doc.set_anns(id, anns^)
        return id

    def _directive(mut self, mut doc: IonDoc, mut tab: LocalTab, op: Int, cat: Catalog) raises DecodeError:
        if op == 0xE1:
            tab.reset_system()
        if op == 0xE3:
            self._clear_macros()
        var saved = self.templ
        if op == 0xE3 or op == 0xE4:
            self.templ = True
        var use_name = String()
        var use_ver = 1
        var saw_use = False
        while self.i < len(self.raw) and Int(self.raw[self.i]) != 0xEF:
            var param0 = len(self.param_kind)
            self.cur_param0 = param0
            var v = self.value(doc, tab, False, cat)
            if op == 0xE1 or op == 0xE2:
                if v >= 0 and doc.nodes[v].kind == K_STRING:
                    _ = tab.add_text(doc.text_at(v))
            if (op == 0xE3 or op == 0xE4) and v >= 0:
                self._define_macro(doc, v, param0)
            if op == 0xE5 and v >= 0:
                if not saw_use and doc.nodes[v].kind == K_STRING:
                    use_name = doc.text_at(v)
                    saw_use = True
                elif doc.nodes[v].kind == K_INT:
                    use_ver = _positive_int(doc, v)
        self.templ = saved
        if op == 0xE5:
            _import_named(tab, cat, use_name, use_ver, self.i)
        if self.i < len(self.raw) and Int(self.raw[self.i]) == 0xEF:
            self.i += 1

    def _take_bits(mut self, n: Int) raises DecodeError -> Int:
        """Remember the start of an `n`-byte little-endian body and advance past it."""
        if n < 0 or self.i + n > len(self.raw):
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var start = self.i
        self.i += n
        return start

    def _field(self, start: Int, at: Int, width: Int) -> Int:
        var v = 0
        var k = 0
        while k < width:
            var pos = at + k
            var b = Int(self.raw[start + (pos // 8)])
            var bit = (b >> (pos % 8)) & 1
            v = v | (bit << k)
            k += 1
        return v

    def _finish_time(mut self, mut doc: IonDoc, when: IonTime) raises DecodeError -> Int:
        if when.month < 1 or when.month > 12:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if when.prec >= PREC_DAY:
            if when.day < 1 or when.day > _dim11(when.year, when.month):
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if when.prec >= PREC_MIN:
            if when.hour > 23 or when.minute > 59:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if when.prec >= PREC_SEC and when.second > 59:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if when.year < 1 or when.year > 999999999:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        return doc.add_time(when)

    def _put_frac(self, mut doc: IonDoc, mut when: IonTime, coef: Int, exp: Int):
        when.prec = PREC_FRAC
        when.frac_exp = exp
        var big = big_from_u64(UInt64(coef), False)
        when.frac_at = len(doc.limbs)
        when.frac_len = len(big.limbs)
        var t = 0
        while t < len(big.limbs):
            doc.limbs.append(big.limbs[t])
            t += 1

    def _short_time(mut self, mut doc: IonDoc, op: Int) raises DecodeError -> Int:
        var n = 1
        if op != 0x80:
            if op == 0x81 or op == 0x82:
                n = 2
            elif op == 0x83:
                n = 4
            elif op == 0x84 or op == 0x88 or op == 0x89:
                n = 5
            elif op == 0x85:
                n = 6
            elif op == 0x86 or op == 0x8A:
                n = 7
            elif op == 0x87 or op == 0x8B:
                n = 8
            else:
                n = 9
        var start = self._take_bits(n)
        var when = IonTime()
        when.year = 1970 + self._field(start, 0, 7)
        when.prec = PREC_YEAR
        when.unknown = True
        when.off = 0
        if op == 0x80:
            return self._finish_time(doc, when)
        when.month = self._field(start, 7, 4)
        when.prec = PREC_MONTH
        if op == 0x81:
            return self._finish_time(doc, when)
        when.day = self._field(start, 11, 5)
        when.prec = PREC_DAY
        if op == 0x82:
            return self._finish_time(doc, when)
        when.hour = self._field(start, 16, 5)
        when.minute = self._field(start, 21, 6)
        when.prec = PREC_MIN
        var known = op >= 0x88
        if known:
            var q = self._field(start, 27, 7)
            if q == 127:
                when.unknown = True
                when.off = 0
            else:
                when.unknown = False
                when.off = (q - 56) * 15
        else:
            var u = self._field(start, 27, 1)
            if u == 0:
                when.unknown = True
                when.off = 0
            else:
                when.unknown = False
                when.off = 0
        if op == 0x83 or op == 0x88:
            return self._finish_time(doc, when)
        var sec_at = 28
        var frac_at = 34
        if known:
            sec_at = 34
            frac_at = 40
        when.second = self._field(start, sec_at, 6)
        when.prec = PREC_SEC
        var digits = 0
        var fbits = 0
        if op == 0x85 or op == 0x8A:
            digits = 3
            fbits = 10
        elif op == 0x86 or op == 0x8B:
            digits = 6
            fbits = 20
        elif op == 0x87 or op == 0x8C:
            digits = 9
            fbits = 30
        if digits != 0:
            var coef = self._field(start, frac_at, fbits)
            self._put_frac(doc, when, coef, 0 - digits)
        return self._finish_time(doc, when)

    def _long_time(mut self, mut doc: IonDoc) raises DecodeError -> Int:
        var n = flex_uint(self.raw, self.i)
        if n < 2 or n == 4 or n == 5:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var start = self._take_bits(n)
        var when = IonTime()
        when.year = self._field(start, 0, 14)
        when.prec = PREC_YEAR
        when.unknown = True
        when.off = 0
        when.month = 1
        when.day = 1
        if n == 2:
            return self._finish_time(doc, when)
        when.month = self._field(start, 14, 4)
        when.prec = PREC_MONTH
        if n == 3:
            var day = self._field(start, 18, 5)
            if day != 0:
                when.day = day
                when.prec = PREC_DAY
            return self._finish_time(doc, when)
        when.day = self._field(start, 18, 5)
        when.hour = self._field(start, 23, 5)
        when.minute = self._field(start, 28, 6)
        when.prec = PREC_MIN
        var raw_off = self._field(start, 34, 12)
        if raw_off == 4095:
            when.unknown = True
            when.off = 0
        else:
            when.unknown = False
            when.off = raw_off - 1440
        if n == 6:
            return self._finish_time(doc, when)
        when.second = self._field(start, 46, 6)
        when.prec = PREC_SEC
        if n == 7:
            return self._finish_time(doc, when)
        var frac_at = start + 7
        var saved = self.i
        self.i = frac_at
        var scale = flex_uint(self.raw, self.i)
        if scale == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var coef_n = (start + n) - self.i
        if coef_n < 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var coef = 0
        var k = 0
        while k < coef_n:
            coef = coef | (Int(self.raw[self.i + k]) << (k * 8))
            k += 1
        self.i = saved
        if scale > 0 and coef >= 1:
            var lim = 1
            var p = 0
            while p < scale:
                if lim > 100000000:
                    break
                lim = lim * 10
                p += 1
            if p == scale and coef >= lim:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self._put_frac(doc, when, coef, 0 - scale)
        return self._finish_time(doc, when)

    def _placeholder(mut self, mut doc: IonDoc, mut tab: LocalTab, op: Int, cat: Catalog) raises DecodeError -> Int:
        if not self.templ:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var rel = len(self.param_kind) - self.cur_param0
        var kind = 0
        var default_id = -1
        if op == 0xEB:
            if self.i >= len(self.raw):
                raise DecodeError(DecodeError.KIND_EOF, self.i)
            kind = Int(self.raw[self.i])
            self.i += 1
        if op == 0xEA:
            var saved = self.templ
            self.templ = False
            while self.i < len(self.raw) and (Int(self.raw[self.i]) == 0xEC or Int(self.raw[self.i]) == 0xED):
                _ = self.value(doc, tab, False, cat)
            default_id = self.value(doc, tab, False, cat)
            self.templ = saved
            if default_id < 0:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        self.param_kind.append(kind)
        self.param_default.append(default_id)
        var hole = IonNode(K_HOLE)
        hole.a = rel
        hole.b = default_id
        return doc._add(hole)

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

    def _eexp(mut self, mut doc: IonDoc, mut tab: LocalTab, op: Int, cat: Catalog) raises DecodeError -> Int:
        var addr = op
        var limit = len(self.raw)
        if op >= 0x48 and op <= 0x4F:
            var hi = flex_uint(self.raw, self.i)
            addr = ((hi << 3) | (op - 0x48)) + 72
        if op == 0xF4:
            addr = flex_uint(self.raw, self.i)
            var nbytes = flex_uint(self.raw, self.i)
            limit = self.i + nbytes
            if limit > len(self.raw):
                raise DecodeError(DecodeError.KIND_EOF, self.i)
        if addr < 0 or addr >= len(self.macro_root):
            raise DecodeError(DecodeError.KIND_SYMBOL, self.i)
        var nparam = self.macro_nparam[addr]
        var param_at = self.macro_param_at[addr]
        var args = List[Int]()
        var p = 0
        while p < nparam:
            while self.i < limit and Int(self.raw[self.i]) == 0xEC:
                self.i += 1
            if self.i >= limit:
                raise DecodeError(DecodeError.KIND_EOF, self.i)
            var kind = self.param_kind[param_at + p]
            if kind == 0:
                if Int(self.raw[self.i]) == 0xE0:
                    self.i += 1
                    args.append(-1)
                else:
                    var arg = self.value(doc, tab, True, cat)
                    if arg < 0:
                        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                    args.append(arg)
            else:
                args.append(self._tagless(doc, tab, kind))
            p += 1
        if op == 0xF4 and self.i != limit:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        return self._expand(doc, self.macro_root[addr], args)

    def _tagless(mut self, mut doc: IonDoc, mut tab: LocalTab, code: Int) raises DecodeError -> Int:
        if code == 0x60:
            return doc.add_i64(Int64(flex_int(self.raw, self.i)))
        if code == 0x61 or code == 0x62 or code == 0x64 or code == 0x68:
            var n = 1
            if code == 0x62:
                n = 2
            if code == 0x64:
                n = 4
            if code == 0x68:
                n = 8
            return doc.add_i64(Int64(_fixed_int(self.raw, self.i, n)))
        if code == 0xE0:
            return doc.add_i64(Int64(flex_uint(self.raw, self.i)))
        if code == 0xE1 or code == 0xE2 or code == 0xE4 or code == 0xE8:
            var n = 1
            if code == 0xE2:
                n = 2
            if code == 0xE4:
                n = 4
            if code == 0xE8:
                n = 8
            if self.i + n > len(self.raw):
                raise DecodeError(DecodeError.KIND_EOF, self.i)
            var acc = 0
            var k = 0
            while k < n:
                acc = acc | (Int(self.raw[self.i + k]) << (k * 8))
                k += 1
            self.i += n
            return doc.add_i64(Int64(acc))
        if code >= 0x6B and code <= 0x6D:
            var n = 2
            if code == 0x6C:
                n = 4
            if code == 0x6D:
                n = 8
            return self._float(doc, n)
        if code == 0x82 or code == 0x83 or code == 0x84 or code == 0x85 or code == 0x86 or code == 0x87:
            return self._short_time(doc, code)
        if code == 0xF8 or code == 0xF9 or code == 0x90:
            var n = flex_uint(self.raw, self.i)
            return doc.add_string(self._text(n))
        _ = tab
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

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
            if n.ann_n > 0:
                var node = doc.nodes[out]
                var cloned = doc._add(node)
                var anns = List[Int]()
                var k = 0
                while k < n.ann_n:
                    anns.append(doc.anns[n.ann + k])
                    k += 1
                doc.set_anns(cloned, anns^)
                return cloned
            return out
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


def _positive_int(doc: IonDoc, id: Int) -> Int:
    var n = doc.nodes[id]
    if n.kind != K_INT or n.c != 0 or n.b > 1:
        return 1
    if n.b == 0:
        return 0
    return Int(doc.limbs[n.a])


def _import_named(mut tab: LocalTab, cat: Catalog, name: String, version: Int, offset: Int) raises DecodeError:
    if name.byte_length() == 0:
        raise DecodeError(DecodeError.KIND_SYMBOL, offset)
    var idx = cat.exact(name, version)
    if idx < 0:
        raise DecodeError(DecodeError.KIND_SYMBOL, offset)
    var n = len(cat.tables[idx].texts)
    var k = 0
    while k < n:
        if cat.tables[idx].gap[k]:
            _ = tab.add_gap()
        else:
            _ = tab.add_text(cat.tables[idx].texts[k])
        k += 1


def _dim11(year: Int, month: Int) -> Int:
    if month == 2:
        if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
            return 29
        return 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31
