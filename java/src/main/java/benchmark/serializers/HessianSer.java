package benchmark.serializers;

import benchmark.model.Fixture;
import com.caucho.hessian.io.Hessian2Input;
import com.caucho.hessian.io.Hessian2Output;
import com.caucho.hessian.io.SerializerFactory;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Hessian2 (Caucho) — compact binary RPC serialization still common (e.g. Dubbo stacks).
 *
 * <p>Recommended: reuse {@link SerializerFactory}; {@link Hessian2Output#writeObject} /
 * {@link Hessian2Input#readObject} (Hessian2, not Hessian 1.x).
 *
 * @see <a href="http://hessian.caucho.com/">Hessian</a>
 */
public final class HessianSer implements BenchSerializer {
  private final SerializerFactory factory = new SerializerFactory();
  private final ByteArrayOutputStream baos = new ByteArrayOutputStream(4096);

  @Override
  public String name() {
    return "hessian";
  }

  @Override
  public String version() {
    return Versions.of(Hessian2Output.class);
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
    Hessian2Output out = new Hessian2Output(baos);
    out.setSerializerFactory(factory);
    out.writeObject(fx.value);
    out.flush();
    out.close();
    return baos.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    Hessian2Input in = new Hessian2Input(new ByteArrayInputStream(data));
    in.setSerializerFactory(factory);
    Object o = in.readObject();
    in.close();
    return o;
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    CountingOutputStream cos = new CountingOutputStream(out);
    Hessian2Output hout = new Hessian2Output(cos);
    hout.setSerializerFactory(factory);
    hout.writeObject(fx.value);
    hout.flush();
    hout.close();
    return cos.count;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    Hessian2Input hin = new Hessian2Input(in);
    hin.setSerializerFactory(factory);
    return hin.readObject();
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
