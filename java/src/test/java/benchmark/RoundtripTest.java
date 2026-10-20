package benchmark;

import benchmark.model.Fixture;
import benchmark.model.v2.Generators;
import benchmark.model.v2.TensorMatrix;
import benchmark.serializers.BenchSerializer;
import benchmark.serializers.KilnSer;
import benchmark.serializers.Registry;
import org.junit.jupiter.api.Test;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RoundtripTest {
  private static final String[] FIXTURES = {
    "message", "document", "telemetry", "strings", "event"
  };

  @Test
  void allSerializersRoundtripMessage() throws Exception {
    roundtripType("message");
  }

  @Test
  void allSerializersRoundtripAllFixtures() throws Exception {
    for (String type : FIXTURES) {
      roundtripType(type);
    }
  }

  private static void roundtripType(String type) throws Exception {
    Object expected = Generators.makeOne(type, Map.of(), 42L, 0);
    Fixture fx = new Fixture(type, expected);
    for (BenchSerializer ser : Registry.all()) {
      if (!ser.supports(type)) {
        continue;
      }
      ser.prepare(fx);
      byte[] buf = ser.serializeBytes(fx);
      Object out = ser.toDomain(ser.deserializeBytes(buf));
      assertTrue(
          Fidelity.check(expected, out),
          () -> "fidelity failed for " + ser.name() + " on " + type);
    }
  }

  @Test
  void kilnTensorSetRoundTrip() throws Exception {
    Map<String, Object> cfg = new HashMap<>();
    cfg.put("rows", 4);
    cfg.put("cols", 4);
    cfg.put("batch", 2);
    cfg.put("seq", 8);
    cfg.put("vocab", 128);
    cfg.put("hidden", 4);
    cfg.put("ffn", 6);
    KilnSer ser = new KilnSer();
    for (String type : List.of("tensor", "tensor_view", "prompt", "shard", "request")) {
      Object expected = Generators.makeOne(type, cfg, 42L, 0);
      assertTrue(ser.supports(type), type);
      Fixture fx = new Fixture(type, expected);
      ser.prepare(fx);
      byte[] buf = ser.serializeBytes(fx);
      Object decoded = ser.deserializeBytes(buf);
      if ("tensor_view".equals(type)) {
        TensorMatrix.View view = (TensorMatrix.View) decoded;
        assertSame(buf, view.data);
        assertEquals(12, view.offset);
        assertEquals(buf.length - 12, view.length);
      } else if ("tensor".equals(type)) {
        assertTrue(decoded instanceof Map<?, ?>);
      }
      assertTrue(Fidelity.check(expected, ser.toDomain(decoded)), type);
    }

    Map<String, Object> full = new HashMap<>();
    full.put("rows", 1024);
    full.put("cols", 1024);
    TensorMatrix tensor = (TensorMatrix) Generators.makeOne("tensor", full, 7L, 0);
    TensorMatrix same = (TensorMatrix) Generators.makeOne("tensor_view", full, 7L, 0);
    assertTrue(Fidelity.check(tensor, same));
    assertEquals(0x80000000, Float.floatToRawIntBits(tensor.values[0]));
    assertEquals(0x7fc00000, Float.floatToRawIntBits(tensor.values[1]));
    float[] tweaked = tensor.values.clone();
    tweaked[0] = 0.0f;
    assertFalse(Fidelity.check(tensor, new TensorMatrix(tensor.rows, tensor.cols, tweaked)));

    Fixture owned = new Fixture("tensor", tensor);
    ser.prepare(owned);
    byte[] raw = ser.serializeBytes(owned);
    assertEquals(4_194_316, raw.length);
    assertTrue(Fidelity.check(tensor, ser.toDomain(ser.deserializeBytes(raw))));

    Fixture fx = new Fixture("tensor_view", same);
    ser.prepare(fx);
    byte[] buf = ser.serializeBytes(fx);
    assertEquals(4_194_316, buf.length);
    Object decoded = ser.deserializeBytes(buf);
    TensorMatrix.View view = (TensorMatrix.View) decoded;
    assertSame(buf, view.data);
    assertTrue(Fidelity.check(same, ser.toDomain(decoded)));
    buf[12] ^= 1;
    assertFalse(Fidelity.check(same, decoded));
  }

  @Test
  void compressSizesGzipHello() {
    int[] c = Compress.sizes("hello".getBytes(java.nio.charset.StandardCharsets.UTF_8));
    assertTrue(c[0] >= 20 && c[0] <= 40, "gzip=" + c[0]);
    int[] empty = Compress.sizes(new byte[0]);
    assertTrue(empty[0] == 0 && empty[1] == 0);
  }
}
