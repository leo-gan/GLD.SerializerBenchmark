package benchmark;

import benchmark.model.Fixture;
import benchmark.serializers.Fastjson2Ser;
import benchmark.serializers.JsoniterSer;
import org.junit.jupiter.api.Test;

import java.io.InputStream;
import java.io.OutputStream;

import static org.junit.jupiter.api.Assertions.assertThrows;

/** These codecs only adapt a byte buffer, so they use BenchSerializer's default stream methods. */
class AdaptedStreamTest {
  @Test
  void fastjson2AndJsoniterUseTheInterfaceDefaults() {
    assertUsesDefault(Fastjson2Ser.class);
    assertUsesDefault(JsoniterSer.class);
  }

  private static void assertUsesDefault(Class<?> type) {
    assertThrows(
        NoSuchMethodException.class,
        () -> type.getDeclaredMethod("serializeStream", Fixture.class, OutputStream.class));
    assertThrows(
        NoSuchMethodException.class,
        () -> type.getDeclaredMethod("deserializeStream", InputStream.class));
  }
}
