package ion

internal class TextParser(val raw: ByteArray) {
    var i: Int = 0
    val n: Int = raw.size
    var depth: Int = 0
    var sexp: Int = 0
    var ver: Int = 10
    var bareIvm: Int = 0
    var templ: Boolean = false
    var curParam0: Int = 0
    private var macroNameStore: ArrayList<String>? = null
    private var macroRootStore: ArrayList<Int>? = null
    private var macroParamAtStore: ArrayList<Int>? = null
    private var macroNparamStore: ArrayList<Int>? = null
    private var paramKindStore: ArrayList<Int>? = null
    private var paramDefaultStore: ArrayList<Int>? = null
    private val macroName: ArrayList<String>
        get() = macroNameStore ?: ArrayList<String>().also { macroNameStore = it }
    private val macroRoot: ArrayList<Int>
        get() = macroRootStore ?: ArrayList<Int>().also { macroRootStore = it }
    private val macroParamAt: ArrayList<Int>
        get() = macroParamAtStore ?: ArrayList<Int>().also { macroParamAtStore = it }
    private val macroNparam: ArrayList<Int>
        get() = macroNparamStore ?: ArrayList<Int>().also { macroNparamStore = it }
    private val paramKind: ArrayList<Int>
        get() = paramKindStore ?: ArrayList<Int>().also { paramKindStore = it }
    private val paramDefault: ArrayList<Int>
        get() = paramDefaultStore ?: ArrayList<Int>().also { paramDefaultStore = it }

    private fun b(): Int = raw[i].toInt() and 0xFF
    private fun at(k: Int): Int = raw[k].toInt() and 0xFF

    private fun syntax(): DecodeError = DecodeError(DecodeError.KIND_SYNTAX, i)
    private fun eof(): DecodeError = DecodeError(DecodeError.KIND_EOF, i)

    fun readAll(doc: IonDoc, tab: LocalTab, cat: Catalog) {
        while (true) {
            skipWs()
            if (i >= n) return
            bareIvm = 0
            val id = parseValue(doc, tab, cat)
            if (id < 0) continue
            if (bareIvm == 10) {
                tab.resetSystem()
                clearMacros()
                ver = 10
                continue
            }
            if (bareIvm == 11) {
                tab.resetSystem()
                clearMacros()
                ver = 11
                continue
            }
            if (ivmNop(doc, id)) continue
            if (ver == 10 && isLocalTable(doc, id)) {
                applyLst(doc, id, tab, cat, i)
                continue
            }
            if (ver == 11 && isLocalTable(doc, id)) continue
            doc.addTop(id)
        }
    }

    fun parseValue(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        skipWs()
        if (depth == 0) {
            val iv = bareIvmWord()
            if (iv != 0) {
                bareIvm = iv
                return doc.addSymbolText(if (iv == 10) "\$ion_1_0" else "\$ion_1_1")
            }
        }
        if (!annAhead()) return one(doc, tab, cat)
        val anns = ArrayList<Int>()
        while (annAhead()) {
            val quoted = b() == 39
            val sym = parseSymbol(doc, tab, quoted)
            skipWs()
            expect(58)
            expect(58)
            anns.add(sym)
            skipWs()
        }
        val id = one(doc, tab, cat)
        if (id < 0) throw syntax()
        return doc.annotate(id, anns)
    }

    private fun skipWs() {
        while (i < n) {
            val c = b()
            if (ws(c)) {
                i++
                continue
            }
            if (c == 47 && i + 1 < n) {
                val nx = at(i + 1)
                if (nx == 47) {
                    i += 2
                    while (i < n && b() != 10 && b() != 13) i++
                    continue
                }
                if (nx == 42) {
                    i += 2
                    var ok = false
                    while (i + 1 < n) {
                        if (b() == 42 && at(i + 1) == 47) {
                            i += 2
                            ok = true
                            break
                        }
                        i++
                    }
                    if (!ok) throw syntax()
                    continue
                }
            }
            return
        }
    }

    private fun expect(c: Int) {
        if (i >= n || b() != c) throw syntax()
        i++
    }

    private fun ivmNop(doc: IonDoc, id: Int): Boolean {
        val node = doc.nodes[id]
        if (node.annN != 0 || node.kind != K_SYMBOL) return false
        val s = doc.syms[node.a]
        if (s.text < 0) return false
        val t = doc.texts[s.text]
        if (t == "\$ion_1_0") return true
        return ver == 11 && t == "\$ion_1_1"
    }

    private fun bareIvmWord(): Int {
        if (i >= n || !ident(b()) || b() in 48..57) return 0
        var j = i
        while (j < n && ident(at(j))) j++
        val word = String(raw, i, j - i, Charsets.US_ASCII)
        var k = j
        while (k < n && ws(at(k))) k++
        if (k + 1 < n && at(k) == 58 && at(k + 1) == 58) return 0
        val which = ivmWord(word)
        if (which == 0) return 0
        i = j
        return which
    }

    private fun ivmWord(word: String): Int {
        if (word.length < 8 || word[0] != '$') return 0
        val prefix = "\$ion_"
        if (word.length <= prefix.length || !word.startsWith(prefix)) return 0
        var k = prefix.length
        var major = 0
        var saw = false
        while (k < word.length && word[k].isDigit()) {
            saw = true
            major = major * 10 + (word[k] - '0')
            k++
        }
        if (!saw || k >= word.length || word[k] != '_') return 0
        k++
        var minor = 0
        saw = false
        while (k < word.length && word[k].isDigit()) {
            saw = true
            minor = minor * 10 + (word[k] - '0')
            k++
        }
        if (!saw || k != word.length) return 0
        if (major == 1 && minor == 0) return 10
        if (major == 1 && minor == 1) return 11
        throw DecodeError(DecodeError.KIND_VERSION, i)
    }

    private fun annAhead(): Boolean {
        if (i >= n) return false
        val c = b()
        if (c != 39 && c != 36 && c !in 65..90 && c !in 97..122 && c != 95) return false
        var j = i
        if (c == 39) {
            j++
            while (j < n) {
                if (at(j) == 92) {
                    j += 2
                    continue
                }
                if (at(j) == 39) {
                    j++
                    break
                }
                j++
            }
        } else {
            while (j < n && ident(at(j))) j++
            val word = String(raw, i, j - i, Charsets.US_ASCII)
            if (word == "null" || word == "true" || word == "false" || word == "nan") return false
        }
        var k = j
        while (k < n && ws(at(k))) k++
        return k + 1 < n && at(k) == 58 && at(k + 1) == 58
    }

    private fun one(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        if (i >= n) throw eof()
        val c = b()
        if (ver == 11 && c == 40 && i + 1 < n && at(i + 1) == 58) return colon(doc, tab, cat)
        if (c == 91) return list(doc, tab, cat)
        if (c == 40) return sexp(doc, tab, cat)
        if (c == 123) {
            if (i + 1 < n && at(i + 1) == 123) return lob(doc)
            return struct(doc, tab, cat)
        }
        if (c == 34) return string(doc, false)
        if (c == 39) {
            if (i + 2 < n && at(i + 1) == 39 && at(i + 2) == 39) return string(doc, true)
            return doc.wrapSym(parseSymbol(doc, tab, true))
        }
        if (c == 43 || c == 45 || c in 48..57) return number(doc)
        if (ident(c)) return keywordOrSymbol(doc, tab)
        if (sexp > 0 && op(c)) return doc.addSymbolText(operator())
        throw syntax()
    }

    private fun enter() {
        if (depth >= 1024) throw DecodeError(DecodeError.KIND_DEPTH, i)
        depth++
    }

    private fun list(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        enter()
        i++
        val id = doc.startContainer(K_LIST)
        skipWs()
        if (i < n && b() == 93) {
            i++
            depth--
            return id
        }
        while (true) {
            val child = parseValue(doc, tab, cat)
            if (child >= 0) doc.addChild(id, child, -1)
            skipWs()
            if (i < n && b() == 44) {
                i++
                skipWs()
                if (i < n && b() == 93) {
                    i++
                    break
                }
                continue
            }
            if (i < n && b() == 93) {
                i++
                break
            }
            throw syntax()
        }
        depth--
        return id
    }

    private fun sexp(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        enter()
        i++
        sexp++
        val id = doc.startContainer(K_SEXP)
        while (true) {
            skipWs()
            if (i < n && b() == 41) {
                i++
                break
            }
            if (i >= n) throw syntax()
            val child = parseValue(doc, tab, cat)
            if (child >= 0) doc.addChild(id, child, -1)
        }
        sexp--
        depth--
        return id
    }

    private fun struct(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        enter()
        val fast = tryPlainStruct(doc)
        if (fast >= 0) {
            depth--
            return fast
        }
        i++
        val id = doc.startContainer(K_STRUCT)
        skipWs()
        if (i < n && b() == 125) {
            i++
            depth--
            return id
        }
        while (true) {
            val field = fieldName(doc, tab)
            if (i < n && b() == 58) {
                i++
                if (i < n && b() == 58) throw syntax()
            } else {
                skipWs()
                expect(58)
                if (i < n && b() == 58) throw syntax()
            }
            val child = parseValue(doc, tab, cat)
            if (child >= 0) doc.addChild(id, child, field)
            if (i >= n || (b() != 44 && b() != 125)) skipWs()
            if (i < n && b() == 44) {
                i++
                skipWs()
                if (i < n && b() == 125) {
                    i++
                    break
                }
                continue
            }
            if (i < n && b() == 125) {
                i++
                break
            }
            throw syntax()
        }
        depth--
        return id
    }

    private fun fieldName(doc: IonDoc, tab: LocalTab): Int {
        skipWs()
        if (i >= n) throw syntax()
        val c = b()
        val long = c == 39 && i + 2 < n && at(i + 1) == 39 && at(i + 2) == 39
        if (c == 34 || long) {
            val node = string(doc, long)
            return doc.symbolRef(doc.textAt(node))
        }
        if (c == 39) return parseSymbol(doc, tab, true)
        if (ident(c) && c !in 48..57) return parseSymbol(doc, tab, false)
        throw syntax()
    }

    fun parseSymbol(doc: IonDoc, tab: LocalTab, quoted: Boolean): Int {
        if (quoted) {
            val bytes = quotedBytes(39, false)
            return doc.symbolRef(utf8Strict(bytes))
        }
        val start = scanIdent()
        val len = i - start
        val sid = dollarSidAt(start, len)
        if (sid >= 0) {
            val node = symFromSid(doc, tab, sid, i)
            return doc.nodes[node].a
        }
        if (keywordAt(start, len) != 0) throw syntax()
        return doc.symbolSlot(doc.internBytes(raw, start, len, true))
    }

    private fun tryPlainStruct(doc: IonDoc): Int {
        val save = i
        if (i >= n || b() != 123) return -1
        i++
        var id = -1
        while (true) {
            if (!skipPlainWs()) {
                i = save
                return -1
            }
            if (i < n && b() == 125) {
                i++
                if (id < 0) id = doc.startContainer(K_STRUCT)
                break
            }
            if (i >= n || !ident(b()) || b() in 48..57 || b() == 36) {
                i = save
                return -1
            }
            val fs = i
            i++
            while (i < n && ident(b())) i++
            val flen = i - fs
            if (keywordAt(fs, flen) != 0) {
                i = save
                return -1
            }
            if (!skipPlainWs()) {
                i = save
                return -1
            }
            if (i >= n || b() != 58) {
                i = save
                return -1
            }
            i++
            if (i < n && b() == 58) {
                i = save
                return -1
            }
            if (!skipPlainWs()) {
                i = save
                return -1
            }
            val value = plainScalar(doc)
            if (value < 0) {
                i = save
                return -1
            }
            if (id < 0) id = doc.startContainer(K_STRUCT)
            doc.addChild(id, value, doc.symbolSlot(doc.internBytes(raw, fs, flen, true)))
            if (!skipPlainWs()) {
                i = save
                return -1
            }
            if (i < n && b() == 44) {
                i++
                continue
            }
            if (i < n && b() == 125) {
                i++
                break
            }
            i = save
            return -1
        }
        return id
    }

    private fun skipPlainWs(): Boolean {
        while (i < n && ws(b())) i++
        if (i < n && b() == 47) return false
        return true
    }

    private fun plainScalar(doc: IonDoc): Int {
        if (i >= n) return -1
        val c = b()
        if (c == 34) {
            val plain = plainQuote(34)
            if (plain < 0) return -1
            val start = i + 1
            val len = plain - start
            var ascii = true
            var k = 0
            while (k < len) {
                if (at(start + k) >= 128) {
                    ascii = false
                    break
                }
                k++
            }
            val id = doc.addStringAt(doc.internBytes(raw, start, len, ascii))
            i = plain + 1
            return id
        }
        if (c == 45 || c in 48..57) return plainInt(doc)
        if (!ident(c) || c in 48..57) return -1
        val start = i
        i++
        while (i < n && ident(b())) i++
        val len = i - start
        when (keywordAt(start, len)) {
            2 -> return doc.addBool(true)
            3 -> return doc.addBool(false)
            4 -> return doc.addFloat(8, 0x7FF8000000000000L)
            1 -> {
                if (i < n && b() == 46) return -1
                return doc.addNull(0)
            }
        }
        if (at(start) == 36) return -1
        return doc.wrapSym(doc.symbolSlot(doc.internBytes(raw, start, len, true)))
    }

    private fun plainInt(doc: IonDoc): Int {
        var neg = false
        if (b() == 45) {
            neg = true
            i++
            if (i >= n || b() !in 48..57) return -1
        }
        if (b() == 48) {
            val nxt = i + 1
            if (nxt < n) {
                val nx = at(nxt)
                if (nx in 48..57 || nx == 95 || nx == 46 || nx == 101 || nx == 69 || nx == 100 || nx == 68 || nx == 120 || nx == 88 || nx == 98 || nx == 66) {
                    return -1
                }
            }
            i++
            return doc.addI64(0)
        }
        var acc = 0L
        var digits = 0
        while (i < n) {
            val ch = b()
            if (ch !in 48..57) break
            val d = ch - 48
            if (acc > 922337203685477580L || (acc == 922337203685477580L && d > 7)) return -1
            acc = acc * 10 + d
            digits++
            i++
        }
        if (digits == 0) return -1
        if (i < n) {
            val nx = b()
            if (nx == 46 || nx == 101 || nx == 69 || nx == 100 || nx == 68 || nx == 95) return -1
        }
        return if (neg) doc.addI64(-acc) else doc.addI64(acc)
    }


    private fun scanIdent(): Int {
        if (i >= n || !ident(b()) || b() in 48..57) throw syntax()
        val start = i
        i++
        while (i < n && ident(b())) i++
        return start
    }

    private fun takeIdent(): String {
        val start = scanIdent()
        return String(raw, start, i - start, Charsets.US_ASCII)
    }

    private fun keywordOrSymbol(doc: IonDoc, tab: LocalTab): Int {
        val start = scanIdent()
        val len = i - start
        when (keywordAt(start, len)) {
            1 -> return nullValue(doc)
            2 -> return doc.addBool(true)
            3 -> return doc.addBool(false)
            4 -> return doc.addFloat(8, 0x7FF8000000000000L)
        }
        val sid = dollarSidAt(start, len)
        if (sid >= 0) return symFromSid(doc, tab, sid, i)
        return doc.wrapSym(doc.symbolSlot(doc.internBytes(raw, start, len, true)))
    }

    private fun keywordAt(start: Int, len: Int): Int {
        if (len == 4 && at(start) == 110 && at(start + 1) == 117 && at(start + 2) == 108 && at(start + 3) == 108) return 1
        if (len == 4 && at(start) == 116 && at(start + 1) == 114 && at(start + 2) == 117 && at(start + 3) == 101) return 2
        if (len == 5 && at(start) == 102 && at(start + 1) == 97 && at(start + 2) == 108 && at(start + 3) == 115 && at(start + 4) == 101) {
            return 3
        }
        if (len == 3 && at(start) == 110 && at(start + 1) == 97 && at(start + 2) == 110) return 4
        return 0
    }

    private fun dollarSidAt(start: Int, len: Int): Int {
        if (len <= 1 || at(start) != 36) return -1
        var sid = 0L
        var k = 1
        while (k < len) {
            val ch = at(start + k)
            if (ch !in 48..57) return -1
            sid = sid * 10 + (ch - 48)
            if (sid > Int.MAX_VALUE) throw DecodeError(DecodeError.KIND_RANGE, i)
            k++
        }
        return sid.toInt()
    }

    private fun nullValue(doc: IonDoc): Int {
        if (i >= n || b() != 46) return doc.addNull(0)
        i++
        val name = takeIdent()
        val k = when (name) {
            "null" -> 0
            "bool" -> K_BOOL
            "int" -> K_INT
            "float" -> K_FLOAT
            "decimal" -> K_DECIMAL
            "timestamp" -> K_TIMESTAMP
            "string" -> K_STRING
            "symbol" -> K_SYMBOL
            "blob" -> K_BLOB
            "clob" -> K_CLOB
            "list" -> K_LIST
            "sexp" -> K_SEXP
            "struct" -> K_STRUCT
            else -> throw syntax()
        }
        return doc.addNull(k)
    }

    private fun string(doc: IonDoc, long: Boolean): Int {
        if (!long) {
            val plain = plainQuote(34)
            if (plain >= 0) {
                val start = i + 1
                val len = plain - start
                var ascii = true
                var k = 0
                while (k < len) {
                    if (at(start + k) >= 128) {
                        ascii = false
                        break
                    }
                    k++
                }
                val id = doc.addStringAt(doc.internBytes(raw, start, len, ascii))
                i = plain + 1
                return id
            }
        }
        val buf = ByteBuf()
        if (long) {
            readLong(buf, false)
            while (true) {
                val save = i
                skipWs()
                if (startsLong()) readLong(buf, false) else {
                    i = save
                    break
                }
            }
        } else {
            readShort(buf, 34, false)
        }
        return doc.addString(utf8Strict(buf.toByteArray()))
    }

    private fun plainQuote(end: Int): Int {
        if (i >= n || b() != end) return -1
        var j = i + 1
        while (j < n) {
            val c = at(j)
            if (c == end) return j
            if (c == 92 || c < 32) return -1
            j++
        }
        return -1
    }

    private fun quotedBytes(end: Int, long: Boolean): ByteArray {
        val buf = ByteBuf()
        if (long) readLong(buf, false) else readShort(buf, end, false)
        return buf.toByteArray()
    }

    private fun startsLong(): Boolean =
        i + 2 < n && b() == 39 && at(i + 1) == 39 && at(i + 2) == 39

    private fun readShort(buf: ByteBuf, end: Int, clob: Boolean) {
        expect(end)
        while (i < n) {
            val c = b()
            if (c == end) {
                i++
                return
            }
            if (c < 32 && c != 9 && c != 11 && c != 12) throw syntax()
            if (c == 92) {
                escape(buf, clob)
                continue
            }
            if (clob && c >= 128) throw syntax()
            buf.add(c)
            i++
        }
        throw syntax()
    }

    private fun readLong(buf: ByteBuf, clob: Boolean) {
        if (!startsLong()) throw syntax()
        i += 3
        while (i < n) {
            if (startsLong()) {
                i += 3
                return
            }
            val c = b()
            if (c < 32 && c != 9 && c != 10 && c != 11 && c != 12 && c != 13) throw syntax()
            if (c == 92) {
                escape(buf, clob)
                continue
            }
            if (c == 13) {
                i++
                if (i < n && b() == 10) i++
                buf.add(10)
                continue
            }
            if (clob && c >= 128) throw syntax()
            buf.add(c)
            i++
        }
        throw syntax()
    }

    private fun escape(buf: ByteBuf, clob: Boolean) {
        i++
        if (i >= n) throw DecodeError(DecodeError.KIND_ESCAPE, i)
        val c = b()
        i++
        when (c) {
            48 -> buf.add(0)
            97 -> buf.add(7)
            98 -> buf.add(8)
            116 -> buf.add(9)
            110 -> buf.add(10)
            118 -> buf.add(11)
            102 -> buf.add(12)
            114 -> buf.add(13)
            34, 39, 47, 63, 92 -> buf.add(c)
            10 -> return
            13 -> {
                if (i < n && b() == 10) i++
            }
            120 -> uEscape(buf, 2)
            117, 85 -> {
                if (clob) throw DecodeError(DecodeError.KIND_ESCAPE, i)
                if (c == 85) {
                    uEscape(buf, 8)
                } else {
                    var cp = hexCp(4)
                    if (cp in 0xD800..0xDBFF) {
                        if (i + 1 < n && b() == 92 && at(i + 1) == 117) {
                            i += 2
                            val low = hexCp(4)
                            if (low !in 0xDC00..0xDFFF) throw DecodeError(DecodeError.KIND_ESCAPE, i)
                            cp = 0x10000 + ((cp - 0xD800) shl 10) + (low - 0xDC00)
                        } else {
                            throw DecodeError(DecodeError.KIND_ESCAPE, i)
                        }
                    }
                    appendUtf8(buf, cp, i)
                }
            }
            else -> throw DecodeError(DecodeError.KIND_ESCAPE, i)
        }
    }

    private fun hexCp(len: Int): Int {
        if (i + len > n) throw DecodeError(DecodeError.KIND_ESCAPE, i)
        var cp = 0
        var k = 0
        while (k < len) {
            val h = hex(at(i + k))
            if (h < 0) throw DecodeError(DecodeError.KIND_ESCAPE, i)
            cp = (cp shl 4) or h
            k++
        }
        i += len
        return cp
    }

    private fun uEscape(buf: ByteBuf, len: Int) {
        val cp = hexCp(len)
        appendUtf8(buf, cp, i)
    }

    private fun lob(doc: IonDoc): Int {
        expect(123)
        expect(123)
        var j = i
        while (j < n && ws(at(j))) j++
        if (j < n && (at(j) == 34 || at(j) == 39)) return clob(doc)
        val chars = ByteBuf()
        while (i < n) {
            val c = b()
            if (c == 125 && i + 1 < n && at(i + 1) == 125) {
                i += 2
                return doc.addBytes(K_BLOB, b64(chars.toByteArray(), i))
            }
            if (ws(c)) {
                i++
                continue
            }
            if (b64Char(c) < 0 && c != 61) throw syntax()
            chars.add(c)
            i++
        }
        throw syntax()
    }

    private fun clob(doc: IonDoc): Int {
        while (i < n && ws(b())) i++
        val buf = ByteBuf()
        var long = startsLong()
        if (long) readLong(buf, true)
        else if (i < n && b() == 34) readShort(buf, 34, true)
        else throw syntax()
        if (long) {
            while (true) {
                val save = i
                while (i < n && ws(b())) i++
                if (startsLong()) readLong(buf, true) else {
                    i = save
                    break
                }
            }
        }
        while (i < n && ws(b())) i++
        if (i + 1 >= n || b() != 125 || at(i + 1) != 125) throw syntax()
        i += 2
        return doc.addBytes(K_CLOB, buf.toByteArray())
    }

    private fun number(doc: IonDoc): Int {
        var neg = false
        if (b() == 43) {
            val save = i
            i++
            if (wordAt("inf")) {
                needStop()
                return doc.addFloat(8, 0x7FF0000000000000L)
            }
            if (sexp > 0) {
                i = save
                return doc.addSymbolText(operator())
            }
            throw syntax()
        }
        if (b() == 45) {
            val save = i
            i++
            if (wordAt("inf")) {
                needStop()
                return doc.addFloat(8, Double.NEGATIVE_INFINITY.toRawBits())
            }
            if (i >= n || b() !in 48..57) {
                if (sexp > 0) {
                    i = save
                    return doc.addSymbolText(operator())
                }
                throw syntax()
            }
            neg = true
        }
        if (i < n && b() == 48 && i + 1 < n) {
            val nx = at(i + 1)
            if (nx == 120 || nx == 88 || nx == 98 || nx == 66) return radix(doc, neg, nx == 98 || nx == 66)
        }
        val fast = fastI64(doc, neg)
        if (fast >= 0) return fast
        return real(doc, neg)
    }

    private fun fastI64(doc: IonDoc, neg: Boolean): Int {
        if (i >= n) return -1
        val c0 = b()
        if (c0 !in 48..57) return -1
        if (c0 == 48) {
            val nxt = i + 1
            if (nxt < n) {
                val nx = at(nxt)
                if (!stop(nx) && !ws(nx)) return -1
            }
            i = nxt
            return doc.addI64(0)
        }
        var acc = 0L
        var j = i
        var digits = 0
        while (j < n) {
            val c = at(j)
            if (c !in 48..57) break
            val d = c - 48
            if (neg && acc == 922337203685477580L && d == 8) {
                val j2 = j + 1
                if (j2 >= n || stop(at(j2)) || ws(at(j2))) {
                    i = j2
                    return doc.addI64(Long.MIN_VALUE)
                }
                return -1
            }
            if (acc > 922337203685477580L || (acc == 922337203685477580L && d > 7)) return -1
            acc = acc * 10 + d
            digits++
            j++
        }
        if (digits == 0) return -1
        if (j < n && !stop(at(j)) && !ws(at(j))) return -1
        i = j
        return if (neg) doc.addI64(-acc) else doc.addI64(acc)
    }

    private fun wordAt(word: String): Boolean {
        if (i + word.length > n) return false
        var k = 0
        while (k < word.length) {
            if (at(i + k) != word[k].code) return false
            k++
        }
        val end = i + word.length
        if (end < n && ident(at(end))) return false
        i = end
        return true
    }

    private fun needStop() {
        if (i < n && !stop(b())) throw syntax()
    }

    private fun radix(doc: IonDoc, neg: Boolean, binary: Boolean): Int {
        i += 2
        val sb = StringBuilder()
        var any = false
        var prevUs = false
        while (i < n) {
            val c = b()
            if (c == 95) {
                if (!any || prevUs) throw syntax()
                prevUs = true
                i++
                continue
            }
            val d = hex(c)
            val ok = if (binary) c == 48 || c == 49 else d in 0..15
            if (!ok) break
            any = true
            prevUs = false
            sb.append(c.toChar())
            i++
        }
        if (!any || prevUs) throw syntax()
        needStop()
        val base = if (binary) 2 else 16
        return doc.addInt(bigFromRadix(sb.toString(), base, neg && sb.any { it != '0' }))
    }

    private fun real(doc: IonDoc, neg: Boolean): Int {
        val whole = ByteBuf()
        val under = BooleanArray(1)
        val nwhole = digits(whole, under)
        if (nwhole == 0) throw syntax()
        if (i < n && (b() == 45 || b() == 84)) {
            if (!neg && !under[0] && nwhole >= 4) return timestamp(doc, whole.toByteArray())
            throw syntax()
        }
        if (whole.size > 1 && whole[0] == 48) throw syntax()
        val frac = ByteBuf()
        var sawDot = false
        if (i < n && b() == 46) {
            sawDot = true
            i++
            if (i < n && b() == 95) throw syntax()
            if (i < n && ((b() in 48..57) || b() == 95)) {
                val fracUnder = BooleanArray(1)
                digits(frac, fracUnder)
            }
        }
        var exp = 0L
        var isFloat = false
        var isDec = sawDot
        if (i < n && (b() == 101 || b() == 69 || b() == 100 || b() == 68)) {
            isFloat = b() == 101 || b() == 69
            isDec = !isFloat
            i++
            exp = exp()
        }
        if (!isDec && !isFloat) {
            val coef = bigFromDigits(whole.toByteArray(), false)
            if (neg && !coef.isZero()) coef.neg = true
            needStop()
            return doc.addInt(coef)
        }
        if (isFloat) {
            needStop()
            return floatNode(doc, neg, whole.toByteArray(), frac.toByteArray(), exp)
        }
        val all = ByteArray(whole.size + frac.size)
        if (whole.size > 0) System.arraycopy(whole.toByteArray(), 0, all, 0, whole.size)
        if (frac.size > 0) System.arraycopy(frac.toByteArray(), 0, all, whole.size, frac.size)
        val coef = bigFromDigits(all, false)
        needStop()
        val decExp = exp - frac.size
        return doc.addDecimal(coef, neg, decExp)
    }

    private fun digits(out: ByteBuf, under: BooleanArray): Int {
        var count = 0
        var prev = false
        under[0] = false
        while (i < n) {
            val c = b()
            if (c in 48..57) {
                out.add(c)
                count++
                prev = false
                i++
                continue
            }
            if (c == 95) {
                if (count == 0 || prev) throw syntax()
                prev = true
                under[0] = true
                i++
                continue
            }
            break
        }
        if (prev) throw syntax()
        return count
    }

    private fun exp(): Long {
        var sign = 1
        if (i < n && (b() == 43 || b() == 45)) {
            if (b() == 45) sign = -1
            i++
        }
        val digs = ByteBuf()
        val under = BooleanArray(1)
        val count = digits(digs, under)
        if (count == 0) throw syntax()
        var v = 0L
        val bytes = digs.toByteArray()
        var k = 0
        while (k < bytes.size) {
            if (v > Long.MAX_VALUE / 10) throw DecodeError(DecodeError.KIND_RANGE, i)
            v = v * 10 + (bytes[k].toInt() and 0xFF) - 48
            k++
        }
        return sign * v
    }

    private fun floatNode(doc: IonDoc, neg: Boolean, whole: ByteArray, frac: ByteArray, exp: Long): Int {
        var nonzero = false
        for (b in whole) if (b != 48.toByte()) nonzero = true
        for (b in frac) if (b != 48.toByte()) nonzero = true
        if (!nonzero) {
            return if (neg) doc.addFloat(8, (-0.0).toRawBits()) else doc.addFloat(0, 0L)
        }
        val sb = StringBuilder()
        if (neg) sb.append('-')
        if (whole.isEmpty()) sb.append('0') else sb.append(String(whole, Charsets.US_ASCII))
        if (frac.isNotEmpty()) {
            sb.append('.')
            sb.append(String(frac, Charsets.US_ASCII))
        }
        sb.append('e')
        sb.append(exp)
        val d = try {
            sb.toString().toDouble()
        } catch (_: NumberFormatException) {
            throw DecodeError(DecodeError.KIND_RANGE, i)
        }
        return doc.addFloat(8, d.toRawBits())
    }

    private fun timestamp(doc: IonDoc, digits: ByteArray): Int {
        if (digits.size != 4) throw syntax()
        var year = 0
        for (b in digits) {
            year = year * 10 + (b.toInt() and 0xFF) - 48
            if (year > 999999999) throw DecodeError(DecodeError.KIND_RANGE, i)
        }
        if (year < 1) throw syntax()
        var prec = PREC_YEAR
        var month = 1
        var day = 1
        var hour = 0
        var minute = 0
        var second = 0
        val frac = ByteBuf()
        var unknown = true
        var off = 0
        if (i < n && b() == 45) {
            i++
            month = two()
            prec = PREC_MONTH
            if (month !in 1..12) throw syntax()
            if (i < n && b() == 45) {
                i++
                day = two()
                prec = PREC_DAY
                if (day < 1 || day > daysInMonth(year, month)) throw syntax()
            }
        }
        if (i < n && b() == 84) {
            i++
            if (i < n && b() in 48..57) {
                if (prec != PREC_DAY) throw syntax()
                hour = two()
                expect(58)
                minute = two()
                prec = PREC_MIN
                if (hour > 23 || minute > 59) throw syntax()
                if (i < n && b() == 58) {
                    i++
                    second = two()
                    prec = PREC_SEC
                    if (second > 59) throw syntax()
                    if (i < n && b() == 46) {
                        i++
                        val u = BooleanArray(1)
                        val nfrac = digits(frac, u)
                        if (nfrac == 0) throw syntax()
                        prec = PREC_FRAC
                    }
                }
                if (i >= n) throw syntax()
                val c = b()
                if (c == 90) {
                    i++
                    unknown = false
                    off = 0
                } else if (c == 43 || c == 45) {
                    val sign = if (c == 45) -1 else 1
                    i++
                    val oh = two()
                    expect(58)
                    val om = two()
                    if (oh > 23 || om > 59) throw syntax()
                    if (sign < 0 && oh == 0 && om == 0) {
                        unknown = true
                        off = 0
                    } else {
                        unknown = false
                        off = sign * (oh * 60 + om)
                    }
                } else {
                    throw syntax()
                }
            } else if (prec != PREC_YEAR && prec != PREC_MONTH && prec != PREC_DAY) {
                throw syntax()
            }
        } else if (prec != PREC_DAY) {
            throw syntax()
        }
        needStop()
        val whenTime = IonTime()
        whenTime.prec = prec
        whenTime.year = year
        whenTime.month = month
        whenTime.day = day
        whenTime.hour = hour
        whenTime.minute = minute
        whenTime.second = second
        whenTime.unknown = unknown
        whenTime.off = off
        if (prec == PREC_FRAC) {
            val fb = frac.toByteArray()
            whenTime.fracExp = -fb.size.toLong()
            val coef = bigFromDigits(fb, false)
            whenTime.fracAt = doc.limbs.size
            whenTime.fracLen = coef.limbs.size
            doc.limbs.addAll(coef.limbs)
        }
        return doc.addTime(whenTime)
    }

    private fun two(): Int {
        if (i + 1 >= n) throw syntax()
        val a = b()
        val c = at(i + 1)
        if (a !in 48..57 || c !in 48..57) throw syntax()
        i += 2
        return (a - 48) * 10 + (c - 48)
    }

    private fun operator(): String {
        val buf = ByteBuf()
        while (i < n && op(b())) {
            if (b() == 47 && i + 1 < n) {
                val nx = at(i + 1)
                if (nx == 47 || nx == 42) break
            }
            buf.add(b())
            i++
        }
        if (buf.size == 0) throw syntax()
        return buf.asString()
    }

    private fun clearMacros() {
        macroNameStore?.clear()
        macroRootStore?.clear()
        macroParamAtStore?.clear()
        macroNparamStore?.clear()
        paramKindStore?.clear()
        paramDefaultStore?.clear()
    }

    private fun colon(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        i += 2
        skipWs()
        if (i < n && b() == 63) return placeholder(doc, tab, cat)
        if (i < n && b() == 41) throw syntax()
        val name = takeIdent()
        if (name == "\$ion") {
            if (depth != 0) throw syntax()
            return directive11(doc, tab, cat)
        }
        if (templ) throw syntax()
        return invoke(doc, tab, cat, name)
    }

    private fun placeholder(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        if (!templ) throw syntax()
        i++
        skipWs()
        var defaultId = -1
        if (i < n && b() != 41) {
            if (b() == 123 && i + 1 < n && at(i + 1) == 35) skipGroup(123, 125)
            else {
                val saved = templ
                templ = false
                defaultId = parseValue(doc, tab, cat)
                templ = saved
                if (defaultId < 0) throw syntax()
            }
        }
        skipWs()
        expect(41)
        val rel = paramKind.size - curParam0
        paramKind.add(0)
        paramDefault.add(defaultId)
        val hole = IonNode(K_HOLE)
        hole.a = rel
        hole.b = defaultId
        return doc.addRaw(hole)
    }

    private fun skipGroup(open: Int, close: Int) {
        if (i >= n || b() != open) throw syntax()
        var d = 0
        while (i < n) {
            val c = b()
            if (c == 34 || c == 39) {
                quotedBytes(c, startsLong())
                continue
            }
            i++
            if (c == open) d++
            else if (c == close) {
                d--
                if (d == 0) return
            }
        }
        throw syntax()
    }

    private fun directive11(doc: IonDoc, tab: LocalTab, cat: Catalog): Int {
        skipWs()
        val opName = takeIdent()
        when (opName) {
            "set_symbols" -> {
                tab.resetSystem()
                addSymbolTexts(doc, tab)
            }
            "add_symbols" -> addSymbolTexts(doc, tab)
            "set_macros", "add_macros" -> {
                if (opName == "set_macros") clearMacros()
                val saved = templ
                templ = true
                while (true) {
                    skipWs()
                    if (i < n && b() == 41) break
                    val param0 = paramKind.size
                    curParam0 = param0
                    val node = sexp(doc, tab, cat)
                    defineMacro(doc, node, param0)
                }
                templ = saved
            }
            "use" -> useModule(doc, tab, cat)
            "module", "import", "encoding" -> skipDirectiveRest()
            else -> throw syntax()
        }
        skipWs()
        expect(41)
        return -1
    }

    private fun addSymbolTexts(doc: IonDoc, tab: LocalTab) {
        while (true) {
            skipWs()
            if (i < n && b() == 41) return
            tab.addText(symbolText(doc))
        }
    }

    private fun symbolText(doc: IonDoc): String {
        skipWs()
        if (i >= n) throw syntax()
        val c = b()
        val long = startsLong()
        if (c == 34 || long) return doc.textAt(string(doc, long))
        if (c == 39) return utf8Strict(quotedBytes(39, false))
        return takeIdent()
    }

    private fun useModule(doc: IonDoc, tab: LocalTab, cat: Catalog) {
        skipWs()
        val name = doc.textAt(string(doc, startsLong()))
        var version = 1
        skipWs()
        if (i < n && b() in 48..57) {
            val num = parseValue(doc, tab, cat)
            version = docInt(doc, num)
        }
        val idx = cat.exact(name, version)
        if (idx < 0) throw DecodeError(DecodeError.KIND_SYMBOL, i)
        val count = cat.tables[idx].texts.size
        var k = 0
        while (k < count) {
            if (cat.tables[idx].gap[k]) tab.addGap() else tab.addText(cat.tables[idx].texts[k])
            k++
        }
    }

    private fun skipDirectiveRest() {
        var d = 1
        while (i < n && d > 0) {
            val c = b()
            if (c == 34 || c == 39) {
                quotedBytes(c, startsLong())
                continue
            }
            i++
            if (c == 40) d++
            else if (c == 41) d--
        }
        if (d != 0) throw syntax()
        i--
    }

    private fun defineMacro(doc: IonDoc, id: Int, param0: Int) {
        val node = doc.nodes[id]
        if (node.kind != K_SEXP || node.nchild != 2) throw syntax()
        val nameId = doc.childAt(id, 0)
        val body = doc.childAt(id, 1)
        if (doc.nodes[nameId].kind != K_SYMBOL || doc.nodes[body].kind == K_HOLE) throw syntax()
        macroName.add(doc.symText(doc.nodes[nameId].a))
        macroRoot.add(body)
        macroParamAt.add(param0)
        macroNparam.add(paramKind.size - param0)
    }

    private fun invoke(doc: IonDoc, tab: LocalTab, cat: Catalog, name: String): Int {
        val addr = macroAddr(name)
        val nparam = macroNparam[addr]
        val args = ArrayList<Int>()
        var p = 0
        while (p < nparam) {
            skipWs()
            if (atAbsent()) {
                eatAbsent()
                args.add(-1)
            } else {
                val arg = parseValue(doc, tab, cat)
                if (arg < 0) throw syntax()
                args.add(arg)
            }
            p++
        }
        skipWs()
        expect(41)
        return expand(doc, macroRoot[addr], args)
    }

    private fun macroAddr(name: String): Int {
        var sid = -1
        if (name.length > 1 && name[0] == '$') {
            var acc = 0
            var digits = true
            var k = 1
            while (k < name.length) {
                val ch = name[k]
                if (ch !in '0'..'9') {
                    digits = false
                    break
                }
                acc = acc * 10 + (ch - '0')
                if (acc < 0) throw DecodeError(DecodeError.KIND_RANGE, i)
                k++
            }
            if (digits) sid = acc
        }
        if (sid >= 0) {
            if (sid >= macroRoot.size) throw DecodeError(DecodeError.KIND_SYMBOL, i)
            return sid
        }
        var k = 0
        while (k < macroName.size) {
            if (macroName[k] == name) return k
            k++
        }
        throw DecodeError(DecodeError.KIND_SYMBOL, i)
    }

    private fun atAbsent(): Boolean {
        if (i + 2 >= n || b() != 40 || at(i + 1) != 58) return false
        var k = i + 2
        while (k < n && ws(at(k))) k++
        return k < n && at(k) == 41
    }

    private fun eatAbsent() {
        i += 2
        skipWs()
        expect(41)
    }

    private fun expand(doc: IonDoc, id: Int, args: List<Int>): Int {
        val node = doc.nodes[id]
        if (node.kind == K_HOLE) {
            var out = -1
            if (node.a < args.size && args[node.a] >= 0) out = args[node.a]
            else if (node.b >= 0) out = expand(doc, node.b, args)
            if (out < 0) return -1
            if (node.annN == 0) return out
            val cloned = doc.addRaw(doc.nodes[out].copy())
            val anns = ArrayList<Int>()
            var k = 0
            while (k < node.annN) {
                anns.add(doc.anns[node.ann + k])
                k++
            }
            doc.nodes[cloned].ann = -1
            doc.nodes[cloned].annN = 0
            doc.setAnns(cloned, anns)
            return cloned
        }
        if (node.kind == K_LIST || node.kind == K_SEXP || node.kind == K_STRUCT) {
            val nid = doc.startContainer(node.kind)
            if (node.annN > 0) {
                val anns = ArrayList<Int>()
                var k = 0
                while (k < node.annN) {
                    anns.add(doc.anns[node.ann + k])
                    k++
                }
                doc.setAnns(nid, anns)
            }
            var e = node.child
            var seen = 0
            while (seen < node.nchild) {
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

private fun ident(c: Int): Boolean =
    c in 48..57 || c in 65..90 || c in 97..122 || c == 95 || c == 36

private fun op(c: Int): Boolean = when (c) {
    33, 35, 37, 38, 42, 43, 45, 46, 47, 59, 60, 61, 62, 63, 64, 94, 96, 124, 126 -> true
    else -> false
}

private fun stop(c: Int): Boolean = when (c) {
    32, 9, 10, 13, 11, 12, 123, 125, 91, 93, 40, 41, 44, 92, 34, 39 -> true
    else -> false
}

private fun ws(c: Int): Boolean = c == 32 || c == 9 || c == 10 || c == 13 || c == 11 || c == 12

private fun hex(c: Int): Int = when {
    c in 48..57 -> c - 48
    c in 65..70 -> c - 55
    c in 97..102 -> c - 87
    else -> -1
}

private fun b64Char(c: Int): Int = when {
    c in 65..90 -> c - 65
    c in 97..122 -> c - 71
    c in 48..57 -> c + 4
    c == 43 -> 62
    c == 47 -> 63
    else -> -1
}

private fun b64(chars: ByteArray, offset: Int): ByteArray {
    val n = chars.size
    if (n == 0) return ByteArray(0)
    var pad = 0
    var i = n - 1
    while (i >= 0 && chars[i] == 61.toByte()) {
        pad++
        i--
    }
    if (pad > 2 || n % 4 != 0) throw DecodeError(DecodeError.KIND_SYNTAX, offset)
    i = 0
    while (i < n - pad) {
        val c = chars[i].toInt() and 0xFF
        if (c == 61 || b64Char(c) < 0) throw DecodeError(DecodeError.KIND_SYNTAX, offset)
        i++
    }
    val out = ByteBuf(n)
    var k = 0
    while (k < n) {
        val c0 = b64Char(chars[k].toInt() and 0xFF)
        val c1 = b64Char(chars[k + 1].toInt() and 0xFF)
        val c2b = chars[k + 2].toInt() and 0xFF
        val c3b = chars[k + 3].toInt() and 0xFF
        val c2 = if (c2b != 61) b64Char(c2b) else 0
        val c3 = if (c3b != 61) b64Char(c3b) else 0
        if (c0 < 0 || c1 < 0) throw DecodeError(DecodeError.KIND_SYNTAX, offset)
        val v = (c0 shl 18) or (c1 shl 12) or (c2 shl 6) or c3
        out.add((v shr 16) and 255)
        if (c2b != 61) out.add((v shr 8) and 255)
        if (c3b != 61) out.add(v and 255)
        k += 4
    }
    return out.toByteArray()
}

private fun utf8Strict(bytes: ByteArray): String {
    validateUtf8(bytes, 0)
    return String(bytes, Charsets.UTF_8)
}

private fun docInt(doc: IonDoc, id: Int): Int {
    val node = doc.nodes[id]
    if (node.kind != K_INT || node.c != 0 || node.b > 2) throw DecodeError(DecodeError.KIND_RANGE, 0)
    if (node.b == 0) return 0
    var mag = u32(doc.limbs[node.a])
    if (node.b == 2) mag = mag or (u32(doc.limbs[node.a + 1]) shl 32)
    if (mag < 0 || mag > Int.MAX_VALUE) throw DecodeError(DecodeError.KIND_RANGE, 0)
    return mag.toInt()
}

fun decodeText(raw: ByteArray, cat: Catalog): IonDoc {
    if (raw.size >= 3 && u8(raw, 0) == 0xEF && u8(raw, 1) == 0xBB && u8(raw, 2) == 0xBF) {
        throw DecodeError(DecodeError.KIND_SYNTAX, 0)
    }
    val doc = IonDoc()
    val guess = raw.size / 3 + 8
    doc.nodes.ensureCapacity(guess)
    doc.ensureEdges(guess)
    doc.top.ensureCapacity(guess)
    doc.texts.ensureCapacity(16)
    doc.syms.ensureCapacity(16)
    val bytes = if (isWide(raw)) {
        val utf = utf8FromWide(raw)
        validateUtf8(utf, 0)
        utf
    } else {
        if (!isAscii(raw)) validateUtf8(raw, 0)
        raw
    }
    return withLocalTab { tab ->
        TextParser(bytes).readAll(doc, tab, cat)
        doc
    }
}

fun parseIon(doc: IonDoc, text: String, expect: Int): Int {
    val raw = text.toByteArray(Charsets.UTF_8)
    val id = TextParser(raw).parseValue(doc, LocalTab(), Catalog())
    if (id < 0) throw DecodeError(DecodeError.KIND_SYNTAX, 0)
    if (expect != 0 && doc.nodes[id].kind != expect) throw DecodeError(DecodeError.KIND_TYPE, 0)
    return id
}
