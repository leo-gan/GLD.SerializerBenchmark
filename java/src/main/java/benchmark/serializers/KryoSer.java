package benchmark.serializers;

import benchmark.model.Fixture;
import com.esotericsoftware.kryo.Kryo;
import com.esotericsoftware.kryo.io.Input;
import com.esotericsoftware.kryo.io.Output;
import com.esotericsoftware.kryo.util.DefaultInstantiatorStrategy;
import org.objenesis.strategy.StdInstantiatorStrategy;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Kryo — dominant high-performance Java binary serializer (caches, RPC, game state).
 *
 * <p>Recommended hot path: reuse one {@link Kryo} + {@link Output}/{@link Input} buffers;
 * register hot classes; {@code writeClassAndObject}/{@code readClassAndObject} for polymorphic
 * roots (lists). Instantiator strategy for classes without no-arg constructors if needed.
 *
 * @see <a href="https://github.com/EsotericSoftware/kryo">Kryo</a>
 */
public final class KryoSer implements BenchSerializer {
  private final Kryo kryo;
  private final Output output;
  private final Input input;
  private final ByteArrayOutputStream baos;
  private Class<?> rootClass;

  public KryoSer() {
    kryo = new Kryo();
    // Registration optional for flexibility; still register suite types in prepare for speed.
    kryo.setRegistrationRequired(false);
    kryo.setReferences(true);
    kryo.setInstantiatorStrategy(
        new DefaultInstantiatorStrategy(new StdInstantiatorStrategy()));
    baos = new ByteArrayOutputStream(4096);
    output = new Output(baos, 4096);
    input = new Input(4096);
  }

  @Override
  public String name() {
    return "kryo";
  }

  @Override
  public String version() {
    return Versions.of(Kryo.class);
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
    rootClass = fx.value.getClass();
    // Register element types for faster serializers
    Class<?> el = TypeUtil.elementClass(fx.value);
    kryo.register(el);
    kryo.register(rootClass);
    kryo.register(java.util.ArrayList.class);
    if (el.getDeclaringClass() != null) {
      // nested static classes already registered via el
    }
    baos.reset();
    output.reset();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    baos.reset();
    output.setOutputStream(baos);
    output.reset();
    kryo.writeClassAndObject(output, fx.value);
    output.flush();
    return baos.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    input.setBuffer(data);
    return kryo.readClassAndObject(input);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) {
    output.setOutputStream(out);
    output.reset();
    kryo.writeClassAndObject(output, fx.value);
    output.flush();
    return (int) output.total();
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    input.setInputStream(in);
    return kryo.readClassAndObject(input);
  }
}
