package benchmark.model.v2;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Data Model v2 make_one generators (within-language deterministic). */
public final class Generators {
  private static final long BASE_TS_MS = 1_704_067_200_000L;

  private Generators() {}

  public static Object makeOne(
      String typeId, Map<String, Object> typeConfig, long seed, int instanceIndex) {
    Rng r = new Rng(Rng.mixSeed(seed, typeId, instanceIndex));
    return switch (typeId) {
      case "message" -> makeMessage(r);
      case "document" -> makeDocument(r, typeConfig);
      case "telemetry" -> makeTelemetry(r, typeConfig);
      case "strings" -> makeStrings(r, typeConfig);
      case "event" -> makeEvent(r, typeConfig);
      default -> throw new IllegalArgumentException("unknown type_id: " + typeId);
    };
  }

  public static List<Object> instances(
      String typeId, Map<String, Object> typeConfig, long seed, int n) {
    List<Object> out = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      out.add(makeOne(typeId, typeConfig, seed, i));
    }
    return out;
  }

  private static int cfgInt(Map<String, Object> m, String key, int def) {
    if (m == null || !m.containsKey(key) || m.get(key) == null) return def;
    Object v = m.get(key);
    if (v instanceof Number n) return n.intValue();
    return def;
  }

  private static Message makeMessage(Rng r) {
    return new Message(
        r.nextBool(),
        r.nextInt(0, 1_000_000),
        r.nextInt(0, 1_000_000),
        r.nextF64() * 1000,
        r.word(3, 16),
        r.nextBool(),
        r.nextInt(0, 1_000_000),
        r.word(3, 16));
  }

  private static Document makeDocument(Rng r, Map<String, Object> cfg) {
    int n = cfgInt(cfg, "children", 8);
    List<Document.DocumentItem> items = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      items.add(new Document.DocumentItem(r.word(3, 12), r.nextInt(1, 100), r.nextInt(0, 100_000)));
    }
    return new Document(
        r.word(8, 12),
        r.nextInt(0, 5),
        new Document.DocumentMeta(r.word(2, 4), r.nextInt(1, 10)),
        items);
  }

  private static Telemetry makeTelemetry(Rng r, Map<String, Object> cfg) {
    int pts = cfgInt(cfg, "points", 32);
    int tagsN = cfgInt(cfg, "tag_count", 2);
    List<String> tags = new ArrayList<>(tagsN);
    for (int i = 0; i < tagsN; i++) tags.add(r.word(3, 10));
    double[] vals = new double[pts];
    for (int i = 0; i < pts; i++) vals[i] = r.nextF64() * 100;
    return new Telemetry(r.word(3, 10), BASE_TS_MS + r.nextInt(0, 86_400_000), tags, vals);
  }

  private static Strings makeStrings(Rng r, Map<String, Object> cfg) {
    int n = cfgInt(cfg, "count", 32);
    List<String> items = new ArrayList<>(n);
    for (int i = 0; i < n; i++) items.add(r.word(3, 16));
    return new Strings(items);
  }

  private static Event makeEvent(Rng r, Map<String, Object> cfg) {
    int n = cfgInt(cfg, "attr_count", 4);
    List<Event.EventAttr> attrs = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      attrs.add(new Event.EventAttr(r.word(3, 12), r.word(3, 12)));
    }
    return new Event(
        r.word(8, 12),
        r.word(3, 12),
        BASE_TS_MS + r.nextInt(0, 86_400_000),
        r.word(3, 12),
        attrs);
  }
}
