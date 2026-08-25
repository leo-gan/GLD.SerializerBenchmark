package benchmark;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Golden vectors for B-1 block_shuffle (must match analysis/tests/test_schedule.py). */
class ScheduleTest {
  @Test
  void goldenSeedAndPermutation() {
    assertEquals("bytes", Schedule.normalizeMode("string"));
    assertEquals("stream", Schedule.normalizeMode("Stream"));
    long seed = Schedule.deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0);
    assertEquals(Long.parseUnsignedLong("15992650003647724414"), seed);
    assertEquals(List.of("C", "B", "A"), Schedule.goldenPermutation());
  }

  @Test
  void modeAliasesSameSeed() {
    long a = Schedule.deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0);
    long b = Schedule.deriveScheduleSeed(42, "message", 1, "abc", "string", 0);
    assertEquals(a, b);
  }
}
