package benchmark

import java.io.ByteArrayOutputStream
import java.util.zip.GZIPOutputStream

/** One-shot compressed sizes of already-written bytes (not timed). */
object Compress {
    /**
     * gzip(6) length and zstd(3) length. The JDK has no zstd encoder, so the
     * second value is always 0.
     */
    fun sizes(raw: ByteArray?): IntArray {
        if (raw == null || raw.isEmpty()) return intArrayOf(0, 0)
        val bos = ByteArrayOutputStream(maxOf(32, raw.size))
        try {
            object : GZIPOutputStream(bos) {
                init {
                    def.setLevel(6)
                }
            }.use { it.write(raw) }
        } catch (_: Exception) {
            return intArrayOf(0, 0)
        }
        return intArrayOf(bos.size(), 0)
    }
}
