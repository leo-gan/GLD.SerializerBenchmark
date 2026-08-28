package benchmark.model.v2

/**
 * Deterministic xorshift64* PRNG (within-language only).
 *
 * Zero seed uses `floor(2^64/φ) = 0x9E3779B97F4A7C15`.
 */
class Rng(seed: Long) {
    private var state: Long = if (seed == 0L) GOLDEN else seed

    fun nextU64(): Long {
        var x = state
        x = x xor (x shl 13)
        x = x xor (x ushr 7)
        x = x xor (x shl 17)
        state = x
        return x
    }

    fun nextInt(lo: Int, hi: Int): Int {
        if (hi <= lo) return lo
        return lo + java.lang.Long.remainderUnsigned(nextU64(), (hi - lo + 1).toLong()).toInt()
    }

    fun nextBool(): Boolean = (nextU64() and 1L) == 1L

    fun nextF64(): Double = (nextU64() ushr 11).toDouble() / (1L shl 53).toDouble()

    fun word(minL: Int, maxL: Int): String {
        val n = nextInt(minL, maxL)
        val b = CharArray(n)
        for (i in 0 until n) {
            b[i] = ('a'.code + java.lang.Long.remainderUnsigned(nextU64(), 26).toInt()).toChar()
        }
        return String(b)
    }

    companion object {
        fun mixSeed(seed: Long, typeId: String, idx: Int): Long {
            var h = seed
            for (ch in typeId) {
                h = (h xor ch.code.toLong()) * 0x100000001B3L
            }
            h = h xor (idx.toLong() * GOLDEN)
            return if (h == 0L) 1L else h
        }

        /** floor(2^64/φ) as a signed long (same bits as Java 0x9E3779B97F4A7C15L). */
        private const val GOLDEN = -0x61C8864680B583EBL
    }
}
