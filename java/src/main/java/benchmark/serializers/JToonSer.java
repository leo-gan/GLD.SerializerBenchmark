package benchmark.serializers;

import benchmark.model.Fixture;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JavaType;
import com.fasterxml.jackson.databind.ObjectMapper;
import dev.toonformat.jtoon.JToon;

import java.nio.charset.StandardCharsets;

/**
 * Official Java TOON codec. Encode and decode are the library's text API.
 * Decode returns a JSON tree. Turning that tree into the suite type is
 * untimed {@link #toDomain}. Size is the UTF-8 byte length.
 *
 * @see <a href="https://github.com/toon-format/toon-java">toon-java</a>
 */
public final class JToonSer implements BenchSerializer {
  private final ObjectMapper mapper =
      new ObjectMapper().configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
  private JavaType javaType = mapper.constructType(Object.class);

  @Override
  public String name() {
    return "jtoon";
  }

  @Override
  public String version() {
    return Versions.of(JToon.class);
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
    return JToon.encode(fx.value).getBytes(StandardCharsets.UTF_8);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return JToon.decode(new String(data, StandardCharsets.UTF_8));
  }

  @Override
  public Object toDomain(Object decoded) {
    if (decoded == null) return null;
    return mapper.convertValue(decoded, javaType);
  }
}
