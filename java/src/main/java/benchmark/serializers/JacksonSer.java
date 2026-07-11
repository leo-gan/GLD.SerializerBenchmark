package benchmark.serializers;

import benchmark.model.Fixture;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.ObjectWriter;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.SerializationFeature;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Jackson databind — de-facto Java JSON standard.
 *
 * <p>Recommended hot path (Jackson performance docs):
 *
 * <ul>
 *   <li>Reuse a single ObjectMapper (expensive to construct)
 *   <li>Cache ObjectWriter / ObjectReader for the target type
 *   <li>{@code writeValueAsBytes} / {@code readValue} for bytes mode
 *   <li>{@code writeValue(OutputStream)} / {@code readValue(InputStream)} for streams
 * </ul>
 *
 * @see <a href="https://github.com/FasterXML/jackson-docs/wiki/presentation:-jackson-performance">Jackson performance</a>
 */
public final class JacksonSer implements BenchSerializer {
  private final ObjectMapper mapper;
  private ObjectWriter writer;
  private ObjectReader reader;
  private Object proto;

  public JacksonSer() {
    mapper = new ObjectMapper();
    // Field-visible POJOs (public fields); no pretty print.
    mapper.findAndRegisterModules();
    mapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
    mapper.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
  }

  @Override
  public String name() {
    return "jackson";
  }

  @Override
  public String version() {
    return Versions.of(ObjectMapper.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public void prepare(Fixture fx) {
    proto = fx.value;
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
    CountingOutputStream cos = new CountingOutputStream(out);
    writer.writeValue(cos, fx.value);
    return cos.count;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return reader.readValue(in);
  }

  static final class CountingOutputStream extends OutputStream {
    final OutputStream delegate;
    int count;

    CountingOutputStream(OutputStream delegate) {
      this.delegate = delegate;
    }

    @Override
    public void write(int b) throws java.io.IOException {
      delegate.write(b);
      count++;
    }

    @Override
    public void write(byte[] b, int off, int len) throws java.io.IOException {
      delegate.write(b, off, len);
      count += len;
    }
  }
}
