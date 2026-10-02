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
    IonDoc,
    IonTime,
    PREC_DAY,
    PREC_FRAC,
    PREC_MIN,
    PREC_MONTH,
    PREC_SEC,
    PREC_YEAR,
)
from ion_runtime.error import DecodeError
from ion_runtime.intx import BigInt, big_from_be, big_from_u64
from ion_runtime.symtab import Catalog, LocalTab
from ion_wire.ion11 import Ion11
from ion_wire.lst import apply_lst, is_local_table, sym_from_sid
from ion_wire.time import apply_offset


struct BinParser[origin: ImmOrigin]:
    var raw: Span[Byte, Self.origin]
    var i: Int
    var n: Int
    var depth: Int
    var cache_sid0: Int
    var cache_sym0: Int
    var cache_sid1: Int
    var cache_sym1: Int

    def __init__(out self, raw: Span[Byte, Self.origin]):
        self.raw = raw
        self.i = 0
        self.n = len(raw)
        self.depth = 0
        self.cache_sid0 = -1
        self.cache_sym0 = -1
        self.cache_sid1 = -1
        self.cache_sym1 = -1

    def _clear_sid_cache(mut self):
        self.cache_sid0 = -1
        self.cache_sid1 = -1

    def _b(mut self) raises DecodeError -> Int:
        if self.i >= self.n:
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var c = Int(self.raw[self.i])
        self.i += 1
        return c

    def _var_uint(mut self) raises DecodeError -> Int:
        var b0 = self._b()
        if (b0 & 0x80) != 0:
            return b0 & 0x7F
        var acc = b0 & 0x7F
        var k = 1
        while k < 10:
            var b = self._b()
            var piece = b & 0x7F
            if acc > 0x00FFFFFFFFFFFFFF // 128:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            acc = (acc << 7) | piece
            if (b & 0x80) != 0:
                return acc
            k += 1
        raise DecodeError(DecodeError.KIND_RANGE, self.i)

    def _var_int(mut self, mut neg0: Bool) raises DecodeError -> Int:
        neg0 = False
        var b = self._b()
        var neg = (b & 0x40) != 0
        var acc = b & 0x3F
        var guard = 0
        while (b & 0x80) == 0:
            guard += 1
            if guard > 10:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            b = self._b()
            if acc > 0x00FFFFFFFFFFFFFF // 128:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            acc = (acc << 7) | (b & 0x7F)
        if neg and acc == 0:
            neg0 = True
            return 0
        if neg:
            return 0 - acc
        return acc

    def _take(mut self, n: Int) raises DecodeError -> Span[Byte, Self.origin]:
        if n < 0 or self.i + n > self.n:
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var start = self.i
        self.i += n
        return self.raw[start:self.i]

    def _repr_len(mut self, ln: Int) raises DecodeError -> Int:
        if ln == 14:
            return self._var_uint()
        return ln

    def read_all(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError:
        if self.n == 0:
            return
        var ver = self._bvm()
        while self.i < self.n:
            if ver == 11:
                ver = self._read11(doc, tab, cat)
            else:
                ver = self._read10(doc, tab, cat)

    def _read10(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        while self.i < self.n:
            if self._at_bvm():
                var next = self._bvm()
                tab.reset_system()
                self._clear_sid_cache()
                return next
            var id = self._value(doc, tab, 10, False)
            if id < 0:
                continue
            if is_local_table(doc, id):
                apply_lst(doc, id, tab, cat, self.i)
                self._clear_sid_cache()
                continue
            doc.add_top(id)
        return 10

    def _read11(mut self, mut doc: IonDoc, mut tab: LocalTab, cat: Catalog) raises DecodeError -> Int:
        var r11 = Ion11(self.raw)
        r11.i = self.i
        while r11.i < self.n:
            self.i = r11.i
            if self._at_bvm():
                var next = self._bvm()
                tab.reset_system()
                self._clear_sid_cache()
                r11._clear_macros()
                if next != 11:
                    return next
                r11.i = self.i
                continue
            var id11 = r11.value(doc, tab, False, cat)
            self.i = r11.i
            if id11 >= 0 and not is_local_table(doc, id11):
                doc.add_top(id11)
        self.i = r11.i
        return 11

    def _at_bvm(self) -> Bool:
        if self.i + 3 >= self.n:
            return False
        return (
            Int(self.raw[self.i]) == 0xE0
            and Int(self.raw[self.i + 1]) == 0x01
            and Int(self.raw[self.i + 3]) == 0xEA
        )

    def _bvm(mut self) raises DecodeError -> Int:
        if self.i + 3 >= self.n:
            raise DecodeError(DecodeError.KIND_VERSION, self.i)
        if Int(self.raw[self.i]) != 0xE0 or Int(self.raw[self.i + 3]) != 0xEA or Int(self.raw[self.i + 1]) != 0x01:
            raise DecodeError(DecodeError.KIND_VERSION, self.i)
        var minor = Int(self.raw[self.i + 2])
        self.i += 4
        if minor == 0:
            return 10
        if minor == 1:
            return 11
        raise DecodeError(DecodeError.KIND_VERSION, self.i)

    def _value(mut self, mut doc: IonDoc, mut tab: LocalTab, ver: Int, in_ann: Bool) raises DecodeError -> Int:
        if self.depth > 1024:
            raise DecodeError(DecodeError.KIND_DEPTH, self.i)
        if self.i < self.n:
            var td0 = Int(self.raw[self.i])
            var t0 = td0 >> 4
            var ln0 = td0 & 15
            if t0 == 2 and ln0 == 0:
                self.i += 1
                return doc.add_i64(Int64(0))
            if t0 == 2 and ln0 == 1 and self.i + 1 < self.n:
                var one = Int(self.raw[self.i + 1])
                self.i += 2
                return doc.add_i64(Int64(one))
            if t0 == 8 and ln0 < 14:
                self.i += 1
                return doc.add_string_raw(self._take(ln0), self.i)
            if t0 >= 11 and t0 <= 13:
                self.i += 1
                return self._container(doc, tab, ver, t0, ln0)
        var td = self._b()
        var t = td >> 4
        var ln = td & 0x0F
        if t == 0:
            if ln == 15:
                return doc.add_null(0)
            var skip = ln
            if ln == 14:
                skip = self._var_uint()
            _ = self._take(skip)
            return -1
        if t == 15:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if t == 14:
            return self._ann(doc, tab, ver, ln, in_ann)
        if t == 1:
            if ln == 0:
                return doc.add_bool(False)
            if ln == 1:
                return doc.add_bool(True)
            if ln == 15:
                return doc.add_null(K_BOOL)
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if t == 2 or t == 3:
            if ln == 15:
                return doc.add_null(K_INT)
            if t == 3 and ln == 0:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            var size = self._repr_len(ln)
            if size == 0:
                return doc.add_i64(Int64(0))
            if size == 1:
                if self.i >= self.n:
                    raise DecodeError(DecodeError.KIND_EOF, self.i)
                var one = Int(self.raw[self.i])
                self.i += 1
                if t == 3 and one == 0:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                if t == 3:
                    return doc.add_i64(Int64(0) - Int64(one))
                return doc.add_i64(Int64(one))
            if size <= 8:
                if self.i + size > self.n:
                    raise DecodeError(DecodeError.KIND_EOF, self.i)
                var mag = UInt64(0)
                var k = 0
                while k < size:
                    mag = (mag << UInt64(8)) | UInt64(Int(self.raw[self.i + k]))
                    k += 1
                self.i += size
                if t == 3 and mag == UInt64(0):
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                if mag <= UInt64(9223372036854775807):
                    if t == 3:
                        return doc.add_i64(Int64(0) - Int64(mag))
                    return doc.add_i64(Int64(mag))
                if t == 3 and mag == (UInt64(1) << UInt64(63)):
                    return doc.add_i64(Int64(0) - Int64(1) - Int64(9223372036854775807))
                var big = big_from_u64(mag, t == 3)
                return doc.add_int(big^)
            var mag = big_from_be(self._take(size), False, self.i)
            if t == 3:
                if mag.is_zero():
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                mag.neg = True
            return doc.add_int(mag^)
        if t == 4:
            if ln == 15:
                return doc.add_null(K_FLOAT)
            if ln == 0:
                return doc.add_float(0, UInt64(0))
            if ln != 4 and ln != 8:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            return self._float(doc, ln)
        if t == 5:
            if ln == 15:
                return doc.add_null(K_DECIMAL)
            if ln == 0:
                return doc.add_decimal(BigInt(), False, 0)
            var size = self._repr_len(ln)
            return self._decimal(doc, self.i + size)
        if t == 6:
            if ln == 15:
                return doc.add_null(6)
            if ln < 2:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            var size = self._repr_len(ln)
            return self._time(doc, self.i + size)
        if t == 7:
            if ln == 15:
                return doc.add_null(K_SYMBOL)
            if ln == 0:
                return sym_from_sid(doc, tab, 0, self.i)
            var size = self._repr_len(ln)
            var sid = self._uint(size)
            return sym_from_sid(doc, tab, sid, self.i)
        if t == 8 or t == 9 or t == 10:
            var kind = K_STRING
            var null_k = K_STRING
            if t == 9:
                kind = K_CLOB
                null_k = K_CLOB
            if t == 10:
                kind = K_BLOB
                null_k = K_BLOB
            if ln == 15:
                return doc.add_null(null_k)
            var size = self._repr_len(ln)
            var span = self._take(size)
            if t == 8:
                return doc.add_string_raw(span, self.i)
            var buf = List[Byte]()
            var k = 0
            while k < len(span):
                buf.append(span[k])
                k += 1
            return doc.add_bytes(kind, buf^)
        if t == 11 or t == 12 or t == 13:
            return self._container(doc, tab, ver, t, ln)
        raise DecodeError(DecodeError.KIND_SYNTAX, self.i)

    def _float(mut self, mut doc: IonDoc, n: Int) raises DecodeError -> Int:
        var span = self._take(n)
        var bits = UInt64(0)
        var k = 0
        while k < n:
            bits = (bits << UInt64(8)) | UInt64(Int(span[k]))
            k += 1
        return doc.add_float(n, bits)

    def _uint(mut self, n: Int) raises DecodeError -> Int:
        var span = self._take(n)
        var acc = 0
        var k = 0
        while k < len(span):
            if acc > 0x00FFFFFFFFFFFFFF // 256:
                raise DecodeError(DecodeError.KIND_RANGE, self.i)
            acc = (acc << 8) | Int(span[k])
            k += 1
        return acc

    def _decimal(mut self, mut doc: IonDoc, end: Int) raises DecodeError -> Int:
        var neg0 = False
        var exp = self._var_int(neg0)
        if self.i > end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var left = end - self.i
        var negz = False
        var coef = self._signed_mag(left, negz)
        if self.i != end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var neg = coef.neg or negz
        coef.neg = False
        return doc.add_decimal(coef^, neg, exp)

    def _signed_mag(mut self, n: Int, mut neg0: Bool) raises DecodeError -> BigInt:
        neg0 = False
        if n == 0:
            return BigInt()
        var span = self._take(n)
        var first = Int(span[0])
        var neg = (first & 0x80) != 0
        var buf = List[Byte]()
        buf.append(Byte(first & 0x7F))
        var k = 1
        while k < len(span):
            buf.append(span[k])
            k += 1
        var mag = big_from_be(Span(buf), False, self.i)
        if neg and mag.is_zero():
            neg0 = True
            return mag^
        if neg:
            mag.neg = True
        return mag^

    def _time(mut self, mut doc: IonDoc, end: Int) raises DecodeError -> Int:
        var neg0 = False
        var off = self._var_int(neg0)
        if self.i >= end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var year = self._var_uint()
        if year < 1 or year > 999999999:
            raise DecodeError(DecodeError.KIND_RANGE, self.i)
        var when = IonTime()
        when.year = year
        when.prec = PREC_YEAR
        when.unknown = neg0
        when.off = off
        if not neg0:
            when.off = off
        if self.i < end:
            when.month = self._var_uint()
            when.prec = PREC_MONTH
            if when.month < 1 or when.month > 12:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self.i < end:
            when.day = self._var_uint()
            when.prec = PREC_DAY
            if when.month < 1 or when.day < 1 or when.day > _dim_bin(when.year, when.month):
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self.i < end:
            when.hour = self._var_uint()
            if self.i >= end:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            when.minute = self._var_uint()
            when.prec = PREC_MIN
            if when.hour > 23 or when.minute > 59:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self.i < end:
            when.second = self._var_uint()
            when.prec = PREC_SEC
            if when.second > 59:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if self.i < end:
            var fneg = False
            var fexp = self._var_int(fneg)
            var coef = BigInt()
            if self.i < end:
                var nz = False
                coef = self._signed_mag(end - self.i, nz)
                if coef.neg and not nz:
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                if nz:
                    coef = BigInt()
            elif self.i != end:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            var drop = coef.is_zero() and fexp >= 0
            if not drop and _frac_ge_one(coef, fexp):
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
            if not drop:
                if fexp >= 0 and not coef.is_zero():
                    raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
                when.prec = PREC_FRAC
                when.frac_exp = fexp
                when.frac_at = len(doc.limbs)
                when.frac_len = len(coef.limbs)
                var t = 0
                while t < len(coef.limbs):
                    doc.limbs.append(coef.limbs[t])
                    t += 1
        if self.i != end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        if when.prec < PREC_MIN:
            when.unknown = True
            when.off = 0
        elif not when.unknown:
            apply_offset(when, when.off)
        return doc.add_time(when)

    def _container(mut self, mut doc: IonDoc, mut tab: LocalTab, ver: Int, t: Int, ln: Int) raises DecodeError -> Int:
        var kind = K_LIST
        var null_k = K_LIST
        if t == 12:
            kind = K_SEXP
            null_k = K_SEXP
        if t == 13:
            kind = K_STRUCT
            null_k = K_STRUCT
        if ln == 15:
            return doc.add_null(null_k)
        if ln == 0:
            return doc.start_container(kind)
        var size = ln
        if ln == 14 or (t == 13 and ln == 1):
            size = self._var_uint()
            if t == 13 and ln == 1 and size == 0:
                raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var end = self.i + size
        if end > self.n:
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        self.depth += 1
        var id = doc.start_container(kind)
        while self.i < end:
            if t == 13:
                var b = Int(self.raw[self.i])
                var sid = b & 0x7F
                if (b & 0x80) != 0:
                    self.i += 1
                else:
                    sid = self._var_uint()
                var child = self._value(doc, tab, ver, False)
                if child < 0:
                    continue
                var slot = self.cache_sym0
                if sid != self.cache_sid0:
                    if sid == self.cache_sid1:
                        slot = self.cache_sym1
                    else:
                        var sym = sym_from_sid(doc, tab, sid, self.i)
                        slot = doc.nodes[sym].a
                        self.cache_sid1 = self.cache_sid0
                        self.cache_sym1 = self.cache_sym0
                        self.cache_sid0 = sid
                        self.cache_sym0 = slot
                doc.add_child(id, child, slot)
            else:
                var child = self._value(doc, tab, ver, False)
                if child < 0:
                    continue
                doc.add_child(id, child, -1)
        self.depth -= 1
        if self.i != end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        return id

    def _ann(mut self, mut doc: IonDoc, mut tab: LocalTab, ver: Int, ln: Int, in_ann: Bool) raises DecodeError -> Int:
        if in_ann or ln < 3 or ln == 15:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var size = self._repr_len(ln)
        var end = self.i + size
        if end > self.n:
            raise DecodeError(DecodeError.KIND_EOF, self.i)
        var alen = self._var_uint()
        var annot_end = self.i + alen
        if annot_end > end or alen <= 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var anns = List[Int]()
        while self.i < annot_end:
            var sid = self._var_uint()
            var sym = sym_from_sid(doc, tab, sid, self.i)
            anns.append(doc.nodes[sym].a)
        if self.i != annot_end or len(anns) == 0:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        var id = self._value(doc, tab, ver, True)
        if id < 0 or self.i != end:
            raise DecodeError(DecodeError.KIND_SYNTAX, self.i)
        doc.set_anns(id, anns^)
        return id


def _frac_ge_one(coef: BigInt, exp: Int) -> Bool:
    if coef.is_zero():
        return False
    if exp >= 0:
        return True
    var limit = BigInt()
    limit.add_small(UInt32(1))
    var k = 0
    var n = 0 - exp
    while k < n:
        limit.mul_small(UInt32(10))
        k += 1
    return coef.cmp_mag(limit) >= 0


def _dim_bin(year: Int, month: Int) -> Int:
    if month == 2:
        if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
            return 29
        return 28
    if month == 4 or month == 6 or month == 9 or month == 11:
        return 30
    return 31


def decode_binary[origin: ImmOrigin](raw: Span[Byte, origin], cat: Catalog) raises DecodeError -> IonDoc:
    var doc = IonDoc()
    doc.reserve(len(raw))
    var tab = LocalTab()
    var parser = BinParser(raw)
    parser.read_all(doc, tab, cat)
    return doc^
