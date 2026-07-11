package benchmark.serializers;

import benchmark.model.Fixture;
import org.apache.avro.Schema;
import org.apache.avro.io.BinaryDecoder;
import org.apache.avro.io.BinaryEncoder;
import org.apache.avro.io.DecoderFactory;
import org.apache.avro.io.EncoderFactory;
import org.apache.avro.reflect.ReflectData;
import org.apache.avro.reflect.ReflectDatumReader;
import org.apache.avro.reflect.ReflectDatumWriter;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Apache Avro (reflect binding) — schema-based binary used widely in data pipelines.
 *
 * <p>Recommended: derive schema once via {@link ReflectData}; reuse
 * {@link ReflectDatumWriter}/{@link ReflectDatumReader}; reuse
 * {@link BinaryEncoder}/{@link BinaryDecoder} via EncoderFactory/DecoderFactory.
 *
 * @see <a href="https://avro.apache.org/docs/current/">Avro docs</a>
 */
public final class AvroSer implements BenchSerializer {
  private Schema schema;
  private ReflectDatumWriter<Object> writer;
  private ReflectDatumReader<Object> reader;
  private final ByteArrayOutputStream baos = new ByteArrayOutputStream(4096);
  private BinaryEncoder encoder;
  private BinaryDecoder decoder;
  private Object proto;

  @Override
  public String name() {
    return "avro";
  }

  @Override
  public String version() {
    return Versions.of(Schema.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public String nativeKind() {
    return "schema";
  }

  @Override
  @SuppressWarnings("unchecked")
  public void prepare(Fixture fx) {
    proto = fx.value;
    Class<?> cls = TypeUtil.isList(fx.value) ? java.util.List.class : fx.value.getClass();
    if (TypeUtil.isList(fx.value)) {
      Class<?> el = TypeUtil.elementClass(fx.value);
      Schema elSchema = ReflectData.get().getSchema(el);
      schema = Schema.createArray(elSchema);
    } else {
      schema = ReflectData.get().getSchema(fx.value.getClass());
    }
    writer = new ReflectDatumWriter<>(schema, ReflectData.get());
    reader = new ReflectDatumReader<>(schema, schema, ReflectData.get());
    baos.reset();
    encoder = null;
    decoder = null;
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    baos.reset();
    encoder = EncoderFactory.get().binaryEncoder(baos, encoder);
    writer.write(fx.value, encoder);
    encoder.flush();
    return baos.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    decoder = DecoderFactory.get().binaryDecoder(data, decoder);
    return reader.read(null, decoder);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    CountingOutputStream cos = new CountingOutputStream(out);
    encoder = EncoderFactory.get().binaryEncoder(cos, encoder);
    writer.write(fx.value, encoder);
    encoder.flush();
    return cos.count;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    decoder = DecoderFactory.get().binaryDecoder(in, decoder);
    return reader.read(null, decoder);
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
