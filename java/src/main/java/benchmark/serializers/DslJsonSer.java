package benchmark.serializers;

import benchmark.model.Fixture;
import com.dslplatform.json.DslJson;
import com.dslplatform.json.JsonWriter;
import com.dslplatform.json.runtime.Settings;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;

/**
 * DSL-JSON — among the fastest pure-Java JSON libraries (runtime binding path).
 *
 * <p>Recommended: single reused {@link DslJson} with runtime settings; {@link JsonWriter}
 * buffer reuse; {@code serialize}/{@code deserialize} on known types.
 *
 * @see <a href="https://github.com/ngs-doo/dsl-json">dsl-json</a>
 */
public final class DslJsonSer implements BenchSerializer {
  private final DslJson<Object> dsl;
  private final JsonWriter writer;
  private final ByteArrayOutputStream baos;
  private Type type;

  public DslJsonSer() {
    // Runtime analysis for POJOs without annotation processor (still recommended Settings).
    dsl =
        new DslJson<>(
            Settings.withRuntime()
                .allowArrayFormat(true)
                .includeServiceLoader());
    baos = new ByteArrayOutputStream(4096);
    writer = dsl.newWriter(4096);
  }

  @Override
  public String name() {
    return "dsl-json";
  }

  @Override
  public String version() {
    return Versions.of(DslJson.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public void prepare(Fixture fx) {
    if (TypeUtil.isList(fx.value)) {
      Class<?> el = TypeUtil.elementClass(fx.value);
      type = new ListType(el);
    } else {
      type = fx.value.getClass();
    }
    writer.reset();
    baos.reset();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    writer.reset();
    dsl.serialize(writer, type, fx.value);
    return writer.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    return dsl.deserialize(type, data, data.length);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    writer.reset();
    dsl.serialize(writer, type, fx.value);
    writer.toStream(out);
    return writer.size();
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return dsl.deserialize(type, in);
  }

  private record ListType(Class<?> el) implements ParameterizedType {
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
