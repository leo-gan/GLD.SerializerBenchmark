package benchmark.serializers;

import benchmark.model.Fixture;
import com.cedarsoftware.io.JsonIo;
import com.cedarsoftware.io.ReadOptions;
import com.cedarsoftware.io.ReadOptionsBuilder;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.nio.charset.StandardCharsets;

/**
 * json-io TOON path. {@code toToon} writes the text. {@code fromToon} reads a
 * JSON tree, and the untimed {@link #toDomain} step turns that tree into the
 * suite type. Size is the UTF-8 byte length.
 *
 * @see <a href="https://github.com/jdereg/json-io">json-io</a>
 */
public final class JsonIoToonSer implements BenchSerializer {
  private static final ReadOptions STRICT = new ReadOptionsBuilder().strictToon().build();
  private final ObjectMapper mapper =
      new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
  private JavaType javaType = mapper.constructType(Object.class);

  @Override
  public String name() {
    return "json-io";
  }

  @Override
  public String version() {
    return Versions.of(JsonIo.class);
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public boolean supports(String testDataName) {
    return !"graph".equals(testDataName);
  }

  @Override
  public void prepare(Fixture fx) {
    if (TypeUtil.isList(fx.value)) {
      javaType = mapper.getTypeFactory().constructType(TypeUtil.listTypeRef(fx.value));
    } else {
      javaType = mapper.constructType(fx.value.getClass());
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    return JsonIo.toToon(fx.value).getBytes(StandardCharsets.UTF_8);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return JsonIo.fromToon(new String(data, StandardCharsets.UTF_8), STRICT).asClass(Object.class);
  }

  @Override
  public Object toDomain(Object decoded) {
    if (decoded == null) return null;
    return mapper.convertValue(decoded, javaType);
  }
}
