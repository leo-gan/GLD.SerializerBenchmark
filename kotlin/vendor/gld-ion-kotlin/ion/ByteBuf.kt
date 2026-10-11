package ion

/** Growable byte buffer used by the encoders. Indexes are plain ints. */
class ByteBuf(initial: Int = 32) {
    @PublishedApi
    internal var data = ByteArray(initial.coerceAtLeast(8))
    var size: Int = 0

    inline fun add(v: Int) {
        if (size == data.size) grow(size + 1)
        data[size++] = v.toByte()
    }

    fun addAll(src: ByteArray) {
        addAll(src, 0, src.size)
    }

    fun addAll(src: ByteArray, off: Int, len: Int) {
        if (len <= 0) return
        if (size + len > data.size) grow(size + len)
        System.arraycopy(src, off, data, size, len)
        size += len
    }

    fun addAll(src: ByteBuf) {
        addAll(src.data, 0, src.size)
    }

    /** ASCII goes straight into the buffer. Anything else is encoded once. */
    fun addUtf8(text: String) {
        var i = 0
        val n = text.length
        while (i < n) {
            if (text[i].code >= 128) {
                addAll(text.toByteArray(Charsets.UTF_8))
                return
            }
            i++
        }
        if (size + n > data.size) grow(size + n)
        i = 0
        while (i < n) {
            data[size++] = text[i].code.toByte()
            i++
        }
    }

    operator fun get(i: Int): Int = data[i].toInt() and 0xFF

    operator fun set(i: Int, v: Int) {
        data[i] = v.toByte()
    }

    fun truncate(n: Int) {
        size = n
    }

    fun toByteArray(): ByteArray = data.copyOf(size)

    fun asString(): String = String(data, 0, size, Charsets.UTF_8)

    @PublishedApi
    internal fun grow(need: Int) {
        var cap = data.size
        while (cap < need) cap = cap * 2
        data = data.copyOf(cap)
    }
}

internal fun u8(raw: ByteArray, i: Int): Int = raw[i].toInt() and 0xFF

internal fun u32(limb: Int): Long = limb.toLong() and 0xFFFFFFFFL
