package benchmark.serializers;

import benchmark.model.Fixture;
import java.io.InputStream;
import java.io.OutputStream;
import org.apache.fory.json.ForyJson;

/**
 * Apache Fory JSON ({@code org.apache.fory:fory-json}), separate from the binary {@code fory} row.
 *
 * <p>One reused {@link ForyJson}. Bytes are UTF-8 JSON. The stream path writes the same document.
 */
public final class ForyJsonSer implements BenchSerializer {
  private final ForyJson json = ForyJson.builder().build();
  private Class<?> type = Object.class;

  @Override
  public String name() {
    return "fory-json";
  }

  @Override
  public String version() {
    return Versions.of(ForyJson.class);
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public String nativeKind() {
    return "message";
  }

  @Override
  public void prepare(Fixture fx) {
    type = fx.value == null ? Object.class : fx.value.getClass();
    json.fromJson(json.toJsonBytes(fx.value), type);
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    return json.toJsonBytes(fx.value);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return json.fromJson(data, type);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    byte[] b = json.toJsonBytes(fx.value);
    out.write(b);
    return b.length;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return json.fromJson(in.readAllBytes(), type);
  }
}
