package ion

internal fun symEq(a: IonDoc, sa: Int, b: IonDoc, sb: Int): Boolean {
    val x = a.syms[sa]
    val y = b.syms[sb]
    if (x.text >= 0 && y.text >= 0) return a.texts[x.text] == b.texts[y.text]
    if (x.text >= 0 || y.text >= 0) return false
    val xImp = x.impName >= 0
    val yImp = y.impName >= 0
    if (xImp || yImp) {
        if (!(xImp && yImp)) return false
        return a.texts[x.impName] == b.texts[y.impName] && x.impSid == y.impSid
    }
    return true
}

private fun limbsEq(a: IonDoc, at: Int, n: Int, b: IonDoc, ot: Int, on: Int): Boolean {
    if (n != on) return false
    var i = 0
    while (i < n) {
        if (a.limbs[at + i] != b.limbs[ot + i]) return false
        i++
    }
    return true
}

private fun annEq(a: IonDoc, ai: Int, b: IonDoc, bi: Int): Boolean {
    val an = a.nodes[ai]
    val bn = b.nodes[bi]
    if (an.annN != bn.annN) return false
    var i = 0
    while (i < an.annN) {
        if (!symEq(a, a.anns[an.ann + i], b, b.anns[bn.ann + i])) return false
        i++
    }
    return true
}

private fun f16ToDouble(h: Int): Double {
    val sign = (h and 0x8000).toLong() shl 48
    var exp = (h and 0x7C00) ushr 10
    var frac = (h and 0x03FF).toLong()
    if (exp == 0) {
        if (frac == 0L) return Double.fromBits(sign)
        exp = 1
        while ((frac and 0x0400L) == 0L) {
            frac = frac shl 1
            exp--
        }
        frac = frac and 0x03FFL
        val e = (exp + (1023 - 15)).toLong()
        return Double.fromBits(sign or (e shl 52) or (frac shl 42))
    }
    if (exp == 31) {
        return Double.fromBits(sign or (0x7FFL shl 52) or (frac shl 42))
    }
    val e = (exp + (1023 - 15)).toLong()
    return Double.fromBits(sign or (e shl 52) or (frac shl 42))
}

internal fun floatValue(bits: Long, width: Int): Double = when (width) {
    0 -> 0.0
    4 -> Float.fromBits(bits.toInt()).toDouble()
    2 -> f16ToDouble(bits.toInt() and 0xFFFF)
    else -> Double.fromBits(bits)
}

private fun floatParts(bits: Long, width: Int): Triple<Double, Boolean, Boolean> {
    if (width == 0) return Triple(0.0, false, false)
    val v = floatValue(bits, width)
    val nan = v.isNaN()
    val neg0 = when (width) {
        4 -> v == 0.0 && (bits.toInt() and 0x80000000.toInt()) != 0
        2 -> v == 0.0 && (bits and 0x8000L) != 0L
        else -> v == 0.0 && (bits and (1L shl 63)) != 0L
    }
    return Triple(v, nan, neg0)
}

private fun floatEq(a: IonDoc, ai: Int, b: IonDoc, bi: Int): Boolean {
    val (av, aNan, aNeg0) = floatParts(a.floats[a.nodes[ai].b], a.nodes[ai].a)
    val (bv, bNan, bNeg0) = floatParts(b.floats[b.nodes[bi].b], b.nodes[bi].a)
    if (aNan || bNan) return aNan && bNan
    if (aNeg0 || bNeg0) return aNeg0 && bNeg0
    return av == bv
}

private fun bytesEq(a: IonDoc, ai: Int, b: IonDoc, bi: Int): Boolean {
    val an = a.nodes[ai]
    val bn = b.nodes[bi]
    if (a.blobLen[an.a] != b.blobLen[bn.a]) return false
    var i = 0
    while (i < a.blobLen[an.a]) {
        if (a.blobBytes[a.blobAt[an.a] + i] != b.blobBytes[b.blobAt[bn.a] + i]) return false
        i++
    }
    return true
}

private fun timeEq(a: IonDoc, ai: Int, b: IonDoc, bi: Int): Boolean {
    val x = a.times[a.nodes[ai].a]
    val y = b.times[b.nodes[bi].a]
    if (x.prec != y.prec || x.unknown != y.unknown) return false
    if (!x.unknown && x.off != y.off) return false
    if (x.year != y.year || x.month != y.month || x.day != y.day) return false
    if (x.hour != y.hour || x.minute != y.minute || x.second != y.second) return false
    if (x.fracExp != y.fracExp) return false
    return limbsEq(a, x.fracAt, x.fracLen, b, y.fracAt, y.fracLen)
}

fun ionEq(a: IonDoc, ai: Int, b: IonDoc, bi: Int): Boolean {
    if (!annEq(a, ai, b, bi)) return false
    val ak = a.nodes[ai].kind
    val bk = b.nodes[bi].kind
    if (ak != bk) return false
    return when (ak) {
        K_NULL -> a.nodes[ai].a == b.nodes[bi].a
        K_BOOL -> a.nodes[ai].a == b.nodes[bi].a
        K_INT -> a.nodes[ai].c == b.nodes[bi].c &&
            limbsEq(a, a.nodes[ai].a, a.nodes[ai].b, b, b.nodes[bi].a, b.nodes[bi].b)
        K_FLOAT -> floatEq(a, ai, b, bi)
        K_DECIMAL -> a.nodes[ai].c == b.nodes[bi].c && a.nodes[ai].exp == b.nodes[bi].exp &&
            limbsEq(a, a.nodes[ai].a, a.nodes[ai].b, b, b.nodes[bi].a, b.nodes[bi].b)
        K_TIMESTAMP -> timeEq(a, ai, b, bi)
        K_STRING -> a.texts[a.nodes[ai].a] == b.texts[b.nodes[bi].a]
        K_SYMBOL -> symEq(a, a.nodes[ai].a, b, b.nodes[bi].a)
        K_BLOB, K_CLOB -> bytesEq(a, ai, b, bi)
        K_LIST, K_SEXP -> {
            if (a.nodes[ai].nchild != b.nodes[bi].nchild) return false
            var ea = a.nodes[ai].child
            var eb = b.nodes[bi].child
            var i = 0
            while (i < a.nodes[ai].nchild) {
                if (!ionEq(a, a.edgeChild[ea], b, b.edgeChild[eb])) return false
                ea = a.edgeNext[ea]
                eb = b.edgeNext[eb]
                i++
            }
            true
        }
        K_STRUCT -> structEq(a, ai, b, bi)
        else -> false
    }
}

private fun structEq(a: IonDoc, ai: Int, b: IonDoc, bi: Int): Boolean {
    if (a.nodes[ai].nchild != b.nodes[bi].nchild) return false
    val n = a.nodes[ai].nchild
    val aChild = IntArray(n)
    val aField = IntArray(n)
    val bChild = IntArray(n)
    val bField = IntArray(n)
    var e = a.nodes[ai].child
    var i = 0
    while (i < n) {
        aChild[i] = a.edgeChild[e]
        aField[i] = a.edgeField[e]
        e = a.edgeNext[e]
        i++
    }
    e = b.nodes[bi].child
    i = 0
    while (i < n) {
        bChild[i] = b.edgeChild[e]
        bField[i] = b.edgeField[e]
        e = b.edgeNext[e]
        i++
    }
    val used = BooleanArray(n)
    i = 0
    while (i < n) {
        var found = false
        var j = 0
        while (j < n) {
            if (!used[j] && symEq(a, aField[i], b, bField[j]) && ionEq(a, aChild[i], b, bChild[j])) {
                used[j] = true
                found = true
                break
            }
            j++
        }
        if (!found) return false
        i++
    }
    return true
}

fun docsEq(a: IonDoc, b: IonDoc): Boolean {
    if (a.top.size != b.top.size) return false
    var i = 0
    while (i < a.top.size) {
        if (!ionEq(a, a.top[i], b, b.top[i])) return false
        i++
    }
    return true
}
