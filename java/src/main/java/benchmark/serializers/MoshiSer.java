package benchmark.serializers;

import benchmark.model.Fixture;
import com.squareup.moshi.JsonAdapter;
import com.squareup.moshi.Moshi;
import com.squareup.moshi.Types;
import okio.Buffer;
import okio.Okio;

import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Type;

/**
 * Moshi (Square) — modern JSON library widely used on Android and JVM services.
 *
 * <p>Recommended: reuse {@link Moshi}; cache typed {@link JsonAdapter}; {@code toJson}/{@code fromJson}
 * with Okio {@link Buffer} (preferred over intermediate UTF-16 Strings).
 *
 * @see <a href="https://github.com/square/moshi">Moshi</a>
 */
public final class MoshiSer implements BenchSerializer {
  private final Moshi moshi;
  private JsonAdapter<Object> adapter;

  public MoshiSer() {
    moshi = new Moshi.Builder().build();
  }

  @Override
  public String name() {
    return "moshi";
  }

  @Override
  public String version() {
    return Versions.of(Moshi.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  @SuppressWarnings("unchecked")
  public void prepare(Fixture fx) {
    Type type;
    if (TypeUtil.isList(fx.value)) {
      Class<?> el = TypeUtil.elementClass(fx.value);
      type = Types.newParameterizedType(java.util.List.class, el);
    } else {
      type = fx.value.getClass();
    }
    adapter = (JsonAdapter<Object>) (JsonAdapter<?>) moshi.adapter(type);
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    Buffer buf = new Buffer();
    adapter.toJson(buf, fx.value);
    return buf.readByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    return adapter.fromJson(new Buffer().write(data));
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    Buffer buf = new Buffer();
    adapter.toJson(buf, fx.value);
    byte[] bytes = buf.readByteArray();
    out.write(bytes);
    return bytes.length;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return adapter.fromJson(Okio.buffer(Okio.source(in)));
  }
}
