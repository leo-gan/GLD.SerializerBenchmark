package ion

import java.math.BigInteger

internal fun flexUInt(raw: ByteArray, idx: IntArray): Long {
    val start = idx[0]
    var acc = 0L
    var shift = 0
    var nread = 0
    while (nread < 8) {
        if (idx[0] >= raw.size) throw DecodeError(DecodeError.KIND_EOF, start)
        val b = raw[idx[0]].toLong() and 0xFF
        idx[0]++
        nread++
        acc = acc or (b shl shift)
        shift += 8
        if (acc == 0L) continue
        var low = 0
        var probe = acc
        while ((probe and 1L) == 0L) {
            probe = probe ushr 1
            low++
        }
        val width = low + 1
        if (nread >= width) return acc ushr width
    }
    throw DecodeError(DecodeError.KIND_RANGE, start)
}

internal fun flexInt(raw: ByteArray, idx: IntArray): Long {
    val start = idx[0]
    var acc = 0L
    var shift = 0
    var nread = 0
    while (nread < 8) {
        if (idx[0] >= raw.size) throw DecodeError(DecodeError.KIND_EOF, start)
        val b = raw[idx[0]].toLong() and 0xFF
        idx[0]++
        nread++
        acc = acc or (b shl shift)
        shift += 8
        if (acc == 0L) continue
        var low = 0
        var probe = acc
        while ((probe and 1L) == 0L) {
            probe = probe ushr 1
            low++
        }
        val width = low + 1
        if (nread >= width) {
            val magBits = 7 * width
            val mag = acc ushr width
            val signbit = 1L shl (magBits - 1)
            if ((mag and signbit) != 0L) {
                val full = (1L shl magBits) - mag
                return -full
            }
            return mag
        }
    }
    throw DecodeError(DecodeError.KIND_RANGE, start)
}

internal fun writeFlexInt(buf: ByteBuf, v: Long) {
    var n = 1
    while (n < 8) {
        val half = 1L shl (7 * n - 1)
        if (v >= -half && v <= half - 1) break
        n++
    }
    val mask = (1L shl (7 * n)) - 1L
    val pattern = v and mask
    var bits = pattern shl n
    bits = bits or (1L shl (n - 1))
    var k = 0
    while (k < n) {
        buf.add(((bits ushr (k * 8)) and 0xFF).toInt())
        k++
    }
}

internal fun writeFlexUInt(buf: ByteBuf, v: Long) {
    var n = 1
    var limit = 128L
    var x = if (v < 0) 0L else v
    while (x >= limit && n < 8) {
        n++
        limit *= 128L
    }
    var bits = x shl n
    bits = bits or (1L shl (n - 1))
    var k = 0
    while (k < n) {
        buf.add(((bits ushr (k * 8)) and 0xFF).toInt())
        k++
    }
}

internal class Ion11(val raw: ByteArray) {
    var i: Int = 0
    var templ: Boolean = false
    var curParam0: Int = 0
    val macroName = ArrayList<String>()
    val macroRoot = ArrayList<Int>()
    val macroParamAt = ArrayList<Int>()
    val macroNparam = ArrayList<Int>()
    val paramKind = ArrayList<Int>()
    val paramDefault = ArrayList<Int>()

    fun readTop(doc: IonDoc, tab: LocalTab, cat: Catalog) {
        while (i < raw.size) {
            if (bvm()) {
                tab.resetSystem()
                clearMacros()
                continue
            }
            val id = value(doc, tab, false, cat)
            if (id >= 0) doc.addTop(id)
        }
    }

    fun clearMacros() {
        macroName.clear()
        macroRoot.clear()
        macroParamAt.clear()
        macroNparam.clear()
        paramKind.clear()
        paramDefault.clear()
    }

    private fun bvm(): Boolean {
        if (i + 3 >= raw.size) return false
        if (u8(raw, i) != 0xE0 || u8(raw, i + 3) != 0xEA || u8(raw, i + 1) != 1) return false
        i += 4
        return true
    }

    private fun idx(): IntArray = intArrayOf(i)

    private fun pull(box: IntArray) {
        i = box[0]
    }

    fun value(doc: IonDoc, tab: LocalTab, inE: Boolean, cat: Catalog): Int {
        if (i >= raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        val op = u8(raw, i)
        i++
        if (op == 0xEC) return -1
        if (op == 0xED) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            if (i + n > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
            i += n
            return -1
        }
        if (op == 0xEF) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        if (op == 0x8E) return doc.addNull(0)
        if (op == 0x8F) return typedNull(doc)
        if (op in 0x60..0x68) {
            if (op == 0x60) return doc.addI64(0)
            return doc.addI64(fixedInt(op - 0x60))
        }
        if (op == 0xF5) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return if (n <= 8) doc.addI64(fixedInt(n)) else doc.addInt(readLeBig(n))
        }
        if (op == 0x6E) return doc.addBool(true)
        if (op == 0x6F) return doc.addBool(false)
        if (op == 0x6A) return doc.addFloat(0, 0L)
        if (op in 0x6B..0x6D) {
            val n = if (op == 0x6C) 4 else if (op == 0x6D) 8 else 2
            return float(doc, n)
        }
        if (op in 0x70..0x7F) return decimal(doc, op - 0x70)
        if (op == 0xF6) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return decimal(doc, n)
        }
        if (op in 0x90..0x9F) return doc.addString(text(op - 0x90))
        if (op == 0xF8) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return doc.addString(text(n))
        }
        if (op in 0xA0..0xAF) return doc.addSymbolText(text(op - 0xA0))
        if (op == 0xF9) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return doc.addSymbolText(text(n))
        }
        if (op in 0x50..0x57) {
            val box = idx()
            val hi = flexUInt(raw, box)
            pull(box)
            val sid = ((hi shl 3) or (op - 0x50).toLong()).toIntChecked(i)
            return symFromSid(doc, tab, sid, i)
        }
        if (op == 0x58 || op == 0x59) {
            i--
            return annotated(doc, tab, cat)
        }
        if (op in 0xB0..0xBF) return container(doc, tab, K_LIST, op - 0xB0, false, cat)
        if (op == 0xFA) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return container(doc, tab, K_LIST, n, false, cat)
        }
        if (op == 0xF0) return container(doc, tab, K_LIST, -1, true, cat)
        if (op in 0xC0..0xCF) return container(doc, tab, K_SEXP, op - 0xC0, false, cat)
        if (op == 0xFB) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return container(doc, tab, K_SEXP, n, false, cat)
        }
        if (op == 0xF1) return container(doc, tab, K_SEXP, -1, true, cat)
        if (op == 0xD0) return doc.startContainer(K_STRUCT)
        if ((op in 0xD2..0xDF) || op == 0xFC || op == 0xFD) {
            var n = op - 0xD0
            var flex = false
            if (op == 0xFC || op == 0xFD) {
                val box = idx()
                n = flexUInt(raw, box).toIntChecked(i)
                pull(box)
            }
            if (op == 0xFD) flex = true
            return struct(doc, tab, n, false, flex, cat)
        }
        if (op == 0xF2 || op == 0xF3) return struct(doc, tab, -1, true, op == 0xF3, cat)
        if (op == 0xFE || op == 0xFF) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return bytes(doc, if (op == 0xFF) K_CLOB else K_BLOB, n)
        }
        if (op in 0x80..0x8C) return shortTime(doc, op)
        if (op == 0xF7) return longTime(doc)
        if (op == 0xE0) {
            if (inE) return -2
            throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (op == 0xE9 || op == 0xEA || op == 0xEB) return placeholder(doc, tab, op, cat)
        if (op in 0xE1..0xE8) {
            directive(doc, tab, op, cat)
            return -1
        }
        if (templ && (op < 0x48 || op in 0x48..0x4F || op == 0xF4)) {
            throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (op < 0x48 || op in 0x48..0x4F || op == 0xF4) return eexp(doc, tab, op, cat)
        throw DecodeError(DecodeError.KIND_VERSION, i)
    }

    private fun text(n: Int): String {
        if (i + n > raw.size || n < 0) throw DecodeError(DecodeError.KIND_EOF, i)
        val start = i
        i += n
        validateUtf8(raw, start, i, start)
        return String(raw, start, n, Charsets.UTF_8)
    }

    private fun typedNull(doc: IonDoc): Int {
        if (i >= raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        val t = u8(raw, i)
        i++
        val k = when (t) {
            1 -> K_BOOL
            2 -> K_INT
            3 -> K_FLOAT
            4 -> K_DECIMAL
            5 -> K_TIMESTAMP
            6 -> K_STRING
            7 -> K_SYMBOL
            8 -> K_BLOB
            9 -> K_CLOB
            10 -> K_LIST
            11 -> K_SEXP
            12 -> K_STRUCT
            else -> throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        return doc.addNull(k)
    }

    private fun float(doc: IonDoc, n: Int): Int {
        if (i + n > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        var bits = 0L
        var k = 0
        while (k < n) {
            bits = bits or ((raw[i + k].toLong() and 0xFF) shl (k * 8))
            k++
        }
        i += n
        return doc.addFloat(n, bits)
    }

    private fun fixedInt(n: Int): Long {
        if (n == 0) return 0
        if (n > 8 || i + n > raw.size) {
            if (i + n > raw.size || n < 0) throw DecodeError(DecodeError.KIND_EOF, i)
            throw DecodeError(DecodeError.KIND_RANGE, i)
        }
        var acc = 0L
        var k = 0
        while (k < n) {
            acc = acc or ((raw[i + k].toLong() and 0xFF) shl (k * 8))
            k++
        }
        i += n
        if (n == 8) return acc
        val sign = 1L shl (n * 8 - 1)
        if ((acc and sign) != 0L) return acc - (1L shl (n * 8))
        return acc
    }

    private fun readLeBig(n: Int): BigInt {
        if (n < 0 || i + n > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        val be = ByteArray(n)
        var k = 0
        while (k < n) {
            be[n - 1 - k] = raw[i + k]
            k++
        }
        i += n
        return bigFromInteger(BigInteger(be))
    }

    private fun decimal(doc: IonDoc, n: Int): Int {
        if (n == 0) return doc.addDecimal(BigInt(), false, 0)
        val end = i + n
        if (n < 0 || end > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        val box = idx()
        val exp = flexInt(raw, box)
        pull(box)
        var coef = BigInt()
        var neg = false
        if (i < end) {
            val left = end - i
            if (left <= 8) {
                val v = fixedInt(left)
                if (v < 0) {
                    neg = true
                    coef = if (v == Long.MIN_VALUE) bigFromU64(Long.MIN_VALUE, false) else bigFromU64(-v, false)
                } else if (v == 0L) {
                    neg = true
                } else {
                    coef = bigFromU64(v, false)
                }
            } else {
                val big = readLeBig(left)
                if (big.isZero()) neg = true
                else {
                    neg = big.neg
                    big.neg = false
                    coef = big
                }
            }
        }
        if (i != end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        return doc.addDecimal(coef, neg, exp)
    }

    private fun bytes(doc: IonDoc, kind: Int, n: Int): Int {
        if (n < 0 || i + n > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        val buf = raw.copyOfRange(i, i + n)
        i += n
        return doc.addBytes(kind, buf)
    }

    private fun container(doc: IonDoc, tab: LocalTab, kind: Int, n: Int, delim: Boolean, cat: Catalog): Int {
        val id = doc.startContainer(kind)
        val end = if (delim) raw.size else {
            if (n < 0 || i > raw.size - n) throw DecodeError(DecodeError.KIND_EOF, i)
            i + n
        }
        while (i < end) {
            if (delim && i < raw.size && u8(raw, i) == 0xEF) {
                i++
                return id
            }
            val child = value(doc, tab, false, cat)
            if (child >= 0) doc.addChild(id, child, -1)
        }
        return id
    }

    private fun fieldId(doc: IonDoc, tab: LocalTab, mode: Boolean): Int {
        val box = idx()
        if (mode) {
            val iv = flexInt(raw, box)
            pull(box)
            if (iv >= 0) {
                val sym = symFromSid(doc, tab, iv.toIntChecked(i), i)
                return doc.nodes[sym].a
            }
            val nbytes = (-1L - iv).toIntChecked(i)
            return doc.nodes[doc.addSymbolText(text(nbytes))].a
        }
        val sid = flexUInt(raw, box).toIntChecked(i)
        pull(box)
        val sym = symFromSid(doc, tab, sid, i)
        return doc.nodes[sym].a
    }

    private fun struct(doc: IonDoc, tab: LocalTab, n: Int, delim: Boolean, flex: Boolean, cat: Catalog): Int {
        val id = doc.startContainer(K_STRUCT)
        var mode = flex
        val end = if (delim) raw.size else {
            if (n < 0 || i > raw.size - n) throw DecodeError(DecodeError.KIND_EOF, i)
            i + n
        }
        while (i < end) {
            if (delim && i < raw.size && u8(raw, i) == 0xEF) {
                i++
                return id
            }
            val field = fieldId(doc, tab, mode)
            if (i < raw.size && (u8(raw, i) == 0xEE || u8(raw, i) == 0xEC || u8(raw, i) == 0xEF)) {
                val marker = u8(raw, i)
                i++
                if (marker == 0xEE) mode = !mode
                if (marker == 0xEF) return id
                continue
            }
            val child = value(doc, tab, false, cat)
            if (child >= 0) doc.addChild(id, child, field)
        }
        return id
    }

    private fun annotated(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        val anns = ArrayList<Int>()
        while (i < raw.size) {
            val op = u8(raw, i)
            if (op == 0x58) {
                i++
                val box = idx()
                val sid = flexUInt(raw, box).toIntChecked(i)
                pull(box)
                val sym = symFromSid(doc, tab, sid, i)
                anns.add(doc.nodes[sym].a)
            } else if (op == 0x59) {
                i++
                val box = idx()
                val n = flexUInt(raw, box).toIntChecked(i)
                pull(box)
                val sym = doc.addSymbolText(text(n))
                anns.add(doc.nodes[sym].a)
            } else {
                break
            }
        }
        if (anns.isEmpty()) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val id = value(doc, tab, false, cat)
        if (id < 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        doc.setAnns(id, anns)
        return id
    }

    private fun directive(doc: IonDoc, tab: LocalTab, op: Int, cat: Catalog) {
        if (op == 0xE1) tab.resetSystem()
        if (op == 0xE3) clearMacros()
        val saved = templ
        if (op == 0xE3 || op == 0xE4) templ = true
        var useName = ""
        var useVer = 1
        var sawUse = false
        while (i < raw.size && u8(raw, i) != 0xEF) {
            val param0 = paramKind.size
            curParam0 = param0
            val v = value(doc, tab, false, cat)
            if ((op == 0xE1 || op == 0xE2) && v >= 0 && doc.nodes[v].kind == K_STRING) {
                tab.addText(doc.textAt(v))
            }
            if ((op == 0xE3 || op == 0xE4) && v >= 0) defineMacro(doc, v, param0)
            if (op == 0xE5 && v >= 0) {
                if (!sawUse && doc.nodes[v].kind == K_STRING) {
                    useName = doc.textAt(v)
                    sawUse = true
                } else if (doc.nodes[v].kind == K_INT) {
                    useVer = positiveInt(doc, v)
                }
            }
        }
        templ = saved
        if (op == 0xE5) importNamed(tab, cat, useName, useVer, i)
        if (i < raw.size && u8(raw, i) == 0xEF) i++
    }

    private fun takeBits(n: Int): Int {
        if (n < 0 || i + n > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        val start = i
        i += n
        return start
    }

    private fun field(start: Int, at: Int, width: Int): Int {
        var v = 0
        var k = 0
        while (k < width) {
            val pos = at + k
            val b = u8(raw, start + (pos / 8))
            val bit = (b shr (pos % 8)) and 1
            v = v or (bit shl k)
            k++
        }
        return v
    }

    private fun finishTime(doc: IonDoc, whenTime: IonTime): Int {
        if (whenTime.month !in 1..12) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        if (whenTime.prec >= PREC_DAY) {
            if (whenTime.day < 1 || whenTime.day > daysInMonth(whenTime.year, whenTime.month)) {
                throw DecodeError(DecodeError.KIND_SYNTAX, i)
            }
        }
        if (whenTime.prec >= PREC_MIN && (whenTime.hour > 23 || whenTime.minute > 59)) {
            throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (whenTime.prec >= PREC_SEC && whenTime.second > 59) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        if (whenTime.year < 1 || whenTime.year > 999999999) throw DecodeError(DecodeError.KIND_RANGE, i)
        return doc.addTime(whenTime)
    }

    private fun putFrac(doc: IonDoc, whenTime: IonTime, coef: Int, exp: Int) {
        whenTime.prec = PREC_FRAC
        whenTime.fracExp = exp.toLong()
        val big = bigFromU64(coef.toLong() and 0xFFFFFFFFL, false)
        whenTime.fracAt = doc.limbs.size
        whenTime.fracLen = big.limbs.size
        doc.limbs.addAll(big.limbs)
    }

    private fun shortTime(doc: IonDoc, op: Int): Int {
        val n = when (op) {
            0x80 -> 1
            0x81, 0x82 -> 2
            0x83 -> 4
            0x84, 0x88, 0x89 -> 5
            0x85 -> 6
            0x86, 0x8A -> 7
            0x87, 0x8B -> 8
            else -> 9
        }
        val start = takeBits(n)
        val whenTime = IonTime()
        whenTime.year = 1970 + field(start, 0, 7)
        whenTime.prec = PREC_YEAR
        whenTime.unknown = true
        whenTime.off = 0
        if (op == 0x80) return finishTime(doc, whenTime)
        whenTime.month = field(start, 7, 4)
        whenTime.prec = PREC_MONTH
        if (op == 0x81) return finishTime(doc, whenTime)
        whenTime.day = field(start, 11, 5)
        whenTime.prec = PREC_DAY
        if (op == 0x82) return finishTime(doc, whenTime)
        whenTime.hour = field(start, 16, 5)
        whenTime.minute = field(start, 21, 6)
        whenTime.prec = PREC_MIN
        val known = op >= 0x88
        if (known) {
            val q = field(start, 27, 7)
            if (q == 127) {
                whenTime.unknown = true
                whenTime.off = 0
            } else {
                whenTime.unknown = false
                whenTime.off = (q - 56) * 15
            }
        } else {
            val u = field(start, 27, 1)
            if (u == 0) {
                whenTime.unknown = true
                whenTime.off = 0
            } else {
                whenTime.unknown = false
                whenTime.off = 0
            }
        }
        if (op == 0x83 || op == 0x88) return finishTime(doc, whenTime)
        val secAt = if (known) 34 else 28
        val fracAt = if (known) 40 else 34
        whenTime.second = field(start, secAt, 6)
        whenTime.prec = PREC_SEC
        var digits = 0
        var fbits = 0
        when (op) {
            0x85, 0x8A -> {
                digits = 3
                fbits = 10
            }
            0x86, 0x8B -> {
                digits = 6
                fbits = 20
            }
            0x87, 0x8C -> {
                digits = 9
                fbits = 30
            }
        }
        if (digits != 0) {
            val coef = field(start, fracAt, fbits)
            putFrac(doc, whenTime, coef, -digits)
        }
        return finishTime(doc, whenTime)
    }

    private fun longTime(doc: IonDoc): Int {
        val box = idx()
        val n = flexUInt(raw, box).toIntChecked(i)
        pull(box)
        if (n < 2 || n == 4 || n == 5) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val start = takeBits(n)
        val whenTime = IonTime()
        whenTime.year = field(start, 0, 14)
        whenTime.prec = PREC_YEAR
        whenTime.unknown = true
        whenTime.off = 0
        whenTime.month = 1
        whenTime.day = 1
        if (n == 2) return finishTime(doc, whenTime)
        whenTime.month = field(start, 14, 4)
        whenTime.prec = PREC_MONTH
        if (n == 3) {
            val day = field(start, 18, 5)
            if (day != 0) {
                whenTime.day = day
                whenTime.prec = PREC_DAY
            }
            return finishTime(doc, whenTime)
        }
        whenTime.day = field(start, 18, 5)
        whenTime.hour = field(start, 23, 5)
        whenTime.minute = field(start, 28, 6)
        whenTime.prec = PREC_MIN
        val rawOff = field(start, 34, 12)
        if (rawOff == 4095) {
            whenTime.unknown = true
            whenTime.off = 0
        } else {
            whenTime.unknown = false
            whenTime.off = rawOff - 1440
        }
        if (n == 6) return finishTime(doc, whenTime)
        whenTime.second = field(start, 46, 6)
        whenTime.prec = PREC_SEC
        if (n == 7) return finishTime(doc, whenTime)
        val fracAt = start + 7
        val saved = i
        i = fracAt
        val scaleBox = idx()
        val scale = flexUInt(raw, scaleBox).toIntChecked(i)
        pull(scaleBox)
        if (scale == 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val coefN = (start + n) - i
        if (coefN < 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        var coef = 0
        var k = 0
        while (k < coefN) {
            coef = coef or (u8(raw, i + k) shl (k * 8))
            k++
        }
        i = saved
        if (scale > 0 && coef >= 1) {
            var lim = 1
            var p = 0
            while (p < scale) {
                if (lim > 100000000) break
                lim *= 10
                p++
            }
            if (p == scale && coef >= lim) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        putFrac(doc, whenTime, coef, -scale)
        return finishTime(doc, whenTime)
    }

    private fun placeholder(doc: IonDoc, tab: LocalTab, op: Int, cat: Catalog): Int {
        if (!templ) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val rel = paramKind.size - curParam0
        var kind = 0
        var defaultId = -1
        if (op == 0xEB) {
            if (i >= raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
            kind = u8(raw, i)
            i++
        }
        if (op == 0xEA) {
            val saved = templ
            templ = false
            while (i < raw.size && (u8(raw, i) == 0xEC || u8(raw, i) == 0xED)) {
                value(doc, tab, false, cat)
            }
            defaultId = value(doc, tab, false, cat)
            templ = saved
            if (defaultId < 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        paramKind.add(kind)
        paramDefault.add(defaultId)
        val hole = IonNode(K_HOLE)
        hole.a = rel
        hole.b = defaultId
        return doc.addRaw(hole)
    }

    private fun defineMacro(doc: IonDoc, id: Int, param0: Int) {
        val n = doc.nodes[id]
        if (n.kind != K_SEXP || n.nchild != 2) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val nameId = doc.childAt(id, 0)
        val body = doc.childAt(id, 1)
        if (doc.nodes[nameId].kind != K_SYMBOL || doc.nodes[body].kind == K_HOLE) {
            throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        macroName.add(doc.symText(doc.nodes[nameId].a))
        macroRoot.add(body)
        macroParamAt.add(param0)
        macroNparam.add(paramKind.size - param0)
    }

    private fun eexp(doc: IonDoc, tab: LocalTab, op: Int, cat: Catalog): Int {
        var addr = op
        var limit = raw.size
        if (op in 0x48..0x4F) {
            val box = idx()
            val hi = flexUInt(raw, box)
            pull(box)
            addr = (((hi shl 3) or (op - 0x48).toLong()) + 72L).toIntChecked(i)
        }
        if (op == 0xF4) {
            val box = idx()
            addr = flexUInt(raw, box).toIntChecked(i)
            val nbytes = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            limit = i + nbytes
            if (nbytes < 0 || limit > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
        }
        if (addr < 0 || addr >= macroRoot.size) throw DecodeError(DecodeError.KIND_SYMBOL, i)
        val nparam = macroNparam[addr]
        val paramAt = macroParamAt[addr]
        val args = ArrayList<Int>()
        var p = 0
        while (p < nparam) {
            while (i < limit && u8(raw, i) == 0xEC) i++
            if (i >= limit) throw DecodeError(DecodeError.KIND_EOF, i)
            val kind = paramKind[paramAt + p]
            if (kind == 0) {
                if (u8(raw, i) == 0xE0) {
                    i++
                    args.add(-1)
                } else {
                    val arg = value(doc, tab, true, cat)
                    if (arg < 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
                    args.add(arg)
                }
            } else {
                args.add(tagless(doc, tab, kind))
            }
            p++
        }
        if (op == 0xF4 && i != limit) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        return expand(doc, macroRoot[addr], args)
    }

    private fun tagless(doc: IonDoc, tab: LocalTab, code: Int): Int {
        if (code == 0x60) {
            val box = idx()
            val v = flexInt(raw, box)
            pull(box)
            return doc.addI64(v)
        }
        if (code == 0x61 || code == 0x62 || code == 0x64 || code == 0x68) {
            val n = when (code) {
                0x62 -> 2
                0x64 -> 4
                0x68 -> 8
                else -> 1
            }
            return doc.addI64(fixedInt(n))
        }
        if (code == 0xE0) {
            val box = idx()
            val v = flexUInt(raw, box)
            pull(box)
            return doc.addI64(v)
        }
        if (code == 0xE1 || code == 0xE2 || code == 0xE4 || code == 0xE8) {
            val n = when (code) {
                0xE2 -> 2
                0xE4 -> 4
                0xE8 -> 8
                else -> 1
            }
            if (i + n > raw.size) throw DecodeError(DecodeError.KIND_EOF, i)
            var acc = 0L
            var k = 0
            while (k < n) {
                acc = acc or ((raw[i + k].toLong() and 0xFF) shl (k * 8))
                k++
            }
            i += n
            return doc.addI64(acc)
        }
        if (code in 0x6B..0x6D) {
            val n = if (code == 0x6C) 4 else if (code == 0x6D) 8 else 2
            return float(doc, n)
        }
        if (code in 0x82..0x87) return shortTime(doc, code)
        if (code == 0xF8 || code == 0xF9 || code == 0x90) {
            val box = idx()
            val n = flexUInt(raw, box).toIntChecked(i)
            pull(box)
            return doc.addString(text(n))
        }
        throw DecodeError(DecodeError.KIND_SYNTAX, i)
    }

    private fun expand(doc: IonDoc, id: Int, args: List<Int>): Int {
        val n = doc.nodes[id]
        if (n.kind == K_HOLE) {
            var out = -1
            if (n.a < args.size && args[n.a] >= 0) out = args[n.a]
            else if (n.b >= 0) out = expand(doc, n.b, args)
            if (out < 0) return -1
            if (n.annN > 0) {
                val cloned = doc.addRaw(doc.nodes[out].copy())
                val anns = ArrayList<Int>()
                var k = 0
                while (k < n.annN) {
                    anns.add(doc.anns[n.ann + k])
                    k++
                }
                doc.nodes[cloned].ann = -1
                doc.nodes[cloned].annN = 0
                doc.setAnns(cloned, anns)
                return cloned
            }
            return out
        }
        if (n.kind == K_LIST || n.kind == K_SEXP || n.kind == K_STRUCT) {
            val nid = doc.startContainer(n.kind)
            if (n.annN > 0) {
                val anns = ArrayList<Int>()
                var k = 0
                while (k < n.annN) {
                    anns.add(doc.anns[n.ann + k])
                    k++
                }
                doc.setAnns(nid, anns)
            }
            var e = n.child
            var seen = 0
            while (seen < n.nchild) {
                val childId = doc.edgeChild[e]
                val field = doc.edgeField[e]
                val child = expand(doc, childId, args)
                if (child >= 0) doc.addChild(nid, child, field)
                e = doc.edgeNext[e]
                seen++
            }
            return nid
        }
        return id
    }
}

private fun positiveInt(doc: IonDoc, id: Int): Int {
    val n = doc.nodes[id]
    if (n.kind != K_INT || n.c != 0 || n.b > 1) return 1
    if (n.b == 0) return 0
    return doc.limbs[n.a]
}

private fun importNamed(tab: LocalTab, cat: Catalog, name: String, version: Int, offset: Int) {
    if (name.isEmpty()) throw DecodeError(DecodeError.KIND_SYMBOL, offset)
    val idx = cat.exact(name, version)
    if (idx < 0) throw DecodeError(DecodeError.KIND_SYMBOL, offset)
    val n = cat.tables[idx].texts.size
    var k = 0
    while (k < n) {
        if (cat.tables[idx].gap[k]) tab.addGap() else tab.addText(cat.tables[idx].texts[k])
        k++
    }
}

private fun Long.toIntChecked(offset: Int): Int {
    if (this < 0 || this > Int.MAX_VALUE) throw DecodeError(DecodeError.KIND_RANGE, offset)
    return toInt()
}
