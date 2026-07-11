package benchmark.serializers;

import benchmark.model.Fixture;
import io.protostuff.LinkedBuffer;
import io.protostuff.ProtostuffIOUtil;
import io.protostuff.Schema;
import io.protostuff.runtime.RuntimeSchema;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Protostuff runtime — protobuf-style binary without .proto for POJOs (popular RPC path).
 *
 * <p>Recommended: cache {@link RuntimeSchema} per type; reuse {@link LinkedBuffer}; use
 * {@link ProtostuffIOUtil#toByteArray}/{@link ProtostuffIOUtil#mergeFrom} for singles and
 * {@code writeListTo}/{@code parseListFrom} for batches.
 *
 * @see <a href="https://github.com/protostuff/protostuff">protostuff</a>
 */
public final class ProtostuffSer implements BenchSerializer {
  private final LinkedBuffer buffer = LinkedBuffer.allocate(LinkedBuffer.DEFAULT_BUFFER_SIZE);
  private Schema<Object> schema;
  private boolean batch;
  private Class<?> elementClass;

  @Override
  public String name() {
    return "protostuff";
  }

  @Override
  public String version() {
    return Versions.of(ProtostuffIOUtil.class);
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
    batch = TypeUtil.isList(fx.value);
    elementClass = TypeUtil.elementClass(fx.value);
    schema = (Schema<Object>) (Schema<?>) RuntimeSchema.getSchema(elementClass);
    buffer.clear();
  }

  @Override
  @SuppressWarnings("unchecked")
  public byte[] serializeBytes(Fixture fx) throws Exception {
    buffer.clear();
    if (batch) {
      ByteArrayOutputStream baos = new ByteArrayOutputStream(4096);
      ProtostuffIOUtil.writeListTo(baos, (List<Object>) fx.value, schema, buffer);
      return baos.toByteArray();
    }
    return ProtostuffIOUtil.toByteArray(fx.value, schema, buffer);
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    if (batch) {
      return ProtostuffIOUtil.parseListFrom(new ByteArrayInputStream(data), schema);
    }
    Object msg = schema.newMessage();
    ProtostuffIOUtil.mergeFrom(data, msg, schema);
    return msg;
  }

  @Override
  @SuppressWarnings("unchecked")
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    buffer.clear();
    if (batch) {
      return ProtostuffIOUtil.writeListTo(out, (List<Object>) fx.value, schema, buffer);
    }
    return ProtostuffIOUtil.writeTo(out, fx.value, schema, buffer);
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    if (batch) {
      return ProtostuffIOUtil.parseListFrom(in, schema);
    }
    Object msg = schema.newMessage();
    ProtostuffIOUtil.mergeFrom(in, msg, schema);
    return msg;
  }
}
