package benchmark.serializers;

import benchmark.model.Fixture;
import com.jsoniter.JsonIterator;
import com.jsoniter.output.EncodingMode;
import com.jsoniter.output.JsonStream;
import com.jsoniter.spi.Config;
import com.jsoniter.spi.DecodingMode;
import com.jsoniter.spi.JsoniterSpi;
import com.jsoniter.spi.TypeLiteral;

import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;

/**
 * jsoniter (json-iterator for Java) — high-performance JSON (dsl-json lineage).
 *
 * <p>Recommended: set default {@link Config} once via {@link JsoniterSpi} with DYNAMIC
 * encoding/decoding (codegen-free, JPMS-friendly); timed path {@link JsonStream#serialize} /
 * {@link JsonIterator#deserialize}.
 *
 * @see <a href="https://jsoniter.com/">jsoniter</a>
 */
public final class JsoniterSer implements BenchSerializer {
  private TypeLiteral<?> typeLiteral;

  private static final Config CFG =
      new Config.Builder()
          // DYNAMIC uses javassist codegen — the recommended high-throughput jsoniter path.
          .encodingMode(EncodingMode.DYNAMIC_MODE)
          .decodingMode(DecodingMode.DYNAMIC_MODE_AND_MATCH_FIELD_WITH_HASH)
          .build();

  static {
    JsoniterSpi.setDefaultConfig(CFG);
  }

  @Override
  public String name() {
    return "jsoniter";
  }

  @Override
  public String version() {
    return Versions.of(JsonIterator.class);
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public void prepare(Fixture fx) {
    if (TypeUtil.isList(fx.value)) {
      Class<?> el = TypeUtil.elementClass(fx.value);
      typeLiteral = TypeLiteral.create(new ListType(el));
    } else {
      typeLiteral = TypeLiteral.create(fx.value.getClass());
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    // Pass Config explicitly so we never fall back to an unconfigured default.
    return JsonStream.serialize(CFG, fx.value).getBytes(StandardCharsets.UTF_8);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return JsonIterator.deserialize(CFG, data, typeLiteral);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    byte[] b = serializeBytes(fx);
    out.write(b);
    return b.length;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return deserializeBytes(in.readAllBytes());
  }

  private record ListType(Class<?> el) implements java.lang.reflect.ParameterizedType {
    @Override
    public Type[] getActualTypeArguments() {
      return new Type[] {el};
    }

    @Override
    public Type getRawType() {
      return java.util.List.class;
    }

    @Override
    public Type getOwnerType() {
      return null;
    }
  }
}
