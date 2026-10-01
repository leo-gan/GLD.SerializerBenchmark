from std.collections import List

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
    K_TIMESTAMP,
    IonDoc,
)


def _ann_eq(a: IonDoc, ai: Int, b: IonDoc, bi: Int) -> Bool:
    var an = a.nodes[ai]
    var bn = b.nodes[bi]
    if an.ann_n != bn.ann_n:
        return False
    var i = 0
    while i < an.ann_n:
        if not sym_eq(a, a.anns[an.ann + i], b, b.anns[bn.ann + i]):
            return False
        i += 1
    return True


def sym_eq(a: IonDoc, sa: Int, b: IonDoc, sb: Int) -> Bool:
    var x = a.syms[sa]
    var y = b.syms[sb]
    if x.text >= 0 and y.text >= 0:
        return a.texts[x.text] == b.texts[y.text]
    if x.text >= 0 or y.text >= 0:
        return False
    var x_imp = x.imp_name >= 0
    var y_imp = y.imp_name >= 0
    if x_imp or y_imp:
        if not (x_imp and y_imp):
            return False
        return a.texts[x.imp_name] == b.texts[y.imp_name] and x.imp_sid == y.imp_sid
    return True


def _limbs(doc: IonDoc, at: Int, n: Int, other: IonDoc, ot: Int, on: Int) -> Bool:
    if n != on:
        return False
    var i = 0
    while i < n:
        if doc.limbs[at + i] != other.limbs[ot + i]:
            return False
        i += 1
    return True


def _bytes_eq(a: IonDoc, ai: Int, b: IonDoc, bi: Int) -> Bool:
    var an = a.nodes[ai]
    var bn = b.nodes[bi]
    if a.blob_len[an.a] != b.blob_len[bn.a]:
        return False
    var i = 0
    while i < a.blob_len[an.a]:
        if a.blob_bytes[a.blob_at[an.a] + i] != b.blob_bytes[b.blob_at[bn.a] + i]:
            return False
        i += 1
    return True


def _f64(bits: UInt64) -> Float64:
    return Float64(from_bits=bits)


def _float_eq(a: IonDoc, ai: Int, b: IonDoc, bi: Int) -> Bool:
    var ab = a.floats[a.nodes[ai].b]
    var bb = b.floats[b.nodes[bi].b]
    var aw = a.nodes[ai].a
    var bw = b.nodes[bi].a
    var a_nan = False
    var b_nan = False
    var a_neg0 = False
    var b_neg0 = False
    var av = _as_f64(ab, aw, a_nan, a_neg0)
    var bv = _as_f64(bb, bw, b_nan, b_neg0)
    if a_nan or b_nan:
        return a_nan and b_nan
    if a_neg0 or b_neg0:
        return a_neg0 and b_neg0
    return av == bv


def _as_f64(bits: UInt64, width: Int, mut is_nan: Bool, mut is_neg0: Bool) -> Float64:
    is_nan = False
    is_neg0 = False
    if width == 0:
        return Float64(0)
    if width == 4:
        var f = Float32(from_bits=UInt32(bits))
        if f != f:
            is_nan = True
        if f == Float32(0) and (UInt32(bits) & UInt32(0x80000000)) != UInt32(0):
            is_neg0 = True
        return Float64(f)
    if width == 2:
        var f = _f16_to_f64(UInt16(bits))
        if f != f:
            is_nan = True
        if f == Float64(0) and (bits & UInt64(0x8000)) != UInt64(0):
            is_neg0 = True
        return f
    var f = _f64(bits)
    if f != f:
        is_nan = True
    if f == Float64(0) and (bits & (UInt64(1) << UInt64(63))) != UInt64(0):
        is_neg0 = True
    return f


def _f16_to_f64(h: UInt16) -> Float64:
    var sign = UInt64(h & UInt16(0x8000)) << UInt64(48)
    var exp = Int((h & UInt16(0x7C00)) >> UInt16(10))
    var frac = UInt64(h & UInt16(0x03FF))
    if exp == 0:
        if frac == UInt64(0):
            return Float64(from_bits=sign)
        exp = 1
        while (frac & UInt64(0x0400)) == UInt64(0):
            frac = frac << UInt64(1)
            exp -= 1
        frac = frac & UInt64(0x03FF)
        var e = UInt64(exp + (1023 - 15))
        var bits = sign | (e << UInt64(52)) | (frac << UInt64(42))
        return Float64(from_bits=bits)
    if exp == 31:
        var bits = sign | (UInt64(0x7FF) << UInt64(52)) | (frac << UInt64(42))
        return Float64(from_bits=bits)
    var e = UInt64(exp + (1023 - 15))
    var bits = sign | (e << UInt64(52)) | (frac << UInt64(42))
    return Float64(from_bits=bits)


def _time_eq(a: IonDoc, ai: Int, b: IonDoc, bi: Int) -> Bool:
    var x = a.times[a.nodes[ai].a]
    var y = b.times[b.nodes[bi].a]
    if x.prec != y.prec or x.unknown != y.unknown:
        return False
    if not x.unknown and x.off != y.off:
        return False
    if x.year != y.year or x.month != y.month or x.day != y.day:
        return False
    if x.hour != y.hour or x.minute != y.minute or x.second != y.second:
        return False
    if x.frac_exp != y.frac_exp:
        return False
    return _limbs(a, x.frac_at, x.frac_len, b, y.frac_at, y.frac_len)


def ion_eq(a: IonDoc, ai: Int, b: IonDoc, bi: Int) -> Bool:
    if not _ann_eq(a, ai, b, bi):
        return False
    var ak = a.nodes[ai].kind
    var bk = b.nodes[bi].kind
    if ak != bk:
        return False
    if ak == K_NULL:
        return a.nodes[ai].a == b.nodes[bi].a
    if ak == K_BOOL:
        return a.nodes[ai].a == b.nodes[bi].a
    if ak == K_INT:
        if a.nodes[ai].c != b.nodes[bi].c:
            return False
        return _limbs(a, a.nodes[ai].a, a.nodes[ai].b, b, b.nodes[bi].a, b.nodes[bi].b)
    if ak == K_FLOAT:
        return _float_eq(a, ai, b, bi)
    if ak == K_DECIMAL:
        if a.nodes[ai].c != b.nodes[bi].c or a.nodes[ai].d != b.nodes[bi].d:
            return False
        return _limbs(a, a.nodes[ai].a, a.nodes[ai].b, b, b.nodes[bi].a, b.nodes[bi].b)
    if ak == K_TIMESTAMP:
        return _time_eq(a, ai, b, bi)
    if ak == K_STRING:
        return a.texts[a.nodes[ai].a] == b.texts[b.nodes[bi].a]
    if ak == K_SYMBOL:
        return sym_eq(a, a.nodes[ai].a, b, b.nodes[bi].a)
    if ak == K_BLOB or ak == K_CLOB:
        return _bytes_eq(a, ai, b, bi)
    if ak == K_LIST or ak == K_SEXP:
        if a.nodes[ai].nchild != b.nodes[bi].nchild:
            return False
        var ea = a.nodes[ai].child
        var eb = b.nodes[bi].child
        var i = 0
        while i < a.nodes[ai].nchild:
            if not ion_eq(a, a.edges[ea].child, b, b.edges[eb].child):
                return False
            ea = a.edges[ea].next
            eb = b.edges[eb].next
            i += 1
        return True
    if ak == K_STRUCT:
        return _struct_eq(a, ai, b, bi)
    return False


def _struct_eq(a: IonDoc, ai: Int, b: IonDoc, bi: Int) -> Bool:
    if a.nodes[ai].nchild != b.nodes[bi].nchild:
        return False
    var n = a.nodes[ai].nchild
    var a_child = List[Int]()
    var a_field = List[Int]()
    var b_child = List[Int]()
    var b_field = List[Int]()
    var e = a.nodes[ai].child
    var i = 0
    while i < n:
        a_child.append(a.edges[e].child)
        a_field.append(a.edges[e].field)
        e = a.edges[e].next
        i += 1
    e = b.nodes[bi].child
    i = 0
    while i < n:
        b_child.append(b.edges[e].child)
        b_field.append(b.edges[e].field)
        e = b.edges[e].next
        i += 1
    var used = List[Bool]()
    i = 0
    while i < n:
        used.append(False)
        i += 1
    i = 0
    while i < n:
        var found = False
        var j = 0
        while j < n:
            if not used[j] and sym_eq(a, a_field[i], b, b_field[j]):
                if ion_eq(a, a_child[i], b, b_child[j]):
                    used[j] = True
                    found = True
                    break
            j += 1
        if not found:
            return False
        i += 1
    return True


def docs_eq(a: IonDoc, b: IonDoc) -> Bool:
    if len(a.top) != len(b.top):
        return False
    var i = 0
    while i < len(a.top):
        if not ion_eq(a, a.top[i], b, b.top[i]):
            return False
        i += 1
    return True
