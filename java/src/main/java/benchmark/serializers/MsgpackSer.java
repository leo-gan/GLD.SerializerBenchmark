package benchmark.serializers;

import benchmark.model.Fixture;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.ObjectWriter;
import org.msgpack.jackson.dataformat.MessagePackFactory;
import org.msgpack.jackson.dataformat.MessagePackMapper;

import java.io.InputStream;
import java.io.OutputStream;

/**
 * MessagePack via jackson-dataformat-msgpack (official msgpack-java Jackson binding).
 *
 * <p>Recommended: reuse {@link MessagePackMapper} / {@link ObjectMapper} with
 * {@link MessagePackFactory}; type-specific {@link ObjectWriter}/{@link ObjectReader}.
 *
 * @see <a href="https://github.com/msgpack/msgpack-java">msgpack-java</a>
 */
public final class MsgpackSer implements BenchSerializer {
  private final ObjectMapper mapper;
  private ObjectWriter writer;
  private ObjectReader reader;

  public MsgpackSer() {
    mapper = new MessagePackMapper(new MessagePackFactory());
  }

  @Override
  public String name() {
    return "msgpack";
  }

  @Override
  public String version() {
    return Versions.of(MessagePackMapper.class);
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
