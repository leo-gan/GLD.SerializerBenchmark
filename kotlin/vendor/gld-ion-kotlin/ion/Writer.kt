package ion

private class SymMap {
    val texts = ArrayList<String>(8)
    private var index: HashMap<String, Int>? = null

    fun clear() {
        texts.clear()
        index?.clear()
    }

    fun sid(text: String): Int {
        val sys = sysSid(text)
        if (sys != 0) return sys
        val map = index
        if (map != null) {
            val hit = map[text]
            if (hit != null) return hit
            val id = 10 + texts.size
            texts.add(text)
            map[text] = id
            return id
        }
        var i = 0
        val n = texts.size
        while (i < n) {
            if (texts[i] == text) return 10 + i
            i++
        }
        texts.add(text)
        if (n + 1 >= 8) {
            val built = HashMap<String, Int>(16)
            var j = 0
            while (j <= n) {
                built[texts[j]] = 10 + j
                j++
            }
            index = built
        }
        return 10 + n
    }
}

private fun writeIonString(buf: ByteBuf, text: String) {
    var ascii = true
    var i = 0
    while (i < text.length) {
        if (text[i].code >= 128) {
            ascii = false
            break
        }
        i++
    }
    if (ascii && text.length < 14) {
        buf.add((8 shl 4) or text.length)
        i = 0
        while (i < text.length) {
            buf.add(text[i].code)
            i++
        }
        return
    }
    val bytes = text.toByteArray(Charsets.UTF_8)
    if (bytes.size < 14) buf.add((8 shl 4) or bytes.size)
    else {
        buf.add((8 shl 4) or 14)
        varUInt(buf, bytes.size.toLong())
    }
    buf.addAll(bytes)
}

private fun limbsOf(doc: IonDoc, at: Int, n: Int): BigInt {
    val b = BigInt()
    var i = 0
    while (i < n) {
        b.limbs.add(doc.limbs[at + i])
        i++
    }
    return b
}

private fun identOk(text: String): Boolean {
    if (text.isEmpty()) return false
    val c0 = text[0]
    if (c0 in '0'..'9') return false
    if (!((c0 in 'A'..'Z') || (c0 in 'a'..'z') || c0 == '_' || c0 == '$')) return false
    var i = 1
    while (i < text.length) {
        val c = text[i]
        val ok = c in '0'..'9' || c in 'A'..'Z' || c in 'a'..'z' || c == '_' || c == '$'
        if (!ok) return false
        i++
    }
    if (text == "null" || text == "true" || text == "nan" || text == "false") return false
    return true
}

private fun putDec(buf: ByteBuf, neg: Boolean, mag: Long) {
    if (neg) buf.add('-'.code)
    if (mag < 10) {
        buf.add('0'.code + mag.toInt())
        return
    }
    if (mag < 100) {
        buf.add('0'.code + (mag / 10).toInt())
        buf.add('0'.code + (mag % 10).toInt())
        return
    }
    val tmp = IntArray(20)
    var v = mag
    var n = 0
    while (v > 0) {
        tmp[n++] = '0'.code + (v % 10).toInt()
        v /= 10
    }
    var i = n - 1
    while (i >= 0) {
        buf.add(tmp[i])
        i--
    }
}

private fun pad(buf: ByteBuf, n: Int, width: Int) {
    val s = n.toString()
    var i = s.length
    while (i < width) {
        buf.add('0'.code)
        i++
    }
    for (ch in s) buf.add(ch.code)
}

private fun varUInt(buf: ByteBuf, value: Long) {
    var v = if (value < 0) 0L else value
    if (v < 128) {
        buf.add(0x80 or v.toInt())
        return
    }
    val parts = ArrayList<Int>()
    var x = v
    while (x > 0) {
        parts.add((x and 0x7F).toInt())
        x = x ushr 7
    }
    var i = parts.size - 1
    while (i >= 0) {
        var b = parts[i]
        if (i == 0) b = b or 0x80
        buf.add(b)
        i--
    }
}

private fun varInt(buf: ByteBuf, v: Long, neg0: Boolean) {
    val neg = v < 0L || neg0
    var mag = if (v < 0L) {
        if (v == Long.MIN_VALUE) throw DecodeError(DecodeError.KIND_RANGE, 0) else -v
    } else v
    if (mag < 64) {
        var b = 0x80 or mag.toInt()
        if (neg) b = b or 0x40
        buf.add(b)
        return
    }
    val lows = ArrayList<Int>()
    while (mag >= 64) {
        lows.add((mag and 0x7F).toInt())
        mag = mag shr 7
    }
    var first = mag.toInt()
    if (neg) first = first or 0x40
    buf.add(first)
    var i = lows.size - 1
    while (i >= 0) {
        var b = lows[i]
        if (i == 0) b = b or 0x80
        buf.add(b)
        i--
    }
}

private fun td(buf: ByteBuf, t: Int, body: ByteArray) {
    val len = body.size
    if (len < 14) buf.add((t shl 4) or len)
    else {
        buf.add((t shl 4) or 14)
        varUInt(buf, len.toLong())
    }
    buf.addAll(body)
}

private fun seal(buf: ByteBuf, mark: Int, tcode: Int) {
    val len = buf.size - (mark + 1)
    if (len < 14) {
        buf[mark] = (tcode shl 4) or len
        return
    }
    val tail = ByteArray(len)
    var i = 0
    while (i < len) {
        tail[i] = buf[mark + 1 + i].toByte()
        i++
    }
    buf.truncate(mark)
    buf.add((tcode shl 4) or 14)
    varUInt(buf, len.toLong())
    buf.addAll(tail)
}

private fun quoteSym(buf: ByteBuf, text: String) {
    buf.add(39)
    val b = text.toByteArray(Charsets.UTF_8)
    for (byte in b) {
        val c = byte.toInt() and 0xFF
        if (c == 39 || c == 92) {
            buf.add(92)
            buf.add(c)
        } else if (c < 32) {
            hexByte(buf, c)
        } else {
            buf.add(c)
        }
    }
    buf.add(39)
}

private fun hexByte(buf: ByteBuf, c: Int) {
    buf.add(92)
    buf.add('x'.code)
    val hi = (c shr 4) and 15
    val lo = c and 15
    buf.add(if (hi < 10) 48 + hi else 87 + hi)
    buf.add(if (lo < 10) 48 + lo else 87 + lo)
}

private fun symText(buf: ByteBuf, text: String) {
    if (identOk(text)) {
        var i = 0
        while (i < text.length) {
            buf.add(text[i].code)
            i++
        }
    } else {
        quoteSym(buf, text)
    }
}

private fun strText(buf: ByteBuf, text: String) {
    val mark = buf.size
    buf.add(34)
    var i = 0
    val n = text.length
    while (i < n) {
        val c = text[i].code
        if (c < 32 || c == 34 || c == 92 || c >= 128) {
            buf.truncate(mark)
            strTextEscaped(buf, text)
            return
        }
        buf.add(c)
        i++
    }
    buf.add(34)
}

private fun strTextEscaped(buf: ByteBuf, text: String) {
    buf.add(34)
    val b = text.toByteArray(Charsets.UTF_8)
    for (byte in b) {
        val c = byte.toInt() and 0xFF
        when {
            c == 34 || c == 92 -> {
                buf.add(92)
                buf.add(c)
            }
            c == 10 -> {
                buf.add(92)
                buf.add('n'.code)
            }
            c < 32 -> hexByte(buf, c)
            else -> buf.add(c)
        }
    }
    buf.add(34)
}

private fun nl(buf: ByteBuf, options: EncodeOptions, depth: Int) {
    if (!options.pretty) return
    buf.add(10)
    var i = 0
    while (i < depth) {
        buf.add(32)
        buf.add(32)
        i++
    }
}

private fun writeText(doc: IonDoc, id: Int, buf: ByteBuf, options: EncodeOptions, depth: Int) {
    val n = doc.nodes[id]
    var a = 0
    while (a < n.annN) {
        val s = doc.syms[doc.anns[n.ann + a]]
        if (s.text < 0) {
            buf.add('$'.code)
            buf.add('0'.code)
        } else {
            symText(buf, doc.texts[s.text])
        }
        buf.add(':'.code)
        buf.add(':'.code)
        a++
    }
    when (n.kind) {
        K_NULL -> {
            buf.addAll("null".toByteArray(Charsets.US_ASCII))
            if (n.a != 0) {
                buf.add('.'.code)
                val name = when (n.a) {
                    K_BOOL -> "bool"
                    K_INT -> "int"
                    K_FLOAT -> "float"
                    K_DECIMAL -> "decimal"
                    K_TIMESTAMP -> "timestamp"
                    K_STRING -> "string"
                    K_SYMBOL -> "symbol"
                    K_BLOB -> "blob"
                    K_CLOB -> "clob"
                    K_LIST -> "list"
                    K_SEXP -> "sexp"
                    K_STRUCT -> "struct"
                    else -> "null"
                }
                buf.addAll(name.toByteArray(Charsets.US_ASCII))
            }
        }
        K_BOOL -> buf.addAll((if (n.a != 0) "true" else "false").toByteArray(Charsets.US_ASCII))
        K_INT -> {
            if (n.b <= 1) {
                val mag = if (n.b == 0) 0L else u32(doc.limbs[n.a])
                putDec(buf, n.c != 0 && mag != 0L, mag)
            } else {
                val mag = limbsOf(doc, n.a, n.b)
                if (n.c != 0) mag.neg = true
                buf.addAll(mag.toBigInteger().toString().toByteArray(Charsets.US_ASCII))
            }
        }
        K_FLOAT -> floatText(doc, id, buf)
        K_DECIMAL -> decText(doc, id, buf)
        K_TIMESTAMP -> timeText(doc, id, buf)
        K_STRING -> strText(buf, doc.texts[n.a])
        K_SYMBOL -> {
            val s = doc.syms[n.a]
            if (s.text < 0) {
                buf.add('$'.code)
                buf.add('0'.code)
            } else {
                symText(buf, doc.texts[s.text])
            }
        }
        K_BLOB, K_CLOB -> lobText(doc, id, buf)
        K_LIST, K_SEXP -> {
            val open = if (n.kind == K_SEXP) 40 else 91
            val close = if (n.kind == K_SEXP) 41 else 93
            buf.add(open)
            var edge = n.child
            var k = 0
            while (k < n.nchild) {
                if (k > 0) {
                    if (n.kind == K_LIST) buf.add(','.code)
                    else if (!options.pretty) buf.add(' '.code)
                }
                if (options.pretty) nl(buf, options, depth + 1)
                writeText(doc, doc.edgeChild[edge], buf, options, depth + 1)
                edge = doc.edgeNext[edge]
                k++
            }
            if (n.nchild > 0 && options.pretty) nl(buf, options, depth)
            buf.add(close)
        }
        K_STRUCT -> {
            buf.add('{'.code)
            var edge = n.child
            var k = 0
            while (k < n.nchild) {
                if (k > 0) buf.add(','.code)
                if (options.pretty) nl(buf, options, depth + 1)
                val f = doc.syms[doc.edgeField[edge]]
                if (f.text < 0) {
                    buf.add('$'.code)
                    buf.add('0'.code)
                } else {
                    symText(buf, doc.texts[f.text])
                }
                buf.add(':'.code)
                writeText(doc, doc.edgeChild[edge], buf, options, depth + 1)
                edge = doc.edgeNext[edge]
                k++
            }
            if (n.nchild > 0 && options.pretty) nl(buf, options, depth)
            buf.add('}'.code)
        }
        else -> throw DecodeError(DecodeError.KIND_TYPE, 0)
    }
}

private fun floatText(doc: IonDoc, id: Int, buf: ByteBuf) {
    val n = doc.nodes[id]
    val bits = doc.floats[n.b]
    if (n.a == 0) {
        buf.addAll("0e0".toByteArray(Charsets.US_ASCII))
        return
    }
    val f = floatValue(bits, n.a)
    val sign = when (n.a) {
        4 -> (bits.toInt() and 0x80000000.toInt()) != 0
        2 -> (bits and 0x8000L) != 0L
        else -> (bits and (1L shl 63)) != 0L
    }
    if (f.isNaN()) {
        buf.addAll("nan".toByteArray(Charsets.US_ASCII))
        return
    }
    if (f == 0.0 && sign) {
        buf.addAll("-0e0".toByteArray(Charsets.US_ASCII))
        return
    }
    if (f.isInfinite()) {
        buf.addAll((if (sign) "-inf" else "+inf").toByteArray(Charsets.US_ASCII))
        return
    }
    val raw = f.toString()
    var exp = false
    for (ch in raw) {
        if (ch == 'e' || ch == 'E') exp = true
        buf.add(ch.code)
    }
    if (!exp) buf.addAll("e0".toByteArray(Charsets.US_ASCII))
}

private fun decText(doc: IonDoc, id: Int, buf: ByteBuf) {
    val n = doc.nodes[id]
    val mag = limbsOf(doc, n.a, n.b)
    val digits = mag.magDecimal().toByteArray(Charsets.US_ASCII)
    if (n.c != 0) buf.add('-'.code)
    if (n.exp >= 0) {
        buf.addAll(digits)
        buf.add('d'.code)
        buf.addAll(n.exp.toString().toByteArray(Charsets.US_ASCII))
        return
    }
    val frac = (-n.exp).toInt()
    if (digits.size == 1 && digits[0] == '0'.code.toByte()) {
        buf.add('0'.code)
        buf.add('.'.code)
        var z = 0
        while (z < frac) {
            buf.add('0'.code)
            z++
        }
        return
    }
    if (frac >= digits.size) {
        buf.add('0'.code)
        buf.add('.'.code)
        var z = 0
        while (z < frac - digits.size) {
            buf.add('0'.code)
            z++
        }
        buf.addAll(digits)
        return
    }
    val cut = digits.size - frac
    buf.addAll(digits, 0, cut)
    buf.add('.'.code)
    buf.addAll(digits, cut, digits.size - cut)
}

private fun timeText(doc: IonDoc, id: Int, buf: ByteBuf) {
    val t = doc.times[doc.nodes[id].a]
    pad(buf, t.year, 4)
    if (t.prec == PREC_YEAR) {
        buf.add('T'.code)
        return
    }
    buf.add('-'.code)
    pad(buf, t.month, 2)
    if (t.prec == PREC_MONTH) {
        buf.add('T'.code)
        return
    }
    buf.add('-'.code)
    pad(buf, t.day, 2)
    if (t.prec == PREC_DAY) return
    buf.add('T'.code)
    pad(buf, t.hour, 2)
    buf.add(':'.code)
    pad(buf, t.minute, 2)
    if (t.prec >= PREC_SEC) {
        buf.add(':'.code)
        pad(buf, t.second, 2)
    }
    if (t.prec == PREC_FRAC) {
        buf.add('.'.code)
        val mag = limbsOf(doc, t.fracAt, t.fracLen)
        val digits = mag.magDecimal()
        val need = (-t.fracExp).toInt()
        var z = digits.length
        while (z < need) {
            buf.add('0'.code)
            z++
        }
        buf.addAll(digits.toByteArray(Charsets.US_ASCII))
    }
    if (t.unknown) {
        buf.addAll("-00:00".toByteArray(Charsets.US_ASCII))
        return
    }
    if (t.off == 0) {
        buf.add('Z'.code)
        return
    }
    var off = t.off
    if (off < 0) {
        buf.add('-'.code)
        off = -off
    } else {
        buf.add('+'.code)
    }
    pad(buf, off / 60, 2)
    buf.add(':'.code)
    pad(buf, off % 60, 2)
}

private fun lobText(doc: IonDoc, id: Int, buf: ByteBuf) {
    val n = doc.nodes[id]
    buf.add('{'.code)
    buf.add('{'.code)
    if (n.kind == K_CLOB) {
        buf.add('"'.code)
        var i = 0
        val start = doc.blobAt[n.a]
        while (i < doc.blobLen[n.a]) {
            val c = doc.blobBytes[start + i]
            when {
                c == 34 || c == 92 -> {
                    buf.add(92)
                    buf.add(c)
                }
                c in 32..126 -> buf.add(c)
                else -> hexByte(buf, c)
            }
            i++
        }
        buf.add('"'.code)
    } else {
        val alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var i = 0
        val start = doc.blobAt[n.a]
        val length = doc.blobLen[n.a]
        while (i < length) {
            val b0 = doc.blobBytes[start + i]
            var b1 = 0
            var b2 = 0
            var have = 1
            if (i + 1 < length) {
                b1 = doc.blobBytes[start + i + 1]
                have = 2
            }
            if (i + 2 < length) {
                b2 = doc.blobBytes[start + i + 2]
                have = 3
            }
            val v = (b0 shl 16) or (b1 shl 8) or b2
            buf.add(alpha[(v shr 18) and 63].code)
            buf.add(alpha[(v shr 12) and 63].code)
            buf.add(if (have > 1) alpha[(v shr 6) and 63].code else '='.code)
            buf.add(if (have > 2) alpha[v and 63].code else '='.code)
            i += 3
        }
    }
    buf.add('}'.code)
    buf.add('}'.code)
}

fun formatValue(doc: IonDoc, id: Int): String {
    val buf = ByteBuf()
    writeText(doc, id, buf, EncodeOptions(), 0)
    return buf.asString()
}

private val MARK_10 = "\$ion_1_0".toByteArray(Charsets.US_ASCII)
private val MARK_11 = "\$ion_1_1".toByteArray(Charsets.US_ASCII)

private class TextScratch {
    val buf = ByteBuf(2048)
    var busy = false
}

private val textScratch = ThreadLocal.withInitial { TextScratch() }

fun encodeText(doc: IonDoc, options: EncodeOptions): ByteArray {
    val sc = textScratch.get()
    if (sc.busy) return encodeTextInto(doc, options, ByteBuf(64 + doc.top.size * 48))
    sc.busy = true
    try {
        return encodeTextInto(doc, options, sc.buf)
    } finally {
        sc.busy = false
    }
}

private fun encodeTextInto(doc: IonDoc, options: EncodeOptions, buf: ByteBuf): ByteArray {
    buf.truncate(0)
    buf.addAll(if (options.version == 11) MARK_11 else MARK_10)
    var ti = 0
    val tn = doc.top.size
    while (ti < tn) {
        buf.add('\n'.code)
        writeText(doc, doc.top[ti], buf, options, 0)
        ti++
    }
    buf.add('\n'.code)
    return buf.toByteArray()
}

private fun coefBytes(mag: BigInt, neg: Boolean): ByteArray {
    val be = mag.toBeBytes()
    if (be.isEmpty()) return if (neg) byteArrayOf(0x80.toByte()) else ByteArray(0)
    if ((be[0].toInt() and 0x80) != 0) {
        val out = ByteArray(be.size + 1)
        out[0] = if (neg) 0x80.toByte() else 0
        System.arraycopy(be, 0, out, 1, be.size)
        return out
    }
    if (neg) be[0] = (be[0].toInt() or 0x80).toByte()
    return be
}

private fun binValue(doc: IonDoc, id: Int, sm: SymMap, buf: ByteBuf) {
    val n = doc.nodes[id]
    if (n.annN == 0) {
        emitCore(doc, id, sm, buf)
        return
    }
    val bare = ByteBuf()
    emitCore(doc, id, sm, bare)
    val ann = ByteBuf()
    var a = 0
    while (a < n.annN) {
        val s = doc.syms[doc.anns[n.ann + a]]
        val sid = if (s.text >= 0) sm.sid(doc.texts[s.text]) else 0
        varUInt(ann, sid.toLong())
        a++
    }
    val wrapped = ByteBuf()
    varUInt(wrapped, ann.size.toLong())
    wrapped.addAll(ann)
    wrapped.addAll(bare)
    td(buf, 14, wrapped.toByteArray())
}

private fun emitCore(doc: IonDoc, id: Int, sm: SymMap, buf: ByteBuf) {
    val n = doc.nodes[id]
    when {
        n.kind == K_NULL && n.a == 0 -> buf.add(0x0F)
        n.kind == K_NULL -> {
            val code = when (n.a) {
                K_BOOL -> 0x1F
                K_INT -> 0x2F
                K_FLOAT -> 0x4F
                K_DECIMAL -> 0x5F
                K_TIMESTAMP -> 0x6F
                K_SYMBOL -> 0x7F
                K_STRING -> 0x8F
                K_CLOB -> 0x9F
                K_BLOB -> 0xAF
                K_LIST -> 0xBF
                K_SEXP -> 0xCF
                K_STRUCT -> 0xDF
                else -> 0x0F
            }
            buf.add(code)
        }
        n.kind == K_BOOL -> buf.add(if (n.a == 0) 0x10 else 0x11)
        n.kind == K_INT -> {
            if (n.b <= 1) {
                val mag = if (n.b == 0) 0L else u32(doc.limbs[n.a])
                putU32(n.c != 0, mag, buf)
            } else {
                val mag = limbsOf(doc, n.a, n.b)
                td(buf, if (n.c != 0) 3 else 2, mag.toBeBytes())
            }
        }
        n.kind == K_FLOAT -> {
            if (n.a == 0) buf.add(0x40)
            else {
                val bits = doc.floats[n.b]
                val width = n.a
                val tmp = ByteArray(width)
                var s = width - 1
                var k = 0
                while (s >= 0) {
                    tmp[k++] = ((bits ushr (s * 8)) and 0xFF).toByte()
                    s--
                }
                td(buf, 4, tmp)
            }
        }
        n.kind == K_DECIMAL -> {
            val tmp = ByteBuf()
            varInt(tmp, n.exp, false)
            if (n.c != 0 || n.b > 0) tmp.addAll(coefBytes(limbsOf(doc, n.a, n.b), n.c != 0))
            td(buf, 5, tmp.toByteArray())
        }
        n.kind == K_STRING -> writeIonString(buf, doc.texts[n.a])
        n.kind == K_BLOB || n.kind == K_CLOB -> {
            td(buf, if (n.kind == K_CLOB) 9 else 10, doc.blobBytes(n.a))
        }
        n.kind == K_SYMBOL -> {
            val s = doc.syms[n.a]
            val sid = if (s.text >= 0) sm.sid(doc.texts[s.text]) else 0
            if (sid == 0) buf.add(0x70)
            else if (sid < 256) {
                buf.add(0x71)
                buf.add(sid)
            } else if (sid < 65536) {
                buf.add(0x72)
                buf.add((sid shr 8) and 255)
                buf.add(sid and 255)
            } else {
                var x = sid
                val tmp = ArrayList<Int>()
                while (x > 0) {
                    tmp.add(x and 255)
                    x = x ushr 8
                }
                val be = ByteArray(tmp.size)
                var i = 0
                while (i < tmp.size) {
                    be[i] = tmp[tmp.size - 1 - i].toByte()
                    i++
                }
                td(buf, 7, be)
            }
        }
        n.kind == K_TIMESTAMP -> binTime(doc, id, buf)
        n.kind == K_LIST || n.kind == K_SEXP || n.kind == K_STRUCT -> {
            val tcode = if (n.kind == K_SEXP) 12 else if (n.kind == K_STRUCT) 13 else 11
            val mark = buf.size
            buf.add(0)
            var edge = n.child
            var k = 0
            while (k < n.nchild) {
                if (n.kind == K_STRUCT) {
                    val f = doc.syms[doc.edgeField[edge]]
                    val sid = if (f.text >= 0) sm.sid(doc.texts[f.text]) else 0
                    varUInt(buf, sid.toLong())
                }
                binValue(doc, doc.edgeChild[edge], sm, buf)
                edge = doc.edgeNext[edge]
                k++
            }
            seal(buf, mark, tcode)
        }
        else -> throw DecodeError(DecodeError.KIND_TYPE, 0)
    }
}

private fun putU32(neg: Boolean, mag: Long, buf: ByteBuf) {
    val t = if (neg && mag != 0L) 3 else 2
    if (mag == 0L) {
        buf.add(t shl 4)
        return
    }
    if (mag < 256) {
        buf.add((t shl 4) or 1)
        buf.add(mag.toInt())
        return
    }
    if (mag < 65536) {
        buf.add((t shl 4) or 2)
        buf.add(((mag shr 8) and 255).toInt())
        buf.add((mag and 255).toInt())
        return
    }
    if (mag < 16777216) {
        buf.add((t shl 4) or 3)
        buf.add(((mag shr 16) and 255).toInt())
        buf.add(((mag shr 8) and 255).toInt())
        buf.add((mag and 255).toInt())
        return
    }
    buf.add((t shl 4) or 4)
    buf.add(((mag shr 24) and 255).toInt())
    buf.add(((mag shr 16) and 255).toInt())
    buf.add(((mag shr 8) and 255).toInt())
    buf.add((mag and 255).toInt())
}

private fun binTime(doc: IonDoc, id: Int, buf: ByteBuf) {
    val t = doc.times[doc.nodes[id].a]
    val tmp = ByteBuf()
    var year = t.year
    var month = t.month
    var day = t.day
    var hour = t.hour
    var minute = t.minute
    if (t.prec < PREC_MIN || t.unknown) varInt(tmp, 0, true)
    else varInt(tmp, t.off.toLong(), false)
    if (t.prec >= PREC_MIN && !t.unknown && t.off != 0) {
        var total = hour * 60 + minute - t.off
        var days = 0
        while (total < 0) {
            total += 1440
            days--
        }
        while (total >= 1440) {
            total -= 1440
            days++
        }
        hour = total / 60
        minute = total % 60
        if (days != 0) {
            val whenTime = t.copy()
            whenTime.hour = hour
            whenTime.minute = minute
            shiftDays(whenTime, days)
            year = whenTime.year
            month = whenTime.month
            day = whenTime.day
        }
    }
    varUInt(tmp, year.toLong())
    if (t.prec >= PREC_MONTH) varUInt(tmp, month.toLong())
    if (t.prec >= PREC_DAY) varUInt(tmp, day.toLong())
    if (t.prec >= PREC_MIN) {
        varUInt(tmp, hour.toLong())
        varUInt(tmp, minute.toLong())
    }
    if (t.prec >= PREC_SEC) varUInt(tmp, t.second.toLong())
    if (t.prec == PREC_FRAC) {
        varInt(tmp, t.fracExp, false)
        val be = coefBytes(limbsOf(doc, t.fracAt, t.fracLen), false)
        tmp.addAll(be)
    }
    td(buf, 6, tmp.toByteArray())
}

private fun writeSimpleLst(sm: SymMap, buf: ByteBuf) {
    val mark = buf.size
    buf.add(0)
    varUInt(buf, 1)
    varUInt(buf, 3)
    val smark = buf.size
    buf.add(0)
    varUInt(buf, 7)
    val lmark = buf.size
    buf.add(0)
    var s = 0
    while (s < sm.texts.size) {
        writeIonString(buf, sm.texts[s])
        s++
    }
    seal(buf, lmark, 11)
    seal(buf, smark, 13)
    seal(buf, mark, 14)
}

private fun uIntBytes(value: Int): ByteArray {
    if (value == 0) return byteArrayOf(0)
    var x = value
    val tmp = ArrayList<Int>()
    while (x > 0) {
        tmp.add(x and 255)
        x = x ushr 8
    }
    val be = ByteArray(tmp.size)
    var k = 0
    while (k < tmp.size) {
        be[k] = tmp[tmp.size - 1 - k].toByte()
        k++
    }
    return be
}

private fun writeLst(sm: SymMap, options: EncodeOptions, cat: Catalog, buf: ByteBuf) {
    if (sm.texts.isEmpty() && options.importNames.isEmpty()) return
    if (options.importNames.isEmpty()) {
        writeSimpleLst(sm, buf)
        return
    }
    val fields = ByteBuf()
    if (options.importNames.isNotEmpty()) {
        varUInt(fields, 6)
        val items = ByteBuf()
        var i = 0
        while (i < options.importNames.size) {
            val item = ByteBuf()
            varUInt(item, 4)
            td(item, 8, options.importNames[i].toByteArray(Charsets.UTF_8))
            varUInt(item, 5)
            td(item, 2, uIntBytes(options.importVersions[i]))
            var maxId = 0
            val idx = cat.exact(options.importNames[i], options.importVersions[i])
            if (idx >= 0) maxId = cat.tables[idx].texts.size
            varUInt(item, 8)
            td(item, 2, uIntBytes(maxId))
            td(items, 13, item.toByteArray())
            i++
        }
        td(fields, 11, items.toByteArray())
    }
    if (sm.texts.isNotEmpty()) {
        varUInt(fields, 7)
        val items = ByteBuf()
        for (text in sm.texts) td(items, 8, text.toByteArray(Charsets.UTF_8))
        td(fields, 11, items.toByteArray())
    }
    val structed = ByteBuf()
    td(structed, 13, fields.toByteArray())
    val ann = ByteBuf()
    varUInt(ann, 1)
    varUInt(ann, 3)
    ann.addAll(structed)
    td(buf, 14, ann.toByteArray())
}

private fun magLe(doc: IonDoc, at: Int, n: Int): ByteArray {
    val out = ByteBuf()
    var i = 0
    while (i < n) {
        val limb = u32(doc.limbs[at + i])
        var s = 0
        while (s < 32) {
            out.add(((limb shr s) and 0xFF).toInt())
            s += 8
        }
        i++
    }
    var end = out.size
    val raw = out.toByteArray()
    while (end > 1 && raw[end - 1] == 0.toByte()) end--
    if (end == 1 && raw[0] == 0.toByte()) return ByteArray(0)
    return raw.copyOf(end)
}

private fun twos(mag: ByteArray, width: Int, neg: Boolean): ByteArray {
    val out = ByteArray(width)
    if (!neg) {
        var i = 0
        while (i < width) {
            out[i] = if (i < mag.size) mag[i] else 0
            i++
        }
        return out
    }
    var carry = 1
    var i = 0
    while (i < width) {
        val b = if (i < mag.size) mag[i].toInt() and 0xFF else 0
        val inv = (b xor 255) + carry
        out[i] = (inv and 255).toByte()
        carry = inv shr 8
        i++
    }
    return out
}

private fun signedBytes(mag: ByteArray, neg: Boolean): ByteArray {
    if (mag.isEmpty() && !neg) return ByteArray(0)
    var width = if (mag.isEmpty()) 1 else mag.size
    while (true) {
        val raw = twos(mag, width, neg)
        val high = raw.last().toInt() and 128
        if (neg && high != 0) return raw
        if (!neg && high == 0) return raw
        width++
    }
}

private fun putIntBytes(raw: ByteArray, buf: ByteBuf) {
    val n = raw.size
    if (n == 0) {
        buf.add(0x60)
        return
    }
    if (n <= 8) buf.add(0x60 + n)
    else {
        buf.add(0xF5)
        writeFlexUInt(buf, n.toLong())
    }
    buf.addAll(raw)
}

private fun encodeValues11(doc: IonDoc, buf: ByteBuf) {
    for (id in doc.top) value11(doc, id, buf)
}

private fun value11(doc: IonDoc, id: Int, buf: ByteBuf) {
    val n = doc.nodes[id]
    var i = 0
    while (i < n.annN) {
        ann11(doc, doc.anns[n.ann + i], buf)
        i++
    }
    when (n.kind) {
        K_NULL -> null11(n.a, buf)
        K_BOOL -> buf.add(if (n.a == 0) 0x6F else 0x6E)
        K_INT -> {
            if (n.b == 0 && n.c == 0) buf.add(0x60)
            else putIntBytes(signedBytes(magLe(doc, n.a, n.b), n.c != 0), buf)
        }
        K_FLOAT -> {
            if (n.a == 0) buf.add(0x6A)
            else {
                val op = when (n.a) {
                    2 -> 0x6B
                    4 -> 0x6C
                    else -> 0x6D
                }
                val width = if (n.a == 2) 2 else if (n.a == 4) 4 else 8
                buf.add(op)
                val bits = doc.floats[n.b]
                var k = 0
                while (k < width) {
                    buf.add(((bits ushr (k * 8)) and 0xFF).toInt())
                    k++
                }
            }
        }
        K_DECIMAL -> decimal11(doc, n.a, n.b, n.c != 0, n.exp, buf)
        K_TIMESTAMP -> time11(doc, doc.times[n.a], buf)
        K_STRING -> textOp(doc.texts[n.a], 0x90, 0xF8, buf)
        K_SYMBOL -> {
            val s = doc.syms[n.a]
            if (s.text < 0) {
                buf.add(0x50 or (s.sid and 7))
                writeFlexUInt(buf, (s.sid ushr 3).toLong())
            } else {
                textOp(doc.texts[s.text], 0xA0, 0xF9, buf)
            }
        }
        K_BLOB, K_CLOB -> {
            val raw = doc.blobBytes(n.a)
            buf.add(if (n.kind == K_BLOB) 0xFE else 0xFF)
            writeFlexUInt(buf, raw.size.toLong())
            buf.addAll(raw)
        }
        K_LIST, K_SEXP, K_STRUCT -> container11(doc, id, buf)
        else -> throw DecodeError(DecodeError.KIND_TYPE, 0)
    }
}

private fun null11(typeKind: Int, buf: ByteBuf) {
    if (typeKind == 0) {
        buf.add(0x8E)
        return
    }
    val code = when (typeKind) {
        K_BOOL -> 1
        K_INT -> 2
        K_FLOAT -> 3
        K_DECIMAL -> 4
        K_TIMESTAMP -> 5
        K_STRING -> 6
        K_SYMBOL -> 7
        K_BLOB -> 8
        K_CLOB -> 9
        K_LIST -> 10
        K_SEXP -> 11
        K_STRUCT -> 12
        else -> 0
    }
    if (code == 0) {
        buf.add(0x8E)
        return
    }
    buf.add(0x8F)
    buf.add(code)
}

private fun ann11(doc: IonDoc, sym: Int, buf: ByteBuf) {
    val s = doc.syms[sym]
    if (s.text < 0) {
        buf.add(0x58)
        writeFlexUInt(buf, s.sid.toLong())
        return
    }
    val raw = doc.texts[s.text].toByteArray(Charsets.UTF_8)
    buf.add(0x59)
    writeFlexUInt(buf, raw.size.toLong())
    buf.addAll(raw)
}

private fun textOp(text: String, shortBase: Int, longOp: Int, buf: ByteBuf) {
    var ascii = text.length <= 15
    var i = 0
    while (ascii && i < text.length) {
        if (text[i].code >= 128) ascii = false
        i++
    }
    if (ascii) {
        buf.add(shortBase + text.length)
        buf.addUtf8(text)
        return
    }
    val raw = text.toByteArray(Charsets.UTF_8)
    if (raw.size <= 15) buf.add(shortBase + raw.size)
    else {
        buf.add(longOp)
        writeFlexUInt(buf, raw.size.toLong())
    }
    buf.addAll(raw)
}

private fun decimal11(doc: IonDoc, at: Int, n: Int, neg: Boolean, exp: Long, buf: ByteBuf) {
    if (n == 0 && !neg && exp == 0L) {
        buf.add(0x70)
        return
    }
    val body = ByteBuf()
    writeFlexInt(body, exp)
    if (n > 0 || neg) {
        val mag = magLe(doc, at, n)
        if (mag.isEmpty() && neg) body.add(0)
        else body.addAll(signedBytes(mag, neg))
    }
    val len = body.size
    if (len <= 15) buf.add(0x70 + len)
    else {
        buf.add(0xF6)
        writeFlexUInt(buf, len.toLong())
    }
    buf.addAll(body)
}

private fun container11(doc: IonDoc, id: Int, buf: ByteBuf) {
    val n = doc.nodes[id]
    val body = ByteBuf()
    var edge = n.child
    var i = 0
    while (i < n.nchild) {
        if (n.kind == K_STRUCT) {
            val field = doc.edgeField[edge]
            val text = if (field >= 0 && doc.syms[field].text >= 0) doc.texts[doc.syms[field].text] else ""
            val nb = text.toByteArray(Charsets.UTF_8)
            writeFlexInt(body, -1L - nb.size)
            body.addAll(nb)
        }
        value11(doc, doc.edgeChild[edge], body)
        edge = doc.edgeNext[edge]
        i++
    }
    if (n.kind == K_STRUCT && body.size == 0) {
        buf.add(0xD0)
        return
    }
    val len = body.size
    if (n.kind == K_STRUCT) {
        buf.add(0xFD)
        writeFlexUInt(buf, len.toLong())
    } else if (len <= 15) {
        val base = if (n.kind == K_SEXP) 0xC0 else 0xB0
        buf.add(base + len)
    } else {
        buf.add(if (n.kind == K_SEXP) 0xFB else 0xFA)
        writeFlexUInt(buf, len.toLong())
    }
    buf.addAll(body)
}

private fun putBits(raw: ByteBuf, nbits: IntArray, value: Int, width: Int) {
    var k = 0
    while (k < width) {
        val bit = (value shr k) and 1
        val pos = nbits[0]
        val bi = pos / 8
        while (raw.size <= bi) raw.add(0)
        raw[bi] = raw[bi] or (bit shl (pos % 8))
        nbits[0] = nbits[0] + 1
        k++
    }
}

private fun time11(doc: IonDoc, t: IonTime, buf: ByteBuf) {
    val raw = ByteBuf()
    val nbits = intArrayOf(0)
    putBits(raw, nbits, t.year, 14)
    var length = 2
    if (t.prec >= PREC_MONTH) {
        val day = if (t.prec >= PREC_DAY) t.day else 0
        putBits(raw, nbits, t.month, 4)
        putBits(raw, nbits, day, 5)
        length = 3
    }
    if (t.prec >= PREC_MIN) {
        putBits(raw, nbits, t.hour, 5)
        putBits(raw, nbits, t.minute, 6)
        var off = 4095
        if (!t.unknown) {
            off = t.off + 1440
            if (off < 0 || off > 4094) throw DecodeError(DecodeError.KIND_RANGE, 0)
        }
        putBits(raw, nbits, off, 12)
        length = 6
    }
    if (t.prec >= PREC_SEC) {
        putBits(raw, nbits, t.second, 6)
        length = 7
    }
    val frac = ByteBuf()
    if (t.prec == PREC_FRAC) {
        val scale = -t.fracExp
        if (scale < 1) throw DecodeError(DecodeError.KIND_SYNTAX, 0)
        writeFlexUInt(frac, scale)
        val mag = magLe(doc, t.fracAt, t.fracLen)
        if (mag.isEmpty()) frac.add(0) else frac.addAll(mag)
        length = 7 + frac.size
    }
    buf.add(0xF7)
    writeFlexUInt(buf, length.toLong())
    var i = 0
    while (i < length && i < raw.size) {
        buf.add(raw[i])
        i++
    }
    while (i < length && t.prec < PREC_FRAC) {
        buf.add(0)
        i++
    }
    if (t.prec == PREC_FRAC) buf.addAll(frac)
}

private class BinScratch {
    val head = ByteBuf(1024)
    val body = ByteBuf(1024)
    val syms = SymMap()
    var busy = false
}

private val binScratch = ThreadLocal.withInitial { BinScratch() }

fun encodeBinary(doc: IonDoc, options: EncodeOptions, cat: Catalog): ByteArray {
    if (options.version == 11) {
        val buf = ByteBuf()
        buf.add(0xE0)
        buf.add(0x01)
        buf.add(0x01)
        buf.add(0xEA)
        encodeValues11(doc, buf)
        return buf.toByteArray()
    }
    val sc = binScratch.get()
    if (sc.busy) return encodeBinary10(doc, options, cat, ByteBuf(1024), ByteBuf(1024), SymMap())
    sc.busy = true
    try {
        sc.head.truncate(0)
        sc.body.truncate(0)
        sc.syms.clear()
        return encodeBinary10(doc, options, cat, sc.head, sc.body, sc.syms)
    } finally {
        sc.busy = false
    }
}

private fun encodeBinary10(
    doc: IonDoc,
    options: EncodeOptions,
    cat: Catalog,
    buf: ByteBuf,
    body: ByteBuf,
    sm: SymMap,
): ByteArray {
    buf.add(0xE0)
    buf.add(0x01)
    buf.add(0x00)
    buf.add(0xEA)
    var ti = 0
    val tn = doc.top.size
    while (ti < tn) {
        binValue(doc, doc.top[ti], sm, body)
        ti++
    }
    writeLst(sm, options, cat, buf)
    buf.addAll(body)
    return buf.toByteArray()
}
