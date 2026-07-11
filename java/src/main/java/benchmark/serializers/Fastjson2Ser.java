package benchmark.serializers;

import benchmark.model.Fixture;
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONReader;
import com.alibaba.fastjson2.JSONWriter;

import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Type;

/**
 * Fastjson2 — high-performance JSON (Alibaba), common in high-throughput Java services.
 *
 * <p>Recommended path: {@link JSON#toJSONBytes(Object, JSONWriter.Feature...)} and
 * {@link JSON#parseObject(byte[], Type, JSONReader.Feature...)} with {@code FieldBased} for
 * public-field POJOs. Reuse type token from prepare.
 *
 * @see <a href="https://github.com/alibaba/fastjson2/wiki">Fastjson2 wiki</a>
 */
public final class Fastjson2Ser implements BenchSerializer {
  private Type type;

  @Override
  public String name() {
    return "fastjson2";
  }

  @Override
  public String version() {
    return Versions.of(JSON.class);
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public void prepare(Fixture fx) {
    if (TypeUtil.isList(fx.value)) {
      Class<?> el = TypeUtil.elementClass(fx.value);
      type = new ParameterizedList(el);
    } else {
      type = fx.value.getClass();
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    return JSON.toJSONBytes(fx.value, JSONWriter.Feature.FieldBased);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return JSON.parseObject(data, type, JSONReader.Feature.FieldBased);
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

  private record ParameterizedList(Class<?> el) implements java.lang.reflect.ParameterizedType {
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
