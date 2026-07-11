package benchmark.model.v2;

/** Deterministic xorshift64* style PRNG (aligned with other harnesses). */
public final class Rng {
  private long state;

  public Rng(long seed) {
    this.state = seed == 0 ? 0x9E3779B97F4A7C15L : seed;
  }

  public long nextU64() {
    long x = state;
    x ^= x << 13;
    x ^= x >>> 7;
    x ^= x << 17;
    state = x;
    return x;
  }

  public int nextInt(int lo, int hi) {
    if (hi <= lo) return lo;
    return lo + (int) (Long.remainderUnsigned(nextU64(), (hi - lo + 1L)));
  }

  public boolean nextBool() {
    return (nextU64() & 1L) == 1L;
  }

  public double nextF64() {
    return (nextU64() >>> 11) / (double) (1L << 53);
  }

  public String word(int minL, int maxL) {
    int n = nextInt(minL, maxL);
    char[] b = new char[n];
    for (int i = 0; i < n; i++) {
      b[i] = (char) ('a' + (int) (Long.remainderUnsigned(nextU64(), 26)));
    }
    return new String(b);
  }

  public static long mixSeed(long seed, String typeId, int idx) {
    long h = seed;
    for (int i = 0; i < typeId.length(); i++) {
      h = (h ^ typeId.charAt(i)) * 0x100000001B3L;
    }
    h ^= (long) idx * 0x9E3779B97F4A7C15L;
    return h == 0 ? 1 : h;
  }
}
