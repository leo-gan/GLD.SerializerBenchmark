package benchmark;

import benchmark.model.Fixture;
import benchmark.model.v2.Generators;
import benchmark.serializers.BenchSerializer;
import benchmark.serializers.Registry;
import org.junit.jupiter.api.Test;

import java.util.Map;

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
}
