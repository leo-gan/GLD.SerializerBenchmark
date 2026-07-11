package benchmark.serializers;

import java.io.InputStream;
import java.util.Properties;

/**
 * Best-effort library version. Prefer Maven-filtered versions.properties; fall back to package
 * Implementation-Version (often missing in shaded jars).
 */
public final class Versions {
  private static final Properties PROPS = load();

  private Versions() {}

  private static Properties load() {
    Properties p = new Properties();
    try (InputStream in =
        Versions.class.getClassLoader().getResourceAsStream("benchmark-versions.properties")) {
      if (in != null) p.load(in);
    } catch (Exception ignored) {
      // optional resource
    }
    return p;
  }

  public static String of(Class<?> cls) {
    String key = cls.getName();
    String v = PROPS.getProperty(key);
    if (v != null && !v.isBlank()) return v;
    // try simple name keys
    v = PROPS.getProperty(cls.getSimpleName());
    if (v != null && !v.isBlank()) return v;
    Package p = cls.getPackage();
    if (p != null) {
      String iv = p.getImplementationVersion();
      if (iv != null && !iv.isBlank()) return iv;
    }
    return PROPS.getProperty("default", "unknown");
  }
}
