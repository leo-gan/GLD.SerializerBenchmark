package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.Strings;
import benchmark.model.v2.Telemetry;
import org.apache.fory.Fory;
import org.apache.fory.config.Language;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;

/**
 * Apache Fory (formerly Fury) — JIT/codegen multi-language binary serialization.
 *
 * <p>Recommended hot path: reuse one {@link Fory} with {@code Language.JAVA} + codegen; register
 * all hot classes <em>before</em> the first serialize (registration freezes after first use);
 * timed path is {@link Fory#serialize}/{@link Fory#deserialize}.
 *
 * @see <a href="https://fory.apache.org/docs/docs/guide/java_serialization_guide">Java guide</a>
 */
public final class ForySer implements BenchSerializer {
  private final Fory fory;

  public ForySer() {
    fory =
        Fory.builder()
            .withLanguage(Language.JAVA)
            .requireClassRegistration(true)
            .withRefTracking(false)
            .withCodegen(true)
            .build();
    // Must register before any top-level serialize/deserialize (Fory freezes registration).
    fory.register(Message.class);
    fory.register(Document.class);
    fory.register(Document.DocumentMeta.class);
    fory.register(Document.DocumentItem.class);
    fory.register(Telemetry.class);
    fory.register(Strings.class);
    fory.register(Event.class);
    fory.register(Event.EventAttr.class);
    fory.register(ArrayList.class);
    fory.register(double[].class);
  }

  @Override
  public String name() {
    return "fory";
  }

  @Override
  public String version() {
    return Versions.of(Fory.class);
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public String nativeKind() {
    return "message";
  }

  @Override
  public void prepare(Fixture fx) {
    // Types already registered in constructor. Optional: warm codegen for this root type.
    fory.serialize(fx.value);
    fory.deserialize(fory.serialize(fx.value));
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    return fory.serialize(fx.value);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return fory.deserialize(data);
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    byte[] b = fory.serialize(fx.value);
    out.write(b);
    return b.length;
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return fory.deserialize(in.readAllBytes());
  }
}
