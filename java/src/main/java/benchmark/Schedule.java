package benchmark;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * B-1 deterministic block_shuffle schedule (must match analysis golden vector).
 *
 * <p>Golden: A,B,C @ seed 42 / message / 1 / abc / bytes / 0 → C,B,A
 * (seed 15992650003647724414).
 */
public final class Schedule {
  private Schedule() {}

  public static String normalizeMode(String mode) {
    String m = mode == null ? "" : mode.trim().toLowerCase(Locale.ROOT);
    if (m.equals("string") || m.equals("buffer")) return "bytes";
    if (m.equals("stream")) return "stream";
    return m;
  }

  /**
   * 64-bit seed for Fisher–Yates for one (cell, mode, rep) group.
   * Returned as a signed long whose bit pattern is the unsigned u64 seed.
   */
  public static long deriveScheduleSeed(
      long baseSeed,
      String typeId,
      int instanceCount,
      String typeConfigHash,
      String mode,
      int rep) {
    String key =
        baseSeed
            + "|"
            + typeId
            + "|"
            + instanceCount
            + "|"
            + (typeConfigHash == null ? "" : typeConfigHash)
            + "|"
            + normalizeMode(mode)
            + "|"
            + rep;
    try {
      MessageDigest md = MessageDigest.getInstance("SHA-256");
      byte[] digest = md.digest(key.getBytes(StandardCharsets.UTF_8));
      // first 8 bytes little-endian
      long u = 0;
      for (int i = 7; i >= 0; i--) {
        u = (u << 8) | (digest[i] & 0xffL);
      }
      return u;
    } catch (NoSuchAlgorithmException e) {
      throw new IllegalStateException("SHA-256 required", e);
    }
  }

  public static <T> List<T> fisherYates(List<T> items, long seed) {
    List<T> arr = new ArrayList<>(items);
    SplitMix64 rng = new SplitMix64(seed);
    for (int i = arr.size() - 1; i > 0; i--) {
      int j = (int) Long.remainderUnsigned(rng.nextU64(), i + 1L);
      T tmp = arr.get(i);
      arr.set(i, arr.get(j));
      arr.set(j, tmp);
    }
    return arr;
  }

  /** Golden vector: A,B,C → C,B,A */
  public static List<String> goldenPermutation() {
    long seed = deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0);
    return fisherYates(List.of("A", "B", "C"), seed);
  }

  public static String resolveStrategy() {
    String env = System.getenv("BENCHMARK_SCHEDULE");
    if (env == null) env = "";
    env = env.trim().toLowerCase(Locale.ROOT);
    if (env.equals("none") || env.equals("block_shuffle")) return env;
    return "block_shuffle";
  }

  public static boolean resolveRecordRunOrder() {
    String env = System.getenv("BENCHMARK_RECORD_RUN_ORDER");
    if (env == null) env = "";
    env = env.trim().toLowerCase(Locale.ROOT);
    if (env.equals("0") || env.equals("false") || env.equals("no")) return false;
    return true;
  }

  /** SplitMix64 PRNG (public-domain algorithm; fixed constants). Unsigned 64-bit via long bits. */
  static final class SplitMix64 {
    private long state;

    SplitMix64(long seed) {
      this.state = seed;
    }

    long nextU64() {
      state += 0x9E3779B97F4A7C15L;
      long z = state;
      z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
      z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
      return z ^ (z >>> 31);
    }
  }
}
