package ion

class IonTime {
    var prec: Int = PREC_YEAR
    var off: Int = 0
    var unknown: Boolean = true
    var year: Int = 1
    var month: Int = 1
    var day: Int = 1
    var hour: Int = 0
    var minute: Int = 0
    var second: Int = 0
    var fracExp: Long = 0
    var fracAt: Int = 0
    var fracLen: Int = 0

    fun copy(): IonTime {
        val t = IonTime()
        t.prec = prec
        t.off = off
        t.unknown = unknown
        t.year = year
        t.month = month
        t.day = day
        t.hour = hour
        t.minute = minute
        t.second = second
        t.fracExp = fracExp
        t.fracAt = fracAt
        t.fracLen = fracLen
        return t
    }
}

class IonNode(var kind: Int) {
    var a: Int = 0
    var b: Int = 0
    var c: Int = 0
    var exp: Long = 0
    var ann: Int = -1
    var annN: Int = 0
    var child: Int = -1
    var nchild: Int = 0
    var tail: Int = -1

    fun copy(): IonNode {
        val n = IonNode(kind)
        n.a = a
        n.b = b
        n.c = c
        n.exp = exp
        n.ann = ann
        n.annN = annN
        n.child = child
        n.nchild = nchild
        n.tail = tail
        return n
    }
}

class SymRef(var text: Int, var sid: Int, var impName: Int, var impSid: Int)

/** Little-endian base-2^32 digits without boxing each limb. */
class LimbList {
    private var data = IntArray(64)
    var size: Int = 0
        private set

    fun add(v: Int) {
        if (size == data.size) data = data.copyOf(data.size * 2)
        data[size++] = v
    }

    fun addAll(src: ArrayList<Int>) {
        val n = src.size
        val need = size + n
        if (need > data.size) {
            var cap = data.size
            while (cap < need) cap *= 2
            data = data.copyOf(cap)
        }
        var i = 0
        while (i < n) {
            data[size++] = src[i]
            i++
        }
    }

    operator fun get(i: Int): Int = data[i]
}

/**
 * One Ion datagram. Nodes are integers into parallel lists.
 * A container never embeds another node; children are edges.
 * Field slots and annotation slots are indexes into [syms].
 */
class IonDoc {
    val nodes = ArrayList<IonNode>()
    val texts = ArrayList<String>()
    val syms = ArrayList<SymRef>()
    val limbs = LimbList()
    val top = ArrayList<Int>()

    // Singly linked children: three parallel arrays, one slot per edge.
    internal var edgeChild = IntArray(64)
    internal var edgeField = IntArray(64)
    internal var edgeNext = IntArray(64)
    internal var nedges: Int = 0

    // Allocated on first use so a document of ints and strings does not pay for them.
    private var annStore: ArrayList<Int>? = null
    private var floatStore: ArrayList<Long>? = null
    private var timeStore: ArrayList<IonTime>? = null
    private var blobAtStore: ArrayList<Int>? = null
    private var blobLenStore: ArrayList<Int>? = null
    private var blobStore: ByteBuf? = null

    val anns: ArrayList<Int>
        get() = annStore ?: ArrayList<Int>().also { annStore = it }
    val floats: ArrayList<Long>
        get() = floatStore ?: ArrayList<Long>().also { floatStore = it }
    val times: ArrayList<IonTime>
        get() = timeStore ?: ArrayList<IonTime>().also { timeStore = it }
    val blobAt: ArrayList<Int>
        get() = blobAtStore ?: ArrayList<Int>().also { blobAtStore = it }
    val blobLen: ArrayList<Int>
        get() = blobLenStore ?: ArrayList<Int>().also { blobLenStore = it }
    val blobBytes: ByteBuf
        get() = blobStore ?: ByteBuf(16).also { blobStore = it }

    private val textIndex = HashMap<String, Int>()
    private val symAt = ArrayList<Int>()
    private val hot = arrayOf("", "", "", "")
    private val hotAt = intArrayOf(-1, -1, -1, -1)
    private var hotNext = 0

    fun intern(text: String): Int {
        val hit = textIndex[text]
        if (hit != null) return hit
        return storeText(text)
    }

    /** Reuse a recent ASCII slice without allocating when the bytes match. */
    internal fun internBytes(raw: ByteArray, from: Int, len: Int, ascii: Boolean): Int {
        if (ascii && len >= 0) {
            var h = 0
            while (h < 4) {
                val at = hotAt[h]
                if (at >= 0 && hot[h].length == len && sameAscii(hot[h], raw, from, len)) return at
                h++
            }
        }
        val text = when {
            len == 0 -> ""
            ascii -> String(raw, from, len, Charsets.US_ASCII)
            else -> String(raw, from, len, Charsets.UTF_8)
        }
        val id = intern(text)
        if (ascii && len > 0) {
            val slot = hotNext and 3
            hotNext++
            hot[slot] = text
            hotAt[slot] = id
        }
        return id
    }

    internal fun symbolSlot(textIndexAt: Int): Int {
        val cached = symAt[textIndexAt]
        if (cached >= 0) return cached
        val s = SymRef(textIndexAt, 0, -1, 0)
        val id = syms.size
        syms.add(s)
        symAt[textIndexAt] = id
        return id
    }

    /** SymRef index for known text. Repeated text shares one record. */
    fun symbolRef(text: String): Int = symbolSlot(intern(text))

    private fun storeText(text: String): Int {
        val id = texts.size
        texts.add(text)
        symAt.add(-1)
        textIndex[text] = id
        return id
    }

    fun addNull(nullType: Int): Int {
        val n = IonNode(K_NULL)
        n.a = nullType
        return addRaw(n)
    }

    fun addBool(value: Boolean): Int {
        val n = IonNode(K_BOOL)
        if (value) n.a = 1
        return addRaw(n)
    }

    fun addInt(value: BigInt): Int {
        val n = IonNode(K_INT)
        n.a = limbs.size
        n.b = value.limbs.size
        if (value.neg) n.c = 1
        limbs.addAll(value.limbs)
        return addRaw(n)
    }

    fun addI64(value: Long): Int {
        val n = IonNode(K_INT)
        if (value == 0L) return addRaw(n)
        var mag = value
        if (value < 0L) {
            n.c = 1
            mag = if (value == Long.MIN_VALUE) Long.MIN_VALUE else -value
        }
        n.a = limbs.size
        val lo = (mag and 0xFFFFFFFFL).toInt()
        val hi = (mag ushr 32).toInt()
        limbs.add(lo)
        n.b = 1
        if (hi != 0) {
            limbs.add(hi)
            n.b = 2
        }
        return addRaw(n)
    }

    fun addFloat(width: Int, bits: Long): Int {
        val n = IonNode(K_FLOAT)
        n.a = width
        n.b = floats.size
        floats.add(bits)
        return addRaw(n)
    }

    fun addDecimal(coef: BigInt, neg: Boolean, exp: Long): Int {
        val n = IonNode(K_DECIMAL)
        n.a = limbs.size
        n.b = coef.limbs.size
        if (neg || coef.neg) n.c = 1
        n.exp = exp
        limbs.addAll(coef.limbs)
        return addRaw(n)
    }

    fun addTime(whenTime: IonTime): Int {
        val n = IonNode(K_TIMESTAMP)
        n.a = times.size
        times.add(whenTime)
        return addRaw(n)
    }

    fun addString(text: String): Int = addStringAt(intern(text))

    internal fun addStringAt(textIndexAt: Int): Int {
        val n = IonNode(K_STRING)
        n.a = textIndexAt
        return addRaw(n)
    }

    fun addStringRaw(span: ByteArray, from: Int, to: Int, offset: Int): Int {
        var ascii = true
        var k = from
        while (k < to) {
            if ((span[k].toInt() and 0xFF) >= 128) {
                ascii = false
                validateUtf8(span, from, to, offset)
                break
            }
            k++
        }
        return addStringAt(internBytes(span, from, to - from, ascii))
    }

    fun addSymbolText(text: String): Int = wrapSym(symbolRef(text))

    fun wrapSym(sym: Int): Int {
        val n = IonNode(K_SYMBOL)
        n.a = sym
        return addRaw(n)
    }

    fun addSymbolRef(sym: SymRef): Int {
        val n = IonNode(K_SYMBOL)
        n.a = syms.size
        syms.add(sym)
        return addRaw(n)
    }

    fun addBytes(kind: Int, data: ByteArray): Int {
        val n = IonNode(kind)
        n.a = blobAt.size
        blobAt.add(blobBytes.size)
        blobLen.add(data.size)
        blobBytes.addAll(data)
        return addRaw(n)
    }

    fun startContainer(kind: Int): Int = addRaw(IonNode(kind))

    fun ensureEdges(need: Int) {
        if (edgeChild.size >= need) return
        var cap = edgeChild.size
        while (cap < need) cap *= 2
        edgeChild = edgeChild.copyOf(cap)
        edgeField = edgeField.copyOf(cap)
        edgeNext = edgeNext.copyOf(cap)
    }

    fun addChild(parent: Int, child: Int, field: Int) {
        val idx = nedges
        if (idx == edgeChild.size) ensureEdges(idx + 1)
        edgeChild[idx] = child
        edgeField[idx] = field
        edgeNext[idx] = -1
        nedges = idx + 1
        val node = nodes[parent]
        if (node.child < 0) {
            node.child = idx
        } else {
            edgeNext[node.tail] = idx
        }
        node.tail = idx
        node.nchild++
    }

    fun setAnns(id: Int, annsIn: List<Int>) {
        if (annsIn.isEmpty()) return
        val node = nodes[id]
        node.ann = anns.size
        node.annN = annsIn.size
        anns.addAll(annsIn)
    }

    /** Fresh node so annotations never mutate a shared scalar. */
    fun annotate(id: Int, annsIn: List<Int>): Int {
        if (annsIn.isEmpty()) return id
        val copy = addRaw(nodes[id].copy())
        nodes[copy].ann = -1
        nodes[copy].annN = 0
        setAnns(copy, annsIn)
        return copy
    }

    fun addTop(id: Int) {
        top.add(id)
    }

    fun childAt(parent: Int, index: Int): Int {
        var edge = nodes[parent].child
        var i = 0
        while (i < index) {
            edge = edgeNext[edge]
            i++
        }
        return edgeChild[edge]
    }

    fun fieldAt(parent: Int, index: Int): Int {
        var edge = nodes[parent].child
        var i = 0
        while (i < index) {
            edge = edgeNext[edge]
            i++
        }
        return edgeField[edge]
    }

    fun textAt(id: Int): String = texts[nodes[id].a]

    fun symText(sym: Int): String {
        val s = syms[sym]
        if (s.text < 0) return ""
        return texts[s.text]
    }

    fun blobBytes(slot: Int): ByteArray {
        val at = blobAt[slot]
        val n = blobLen[slot]
        val out = ByteArray(n)
        var i = 0
        while (i < n) {
            out[i] = blobBytes[at + i].toByte()
            i++
        }
        return out
    }

    internal fun addRaw(node: IonNode): Int {
        nodes.add(node)
        return nodes.lastIndex
    }
}

private fun sameAscii(text: String, raw: ByteArray, from: Int, len: Int): Boolean {
    var k = 0
    while (k < len) {
        if (text[k].code != (raw[from + k].toInt() and 0xFF)) return false
        k++
    }
    return true
}
