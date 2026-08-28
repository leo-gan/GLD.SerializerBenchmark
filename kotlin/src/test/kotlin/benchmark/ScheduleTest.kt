package benchmark

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

/** Golden vectors for B-1 block_shuffle (must match analysis/tests/test_schedule.py). */
class ScheduleTest {
    @Test
    fun goldenSeedAndPermutation() {
        assertEquals("bytes", Schedule.normalizeMode("string"))
        assertEquals("stream", Schedule.normalizeMode("Stream"))
        val seed = Schedule.deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0)
        assertEquals(java.lang.Long.parseUnsignedLong("15992650003647724414"), seed)
        assertEquals(listOf("C", "B", "A"), Schedule.goldenPermutation())
    }

    @Test
    fun modeAliasesSameSeed() {
        val a = Schedule.deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0)
        val b = Schedule.deriveScheduleSeed(42, "message", 1, "abc", "string", 0)
        assertEquals(a, b)
    }
}
