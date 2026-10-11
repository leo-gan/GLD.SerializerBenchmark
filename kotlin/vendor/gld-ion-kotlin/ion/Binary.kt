package ion

internal class BinParser(val raw: ByteArray) {
    var i: Int = 0
    val n: Int = raw.size
    var depth: Int = 0
    private var cacheSid0 = -1
    private var cacheSym0 = -1
    private var cacheSid1 = -1
    private var cacheSym1 = -1

    private fun clearSidCache() {
        cacheSid0 = -1
        cacheSid1 = -1
    }

    private fun b(): Int {
        if (i >= n) throw DecodeError(DecodeError.KIND_EOF, i)
        return raw[i++].toInt() and 0xFF
    }

    private fun varUInt(): Long {
        var b0 = b()
        if ((b0 and 0x80) != 0) return (b0 and 0x7F).toLong()
        var acc = (b0 and 0x7F).toLong()
        var k = 1
        while (k < 10) {
            val bb = b()
            if (acc > 0x00FFFFFFFFFFFFFFL / 128L) throw DecodeError(DecodeError.KIND_RANGE, i)
            acc = (acc shl 7) or (bb and 0x7F).toLong()
            if ((bb and 0x80) != 0) return acc
            k++
        }
        throw DecodeError(DecodeError.KIND_RANGE, i)
    }

    private fun lenOf(v: Long): Int {
        if (v < 0 || v > Int.MAX_VALUE) throw DecodeError(DecodeError.KIND_RANGE, i)
        return v.toInt()
    }

    /** Returns the value and sets [neg0] when the encoding is negative zero. */
    private fun varInt(): Pair<Long, Boolean> {
        var bb = b()
        val neg = (bb and 0x40) != 0
        var acc = (bb and 0x3F).toLong()
        var guard = 0
        while ((bb and 0x80) == 0) {
            guard++
            if (guard > 10) throw DecodeError(DecodeError.KIND_RANGE, i)
            bb = b()
            if (acc > 0x00FFFFFFFFFFFFFFL / 128L) throw DecodeError(DecodeError.KIND_RANGE, i)
            acc = (acc shl 7) or (bb and 0x7F).toLong()
        }
        if (neg && acc == 0L) return Pair(0L, true)
        return if (neg) Pair(-acc, false) else Pair(acc, false)
    }

    private fun take(len: Int): ByteArray {
        if (len < 0 || i + len > n || i + len < i) throw DecodeError(DecodeError.KIND_EOF, i)
        val out = raw.copyOfRange(i, i + len)
        i += len
        return out
    }

    private fun reprLen(ln: Int): Int {
        if (ln == 14) return lenOf(varUInt())
        return ln
    }

    fun readAll(doc: IonDoc, tab: LocalTab, cat: Catalog) {
        if (n == 0) return
        var ver = bvm()
        while (i < n) {
            ver = if (ver == 11) read11(doc, tab, cat) else read10(doc, tab, cat)
        }
    }

    private fun read10(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        while (i < n) {
            if (atBvm()) {
                val next = bvm()
                tab.resetSystem()
                clearSidCache()
                return next
            }
            val id = value(doc, tab, false)
            if (id < 0) continue
            if (isLocalTable(doc, id)) {
                applyLst(doc, id, tab, cat, i)
                clearSidCache()
                continue
            }
            doc.addTop(id)
        }
        return 10
    }

    private fun read11(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        val r11 = Ion11(raw)
        r11.i = i
        while (r11.i < n) {
            i = r11.i
            if (atBvm()) {
                val next = bvm()
                tab.resetSystem()
                clearSidCache()
                r11.clearMacros()
                if (next != 11) return next
                r11.i = i
                continue
            }
            val id11 = r11.value(doc, tab, false, cat)
            i = r11.i
            if (id11 >= 0 && !isLocalTable(doc, id11)) doc.addTop(id11)
        }
        i = r11.i
        return 11
    }

    private fun atBvm(): Boolean {
        if (i + 3 >= n) return false
        return u8(raw, i) == 0xE0 && u8(raw, i + 1) == 0x01 && u8(raw, i + 3) == 0xEA
    }

    private fun bvm(): Int {
        if (i + 3 >= n) throw DecodeError(DecodeError.KIND_VERSION, i)
        if (u8(raw, i) != 0xE0 || u8(raw, i + 3) != 0xEA || u8(raw, i + 1) != 0x01) {
            throw DecodeError(DecodeError.KIND_VERSION, i)
        }
        val minor = u8(raw, i + 2)
        i += 4
        if (minor == 0) return 10
        if (minor == 1) return 11
        throw DecodeError(DecodeError.KIND_VERSION, i)
    }

    private fun value(doc: IonDoc, tab: LocalTab, inAnn: Boolean): Int {
        if (depth > 1024) throw DecodeError(DecodeError.KIND_DEPTH, i)
        if (i < n) {
            val td0 = raw[i].toInt() and 0xFF
            val t0 = td0 shr 4
            val ln0 = td0 and 15
            if (t0 == 2 && ln0 == 0) {
                i++
                return doc.addI64(0)
            }
            if (t0 == 2 && ln0 == 1 && i + 1 < n) {
                val one = raw[i + 1].toInt() and 0xFF
                i += 2
                return doc.addI64(one.toLong())
            }
            if (t0 == 8 && ln0 < 14 && i + 1 + ln0 <= n) {
                i++
                val from = i
                i += ln0
                return doc.addStringRaw(raw, from, i, from)
            }
        }
        val td = b()
        val t = td shr 4
        val ln = td and 0x0F
        if (t == 0) {
            if (ln == 15) return doc.addNull(0)
            val skip = if (ln == 14) lenOf(varUInt()) else ln
            take(skip)
            return -1
        }
        if (t == 15) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        if (t == 14) return ann(doc, tab, ln, inAnn)
        if (t == 1) {
            if (ln == 0) return doc.addBool(false)
            if (ln == 1) return doc.addBool(true)
            if (ln == 15) return doc.addNull(K_BOOL)
            throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (t == 2 || t == 3) {
            if (ln == 15) return doc.addNull(K_INT)
            if (t == 3 && ln == 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
            val size = reprLen(ln)
            if (size == 0) return doc.addI64(0)
            if (size == 1) {
                val one = b()
                if (t == 3 && one == 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
                return if (t == 3) doc.addI64(-one.toLong()) else doc.addI64(one.toLong())
            }
            if (size <= 8) {
                if (i + size > n) throw DecodeError(DecodeError.KIND_EOF, i)
                var mag = 0L
                var k = 0
                while (k < size) {
                    mag = (mag shl 8) or u8(raw, i + k).toLong()
                    k++
                }
                i += size
                if (t == 3 && mag == 0L) throw DecodeError(DecodeError.KIND_SYNTAX, i)
                if (mag >= 0 && mag <= Long.MAX_VALUE) {
                    return if (t == 3) doc.addI64(-mag) else doc.addI64(mag)
                }
                if (t == 3 && mag == Long.MIN_VALUE) return doc.addI64(Long.MIN_VALUE)
                // mag's high bit is set: value does not fit in a positive Long, or is 2^63.
                val big = bigFromU64(mag, t == 3)
                if (t == 3 && mag == Long.MIN_VALUE) return doc.addI64(Long.MIN_VALUE)
                return doc.addInt(big)
            }
            val mag = bigFromBe(take(size), false, i)
            if (t == 3) {
                if (mag.isZero()) throw DecodeError(DecodeError.KIND_SYNTAX, i)
                mag.neg = true
            }
            return doc.addInt(mag)
        }
        if (t == 4) {
            if (ln == 15) return doc.addNull(K_FLOAT)
            if (ln == 0) return doc.addFloat(0, 0L)
            if (ln != 4 && ln != 8) throw DecodeError(DecodeError.KIND_SYNTAX, i)
            return float(doc, ln)
        }
        if (t == 5) {
            if (ln == 15) return doc.addNull(K_DECIMAL)
            if (ln == 0) return doc.addDecimal(BigInt(), false, 0)
            val size = reprLen(ln)
            return decimal(doc, i + size)
        }
        if (t == 6) {
            if (ln == 15) return doc.addNull(K_TIMESTAMP)
            if (ln < 2) throw DecodeError(DecodeError.KIND_SYNTAX, i)
            val size = reprLen(ln)
            return time(doc, i + size)
        }
        if (t == 7) {
            if (ln == 15) return doc.addNull(K_SYMBOL)
            if (ln == 0) return symFromSid(doc, tab, 0, i)
            val size = reprLen(ln)
            val sid = uint(size)
            return symFromSid(doc, tab, sid, i)
        }
        if (t == 8 || t == 9 || t == 10) {
            val kind = if (t == 9) K_CLOB else if (t == 10) K_BLOB else K_STRING
            if (ln == 15) return doc.addNull(kind)
            val size = reprLen(ln)
            val span = take(size)
            if (t == 8) return doc.addStringRaw(span, 0, span.size, i)
            return doc.addBytes(kind, span)
        }
        if (t == 11 || t == 12 || t == 13) return container(doc, tab, t, ln)
        throw DecodeError(DecodeError.KIND_SYNTAX, i)
    }

    private fun float(doc: IonDoc, len: Int): Int {
        val span = take(len)
        var bits = 0L
        var k = 0
        while (k < len) {
            bits = (bits shl 8) or (span[k].toLong() and 0xFF)
            k++
        }
        return doc.addFloat(len, bits)
    }

    private fun uint(len: Int): Int {
        val span = take(len)
        var acc = 0L
        var k = 0
        while (k < span.size) {
            if (acc > 0x00FFFFFFFFFFFFFFL / 256L) throw DecodeError(DecodeError.KIND_RANGE, i)
            acc = (acc shl 8) or (span[k].toLong() and 0xFF)
            k++
        }
        if (acc > Int.MAX_VALUE) throw DecodeError(DecodeError.KIND_RANGE, i)
        return acc.toInt()
    }

    private fun decimal(doc: IonDoc, end: Int): Int {
        val (exp, _) = varInt()
        if (i > end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val (coef, neg0) = signedMag(end - i)
        if (i != end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val neg = coef.neg || neg0
        coef.neg = false
        return doc.addDecimal(coef, neg, exp)
    }

    private fun signedMag(len: Int): Pair<BigInt, Boolean> {
        if (len == 0) return Pair(BigInt(), false)
        val span = take(len)
        val first = span[0].toInt() and 0xFF
        val neg = (first and 0x80) != 0
        val buf = ByteArray(span.size)
        buf[0] = (first and 0x7F).toByte()
        if (span.size > 1) System.arraycopy(span, 1, buf, 1, span.size - 1)
        val mag = bigFromBe(buf, false, i)
        if (neg && mag.isZero()) return Pair(mag, true)
        if (neg) mag.neg = true
        return Pair(mag, false)
    }

    private fun time(doc: IonDoc, end: Int): Int {
        val (off, neg0) = varInt()
        if (i >= end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val year = lenOf(varUInt())
        if (year < 1 || year > 999999999) throw DecodeError(DecodeError.KIND_RANGE, i)
        val whenTime = IonTime()
        whenTime.year = year
        whenTime.prec = PREC_YEAR
        whenTime.unknown = neg0
        whenTime.off = off.toInt()
        if (i < end) {
            whenTime.month = lenOf(varUInt())
            whenTime.prec = PREC_MONTH
            if (whenTime.month !in 1..12) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (i < end) {
            whenTime.day = lenOf(varUInt())
            whenTime.prec = PREC_DAY
            if (whenTime.day < 1 || whenTime.day > daysInMonth(whenTime.year, whenTime.month)) {
                throw DecodeError(DecodeError.KIND_SYNTAX, i)
            }
        }
        if (i < end) {
            whenTime.hour = lenOf(varUInt())
            if (i >= end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
            whenTime.minute = lenOf(varUInt())
            whenTime.prec = PREC_MIN
            if (whenTime.hour > 23 || whenTime.minute > 59) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (i < end) {
            whenTime.second = lenOf(varUInt())
            whenTime.prec = PREC_SEC
            if (whenTime.second > 59) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (i < end) {
            val (fexp, _) = varInt()
            var coef = BigInt()
            if (i < end) {
                val (read, nz) = signedMag(end - i)
                coef = read
                if (coef.neg && !nz) throw DecodeError(DecodeError.KIND_SYNTAX, i)
                if (nz) coef = BigInt()
            } else if (i != end) {
                throw DecodeError(DecodeError.KIND_SYNTAX, i)
            }
            val drop = coef.isZero() && fexp >= 0
            if (!drop && fracGeOne(coef, fexp)) throw DecodeError(DecodeError.KIND_SYNTAX, i)
            if (!drop) {
                if (fexp >= 0 && !coef.isZero()) throw DecodeError(DecodeError.KIND_SYNTAX, i)
                whenTime.prec = PREC_FRAC
                whenTime.fracExp = fexp
                whenTime.fracAt = doc.limbs.size
                whenTime.fracLen = coef.limbs.size
                doc.limbs.addAll(coef.limbs)
            }
        }
        if (i != end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        if (whenTime.prec < PREC_MIN) {
            whenTime.unknown = true
            whenTime.off = 0
        } else if (!whenTime.unknown) {
            if (off > Int.MAX_VALUE || off < Int.MIN_VALUE) throw DecodeError(DecodeError.KIND_RANGE, i)
            applyOffset(whenTime, whenTime.off)
        }
        return doc.addTime(whenTime)
    }

    private fun container(doc: IonDoc, tab: LocalTab, t: Int, ln: Int): Int {
        val kind = if (t == 12) K_SEXP else if (t == 13) K_STRUCT else K_LIST
        if (ln == 15) return doc.addNull(kind)
        if (ln == 0) return doc.startContainer(kind)
        var size = ln
        if (ln == 14 || (t == 13 && ln == 1)) {
            size = lenOf(varUInt())
            if (t == 13 && ln == 1 && size == 0) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        }
        if (size < 0 || i > n - size) throw DecodeError(DecodeError.KIND_EOF, i)
        val end = i + size
        depth++
        val id = doc.startContainer(kind)
        while (i < end) {
            if (t == 13 && i + 1 < end) {
                val b0 = raw[i].toInt() and 0xFF
                if ((b0 and 0x80) != 0) {
                    val td = raw[i + 1].toInt() and 0xFF
                    val tt = td shr 4
                    val ln = td and 15
                    if (tt == 2 && ln == 0) {
                        i += 2
                        doc.addChild(id, doc.addI64(0), fieldSlot(doc, tab, b0 and 0x7F))
                        continue
                    }
                    if (tt == 2 && ln == 1 && i + 2 < end) {
                        val one = raw[i + 2].toInt() and 0xFF
                        i += 3
                        doc.addChild(id, doc.addI64(one.toLong()), fieldSlot(doc, tab, b0 and 0x7F))
                        continue
                    }
                    if (tt == 8 && ln < 14 && i + 2 + ln <= end) {
                        i += 2
                        val from = i
                        i += ln
                        doc.addChild(id, doc.addStringRaw(raw, from, i, from), fieldSlot(doc, tab, b0 and 0x7F))
                        continue
                    }
                }
            }
            if (t == 13) {
                val bb = u8(raw, i)
                val sid = if ((bb and 0x80) != 0) {
                    i++
                    bb and 0x7F
                } else {
                    lenOf(varUInt())
                }
                val child = value(doc, tab, false)
                if (child < 0) continue
                val slot = fieldSlot(doc, tab, sid)
                doc.addChild(id, child, slot)
            } else {
                val child = value(doc, tab, false)
                if (child < 0) continue
                doc.addChild(id, child, -1)
            }
        }
        depth--
        if (i != end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        return id
    }

    private fun fieldSlot(doc: IonDoc, tab: LocalTab, sid: Int): Int {
        if (sid == cacheSid0 && cacheSym0 >= 0) return cacheSym0
        if (sid == cacheSid1 && cacheSym1 >= 0) return cacheSym1
        val sym = symFromSid(doc, tab, sid, i)
        val slot = doc.nodes[sym].a
        cacheSid1 = cacheSid0
        cacheSym1 = cacheSym0
        cacheSid0 = sid
        cacheSym0 = slot
        return slot
    }

    private fun ann(doc: IonDoc, tab: LocalTab, ln: Int, inAnn: Boolean): Int {
        if (inAnn || ln < 3 || ln == 15) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val size = reprLen(ln)
        if (size < 0 || i > n - size) throw DecodeError(DecodeError.KIND_EOF, i)
        val end = i + size
        val alen = lenOf(varUInt())
        if (alen <= 0 || i > end - alen) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val annotEnd = i + alen
        val anns = ArrayList<Int>()
        while (i < annotEnd) {
            val sid = lenOf(varUInt())
            val sym = symFromSid(doc, tab, sid, i)
            anns.add(doc.nodes[sym].a)
        }
        if (i != annotEnd || anns.isEmpty()) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        val id = value(doc, tab, true)
        if (id < 0 || i != end) throw DecodeError(DecodeError.KIND_SYNTAX, i)
        doc.setAnns(id, anns)
        return id
    }
}

fun decodeBinary(raw: ByteArray, cat: Catalog): IonDoc {
    val doc = IonDoc()
    val guess = raw.size / 3 + 8
    doc.nodes.ensureCapacity(guess)
    doc.ensureEdges(guess)
    doc.top.ensureCapacity(guess)
    doc.texts.ensureCapacity(16)
    doc.syms.ensureCapacity(16)
    return withLocalTab { tab ->
        BinParser(raw).readAll(doc, tab, cat)
        doc
    }
}
