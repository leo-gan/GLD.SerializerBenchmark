package benchmark.serializers;

import benchmark.model.Fixture;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.ObjectWriter;
import com.fasterxml.jackson.dataformat.smile.SmileFactory;
import com.fasterxml.jackson.dataformat.smile.databind.SmileMapper;

import java.io.InputStream;
import java.io.OutputStream;

/**
 * Jackson Smile — binary JSON (Elasticsearch / Jackson ecosystem).
 *
 * <p>Recommended: reuse {@link SmileMapper}; typed writer/reader.
 *
 * @see <a href="https://github.com/FasterXML/jackson-dataformats-binary">jackson-dataformats-binary</a>
 */
public final class JacksonSmileSer implements BenchSerializer {
  private final ObjectMapper mapper;
  private ObjectWriter writer;
  private ObjectReader reader;

  public JacksonSmileSer() {
    mapper = new SmileMapper(new SmileFactory());
  }

  @Override
  public String name() {
    return "jackson-smile";
  }

  @Override
  public String version() {
    return Versions.of(SmileMapper.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public void prepare(Fixture fx) {
    if (TypeUtil.isList(fx.value)) {
      writer = mapper.writerFor(TypeUtil.listTypeRef(fx.value));
      reader = mapper.readerFor(TypeUtil.listTypeRef(fx.value));
    } else {
      writer = mapper.writerFor(fx.value.getClass());
      reader = mapper.readerFor(fx.value.getClass());
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    return writer.writeValueAsBytes(fx.value);
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    return reader.readValue(data);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    JacksonSer.CountingOutputStream cos = new JacksonSer.CountingOutputStream(out);
    writer.writeValue(cos, fx.value);
    return cos.count;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return reader.readValue(in);
  }
}
