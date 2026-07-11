package benchmark.serializers;

import benchmark.model.Fixture;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.io.OutputStream;

/**
 * java.io serialization — JDK baseline ({@link ObjectOutputStream}/{@link ObjectInputStream}).
 *
 * <p>Not recommended for new systems (security + size), but essential as the language-native
 * binary baseline in comparative benchmarks.
 */
public final class JavaSerializationSer implements BenchSerializer {
  private final ByteArrayOutputStream baos = new ByteArrayOutputStream(4096);

  @Override
  public String name() {
    return "java-serialization";
  }

  @Override
  public String version() {
    return System.getProperty("java.version", "unknown");
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public String nativeKind() {
    return "message";
  }

  @Override
  public void prepare(Fixture fx) {
    baos.reset();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    baos.reset();
    try (ObjectOutputStream oos = new ObjectOutputStream(baos)) {
      oos.writeObject(fx.value);
    }
    return baos.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    try (ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(data))) {
      return ois.readObject();
    }
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    CountingOutputStream cos = new CountingOutputStream(out);
    try (ObjectOutputStream oos = new ObjectOutputStream(cos)) {
      oos.writeObject(fx.value);
    }
    return cos.count;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    try (ObjectInputStream ois = new ObjectInputStream(in)) {
      return ois.readObject();
    }
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
