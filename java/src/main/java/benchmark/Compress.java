package benchmark;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.zip.GZIPOutputStream;

/** One-shot compressed sizes of already-written bytes (not timed). */
public final class Compress {
  private Compress() {}

  /**
   * gzip(6) length and zstd(3) length. The JDK has no zstd encoder, so the
   * second value is always 0.
   */
  public static int[] sizes(byte[] raw) {
    if (raw == null || raw.length == 0) {
      return new int[] {0, 0};
    }
    ByteArrayOutputStream bos = new ByteArrayOutputStream(Math.max(32, raw.length));
    try (GZIPOutputStream gzos =
        new GZIPOutputStream(bos) {
          {
            def.setLevel(6);
          }
        }) {
      gzos.write(raw);
    } catch (IOException e) {
      return new int[] {0, 0};
    }
    return new int[] {bos.size(), 0};
  }
}
