package benchmark.serializers;

import benchmark.model.Fixture;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.ObjectWriter;
import com.fasterxml.jackson.dataformat.ion.IonFactory;
import com.fasterxml.jackson.dataformat.ion.IonObjectMapper;

import java.io.InputStream;
import java.io.OutputStream;

/**
 * Amazon Ion (binary) via Jackson dataformat — AWS ecosystem document binary format.
 *
 * <p>Recommended: reuse {@link IonObjectMapper}/{@link IonFactory}; typed writer/reader;
 * binary Ion (default factory), not text Ion.
 *
 * @see <a href="https://amazon-ion.github.io/ion-docs/">Ion docs</a>
 */
public final class IonSer implements BenchSerializer {
  private final ObjectMapper mapper;
  private ObjectWriter writer;
  private ObjectReader reader;

  public IonSer() {
    // IonFactory defaults to binary Ion encoding with ObjectMapper data-binding.
    mapper = new IonObjectMapper(new IonFactory());
  }

  @Override
  public String name() {
    return "ion";
  }

  @Override
  public String version() {
    return Versions.of(IonObjectMapper.class);
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
