package benchmark;

import benchmark.model.Fixture;
import benchmark.model.v2.Generators;
import benchmark.serializers.BenchSerializer;
import benchmark.serializers.Registry;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertTrue;

class RoundtripTest {
  @Test
  void allSerializersRoundtripMessage() throws Exception {
    Object msg = Generators.makeOne("message", Map.of(), 42L, 0);
    Fixture fx = new Fixture("message", msg);
    for (BenchSerializer ser : Registry.all()) {
      ser.prepare(fx);
      byte[] buf = ser.serializeBytes(fx);
      Object out = ser.toDomain(ser.deserializeBytes(buf));
      assertTrue(Fidelity.check(msg, out), () -> "fidelity failed for " + ser.name());
    }
  }
}
