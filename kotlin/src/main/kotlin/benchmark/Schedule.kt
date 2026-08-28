package benchmark

import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Locale

/**
 * B-1 deterministic block_shuffle schedule (must match analysis golden vector).
 *
 * Golden: A,B,C @ seed 42 / message / 1 / abc / bytes / 0 → C,B,A
 */
object Schedule {
    fun normalizeMode(mode: String?): String {
        val m = mode?.trim()?.lowercase(Locale.ROOT) ?: ""
        if (m == "string" || m == "buffer") return "bytes"
        if (m == "stream") return "stream"
        return m
    }

    fun deriveScheduleSeed(
        baseSeed: Long,
        typeId: String,
        instanceCount: Int,
        typeConfigHash: String?,
        mode: String,
        rep: Int,
    ): Long {
        val key =
            "$baseSeed|$typeId|$instanceCount|${typeConfigHash ?: ""}|${normalizeMode(mode)}|$rep"
        val digest = MessageDigest.getInstance("SHA-256").digest(key.toByteArray(StandardCharsets.UTF_8))
        var u = 0L
        for (i in 7 downTo 0) {
            u = (u shl 8) or (digest[i].toLong() and 0xffL)
        }
        return u
    }

    fun <T> fisherYates(items: List<T>, seed: Long): List<T> {
        val arr = items.toMutableList()
        val rng = SplitMix64(seed)
        for (i in arr.lastIndex downTo 1) {
            val j = java.lang.Long.remainderUnsigned(rng.nextU64(), (i + 1).toLong()).toInt()
            val tmp = arr[i]
            arr[i] = arr[j]
            arr[j] = tmp
        }
        return arr
    }

    fun goldenPermutation(): List<String> {
        val seed = deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0)
        return fisherYates(listOf("A", "B", "C"), seed)
    }

    fun resolveStrategy(): String {
        val env = (System.getenv("BENCHMARK_SCHEDULE") ?: "").trim().lowercase(Locale.ROOT)
        if (env == "none" || env == "block_shuffle") return env
        return "block_shuffle"
    }

    fun resolveRecordRunOrder(): Boolean {
        val env = (System.getenv("BENCHMARK_RECORD_RUN_ORDER") ?: "").trim().lowercase(Locale.ROOT)
        return !(env == "0" || env == "false" || env == "no")
    }

    private class SplitMix64(seed: Long) {
        private var state = seed

        fun nextU64(): Long {
            state += C1
            var z = state
            z = (z xor (z ushr 30)) * C2
            z = (z xor (z ushr 27)) * C3
            return z xor (z ushr 31)
        }

        companion object {
            // Same bit patterns as Java's 0x9E3779B97F4A7C15L / 0xBF58476D1CE4E5B9L / 0x94D049BB133111EBL.
            private val C1 = 0x9E3779B97F4A7C15uL.toLong()
            private val C2 = 0xBF58476D1CE4E5B9uL.toLong()
            private val C3 = 0x94D049BB133111EBuL.toLong()
        }
    }
}
