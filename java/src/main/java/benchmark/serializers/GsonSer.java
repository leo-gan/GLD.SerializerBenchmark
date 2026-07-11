package benchmark.serializers;

import benchmark.model.Fixture;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import com.google.gson.stream.JsonReader;
import com.google.gson.stream.JsonWriter;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;

/**
 * Gson — Google's widely deployed JSON library.
 *
 * <p>Recommended: reuse a single {@link Gson}; {@code toJson}/{@code fromJson} with explicit
 * {@link Type} for lists; stream via {@link JsonWriter}/{@link JsonReader}. Disable HTML escaping
 * for throughput-oriented use (Gson User Guide).
 *
 * @see <a href="https://github.com/google/gson/blob/main/UserGuide.md">Gson User Guide</a>
 */
public final class GsonSer implements BenchSerializer {
  private final Gson gson;
  private Type type;

  public GsonSer() {
    gson = new GsonBuilder().disableHtmlEscaping().create();
  }

  @Override
  public String name() {
    return "gson";
  }

  @Override
  public String version() {
    return Versions.of(Gson.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public void prepare(Fixture fx) {
    if (TypeUtil.isList(fx.value)) {
      Class<?> el = TypeUtil.elementClass(fx.value);
      type = TypeToken.getParameterized(java.util.List.class, el).getType();
    } else {
      type = fx.value.getClass();
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    return gson.toJson(fx.value, type).getBytes(StandardCharsets.UTF_8);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return gson.fromJson(new String(data, StandardCharsets.UTF_8), type);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    CountingOutputStream cos = new CountingOutputStream(out);
    OutputStreamWriter osw = new OutputStreamWriter(cos, StandardCharsets.UTF_8);
    JsonWriter jw = gson.newJsonWriter(osw);
    gson.toJson(fx.value, type, jw);
    jw.flush();
    osw.flush();
    return cos.count;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    JsonReader jr = gson.newJsonReader(new InputStreamReader(in, StandardCharsets.UTF_8));
    return gson.fromJson(jr, type);
  }

  static final class CountingOutputStream extends OutputStream {
    final OutputStream d;
    int count;

    CountingOutputStream(OutputStream d) {
      this.d = d;
    }

    @Override
    public void write(int b) throws java.io.IOException {
      d.write(b);
      count++;
    }

    @Override
    public void write(byte[] b, int off, int len) throws java.io.IOException {
      d.write(b, off, len);
      count += len;
    }
  }
}
