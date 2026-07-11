package benchmark.serializers;

import benchmark.model.Fixture;

import java.io.InputStream;
import java.io.OutputStream;

/**
 * Prepare/timed call-path contract (aligned with Go/Python/Rust).
 *
 * <pre>
 * prepare(fixture)                 # untimed
 * serializeBytes / stream          # timed
 * deserializeBytes / stream        # timed (codec only)
 * toDomain (optional)              # untimed
 * fidelity                         # untimed
 * </pre>
 */
public interface BenchSerializer {
  String name();

  String version();

  /** native | adapted */
  default String streamMode() {
    return "adapted";
  }

  /** reflect | message | schema */
  default String nativeKind() {
    return "reflect";
  }

  default boolean supports(String testDataName) {
    return true;
  }

  void prepare(Fixture fx) throws Exception;

  byte[] serializeBytes(Fixture fx) throws Exception;

  Object deserializeBytes(byte[] data) throws Exception;

  default int serializeStream(Fixture fx, OutputStream out) throws Exception {
    byte[] b = serializeBytes(fx);
    out.write(b);
    return b.length;
  }

  default Object deserializeStream(InputStream in) throws Exception {
    return deserializeBytes(in.readAllBytes());
  }

  /**
   * Optional untimed conversion from library-native value to suite domain object.
   * Default is identity.
   */
  default Object toDomain(Object decoded) throws Exception {
    return decoded;
  }
}
