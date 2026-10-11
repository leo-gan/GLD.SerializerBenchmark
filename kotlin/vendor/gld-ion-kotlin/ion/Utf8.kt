package ion

internal fun validateUtf8(span: ByteArray, offset: Int) {
    validateUtf8(span, 0, span.size, offset)
}

internal fun validateUtf8(span: ByteArray, from: Int, to: Int, offset: Int) {
    var i = from
    while (i < to) {
        val c = span[i].toInt() and 0xFF
        if (c < 0x80) {
            i++
            continue
        }
        val need: Int
        var cp: Int
        val minCp: Int
        when {
            c in 0xC2..0xDF -> {
                need = 1
                cp = c and 0x1F
                minCp = 0x80
            }
            c in 0xE0..0xEF -> {
                need = 2
                cp = c and 0x0F
                minCp = 0x800
            }
            c in 0xF0..0xF4 -> {
                need = 3
                cp = c and 0x07
                minCp = 0x10000
            }
            else -> throw DecodeError(DecodeError.KIND_UTF8, offset + (i - from))
        }
        if (i + need >= to) throw DecodeError(DecodeError.KIND_UTF8, offset + (i - from))
        var k = 0
        while (k < need) {
            i++
            val cc = span[i].toInt() and 0xFF
            if ((cc and 0xC0) != 0x80) throw DecodeError(DecodeError.KIND_UTF8, offset + (i - from))
            cp = (cp shl 6) or (cc and 0x3F)
            k++
        }
        if (cp < minCp || cp > 0x10FFFF || cp in 0xD800..0xDFFF) {
            throw DecodeError(DecodeError.KIND_UTF8, offset + (i - from))
        }
        i++
    }
}

internal fun appendUtf8(buf: ByteBuf, cp: Int, offset: Int) {
    if (cp < 0 || cp > 0x10FFFF || cp in 0xD800..0xDFFF) {
        throw DecodeError(DecodeError.KIND_ESCAPE, offset)
    }
    when {
        cp < 0x80 -> buf.add(cp)
        cp < 0x800 -> {
            buf.add(0xC0 or (cp shr 6))
            buf.add(0x80 or (cp and 0x3F))
        }
        cp < 0x10000 -> {
            buf.add(0xE0 or (cp shr 12))
            buf.add(0x80 or ((cp shr 6) and 0x3F))
            buf.add(0x80 or (cp and 0x3F))
        }
        else -> {
            buf.add(0xF0 or (cp shr 18))
            buf.add(0x80 or ((cp shr 12) and 0x3F))
            buf.add(0x80 or ((cp shr 6) and 0x3F))
            buf.add(0x80 or (cp and 0x3F))
        }
    }
}

internal fun isAscii(raw: ByteArray): Boolean {
    var i = 0
    var bits = 0
    val n = raw.size
    while (i + 4 <= n) {
        bits = bits or (raw[i].toInt() and 0xFF) or (raw[i + 1].toInt() and 0xFF) or
            (raw[i + 2].toInt() and 0xFF) or (raw[i + 3].toInt() and 0xFF)
        i += 4
    }
    while (i < n) {
        bits = bits or (raw[i].toInt() and 0xFF)
        i++
    }
    return (bits and 128) == 0
}

internal fun isWide(raw: ByteArray): Boolean {
    if (raw.size >= 4 && u8(raw, 0) == 0 && u8(raw, 1) == 0 && u8(raw, 2) == 0) return true
    if (raw.size >= 4 && u8(raw, 0) != 0 && u8(raw, 1) == 0 && u8(raw, 2) == 0 && u8(raw, 3) == 0) return true
    if (raw.size >= 2 && u8(raw, 0) == 0 && u8(raw, 1) != 0) return true
    if (raw.size >= 2 && u8(raw, 0) != 0 && u8(raw, 1) == 0) return true
    return false
}

internal fun utf8FromWide(raw: ByteArray): ByteArray {
    val out = ByteBuf(raw.size)
    var width = 1
    var be = true
    if (raw.size >= 4 && u8(raw, 0) == 0 && u8(raw, 1) == 0 && u8(raw, 2) == 0) {
        width = 4
    } else if (raw.size >= 4 && u8(raw, 0) != 0 && u8(raw, 1) == 0 && u8(raw, 2) == 0 && u8(raw, 3) == 0) {
        width = 4
        be = false
    } else if (raw.size >= 2 && u8(raw, 0) == 0 && u8(raw, 1) != 0) {
        width = 2
    } else if (raw.size >= 2 && u8(raw, 0) != 0 && u8(raw, 1) == 0) {
        width = 2
        be = false
    }
    if (width == 1) return raw
    if (raw.size % width != 0) throw DecodeError(DecodeError.KIND_UTF8, 0)
    var i = 0
    while (i < raw.size) {
        var cp = 0
        var b = 0
        while (b < width) {
            val idx = if (be) i + b else i + width - 1 - b
            cp = (cp shl 8) or u8(raw, idx)
            b++
        }
        i += width
        if (width == 2 && cp in 0xD800..0xDBFF && i + 1 < raw.size) {
            val low = if (be) (u8(raw, i) shl 8) or u8(raw, i + 1) else (u8(raw, i + 1) shl 8) or u8(raw, i)
            if (low in 0xDC00..0xDFFF) {
                cp = 0x10000 + ((cp - 0xD800) shl 10) + (low - 0xDC00)
                i += 2
            }
        }
        appendUtf8(out, cp, i)
    }
    return out.toByteArray()
}
