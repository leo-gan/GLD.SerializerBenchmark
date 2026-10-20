package benchmark.model.v2;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** Data Model v2 make_one generators (within-language deterministic). */
public final class Generators {
  private static final long BASE_TS_MS = 1_704_067_200_000L;

  private Generators() {}

  public static Object makeOne(
      String typeId, Map<String, Object> typeConfig, long seed, int instanceIndex) {
    // tensor_view is the same matrix as tensor for this seed and shape.
    String seedId = "tensor_view".equals(typeId) ? "tensor" : typeId;
    Rng r = new Rng(Rng.mixSeed(seed, seedId, instanceIndex));
    return switch (typeId) {
      case "message" -> makeMessage(r);
      case "document" -> makeDocument(r, typeConfig);
      case "telemetry" -> makeTelemetry(r, typeConfig);
      case "strings" -> makeStrings(r, typeConfig);
      case "event" -> makeEvent(r, typeConfig);
      case "table", "table_project" -> makeTable(r, typeConfig, seed, typeId);
      case "nested_table" -> makeNested(r, typeConfig);
      case "signal" -> makeSignal(r, typeConfig);
      case "tensor", "tensor_view" -> makeTensor(r, typeConfig);
      case "prompt" -> makePrompt(r, typeConfig);
      case "shard" -> makeShard(r, typeConfig);
      case "request" -> makeRequest(r, typeConfig);
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

  private static double cfgDouble(Map<String, Object> m, String key, double def) {
    if (m == null || !m.containsKey(key) || m.get(key) == null) return def;
    Object v = m.get(key);
    if (v instanceof Number n) return n.doubleValue();
    return def;
  }

  private static Map<String, Object> cfgMap(Map<String, Object> m, String key) {
    if (m == null || !(m.get(key) instanceof Map<?, ?> raw)) return Map.of();
    Map<String, Object> out = new HashMap<>();
    for (Map.Entry<?, ?> e : raw.entrySet()) {
      out.put(String.valueOf(e.getKey()), e.getValue());
    }
    return out;
  }

  /** Catalog string_len, or {@code defMin..defMax} when the key is absent. */
  private static int[] slen(Map<String, Object> cfg, int defMin, int defMax) {
    Map<String, Object> sl = cfgMap(cfg, "string_len");
    return new int[] {cfgInt(sl, "min", defMin), cfgInt(sl, "max", defMax)};
  }

  private static int[] irange(Map<String, Object> cfg) {
    Map<String, Object> ir = cfgMap(cfg, "int_range");
    return new int[] {cfgInt(ir, "min", 0), cfgInt(ir, "max", 1_000_000)};
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

  private static List<String> vocab(long seed, String typeId, int smin, int smax) {
    Rng vr = new Rng(Rng.mixSeed(seed, typeId + "#vocab", 0));
    List<String> out = new ArrayList<>(32);
    for (int i = 0; i < 32; i++) out.add(vr.word(smin, smax));
    return out;
  }

  private static String pick(Rng r, List<String> vocab, double duplication, int smin, int smax) {
    if (!vocab.isEmpty() && r.nextF64() < duplication) {
      return vocab.get(r.nextInt(0, vocab.size() - 1));
    }
    return r.word(smin, smax);
  }

  private static TableRow makeTable(Rng r, Map<String, Object> cfg, long seed, String typeId) {
    int[] sl = slen(cfg, 3, 16);
    int[] ir = irange(cfg);
    double dup = cfgDouble(cfg, "duplication", 0.5);
    List<String> words = vocab(seed, typeId, sl[0], sl[1]);
    double[] f = new double[16];
    for (int i = 0; i < f.length; i++) f[i] = r.nextF64() * 1000.0;
    long[] n = new long[4];
    for (int i = 0; i < n.length; i++) n[i] = r.nextInt(ir[0], ir[1]);
    TableRow row = new TableRow();
    row.fFloat0 = f[0];
    row.fFloat1 = f[1];
    row.fFloat2 = f[2];
    row.fFloat3 = f[3];
    row.fFloat4 = f[4];
    row.fFloat5 = f[5];
    row.fFloat6 = f[6];
    row.fFloat7 = f[7];
    row.fFloat8 = f[8];
    row.fFloat9 = f[9];
    row.fFloat10 = f[10];
    row.fFloat11 = f[11];
    row.fFloat12 = f[12];
    row.fFloat13 = f[13];
    row.fFloat14 = f[14];
    row.fFloat15 = f[15];
    row.fInt0 = n[0];
    row.fInt1 = n[1];
    row.fInt2 = n[2];
    row.fInt3 = n[3];
    row.fStr0 = pick(r, words, dup, sl[0], sl[1]);
    row.fStr1 = pick(r, words, dup, sl[0], sl[1]);
    return row;
  }

  /** Draw order: id, status, meta, then items. */
  private static NestedRow makeNested(Rng r, Map<String, Object> cfg) {
    int[] sl = slen(cfg, 3, 12);
    int children = cfgInt(cfg, "children", 4);
    NestedRow row = new NestedRow();
    row.id = r.word(8, 12);
    row.status = r.nextInt(0, 5);
    row.meta = new NestedRow.NestedMeta(r.word(2, 4), r.nextInt(1, 10));
    for (int i = 0; i < children; i++) {
      row.items.add(
          new NestedRow.NestedItem(
              r.word(sl[0], sl[1]), r.nextInt(1, 100), r.nextInt(0, 100_000)));
    }
    return row;
  }

  /**
   * Domain draw order is fixed fields, then symbol and venue, then legs.
   * {@code leg_pad} is the constant 0 and does not consume the PRNG.
   */
  private static Signal makeSignal(Rng r, Map<String, Object> cfg) {
    int[] sl = slen(cfg, 3, 12);
    int groups = cfgInt(cfg, "group_count", 4);
    Signal row = new Signal();
    row.seq = r.nextInt(0, 1_000_000_000);
    row.ts = BASE_TS_MS + r.nextInt(0, 86_400_000);
    row.priceMantissa = r.nextInt(0, 1_000_000_000);
    row.qty = r.nextInt(0, 10_000);
    row.flags = r.nextInt(0, 65_535);
    row.symbol = r.word(sl[0], sl[1]);
    row.venue = r.word(sl[0], sl[1]);
    for (int i = 0; i < groups; i++) {
      row.legs.add(new Signal.SignalLeg(r.nextInt(0, 1_000_000), r.nextInt(0, 10_000), 0));
    }
    return row;
  }

  /**
   * Draw every element, then pin index 0 to negative zero and index 1 to quiet NaN
   * {@code 0x7fc00000}. The pins do not skip those RNG steps.
   */
  private static float[] f32Fill(Rng r, int count, boolean pin) {
    float[] values = new float[count];
    for (int i = 0; i < count; i++) {
      values[i] = (float) r.nextF64();
    }
    if (pin && count >= 2) {
      values[0] = Float.intBitsToFloat(0x80000000);
      values[1] = Float.intBitsToFloat(0x7fc00000);
    }
    return values;
  }

  private static TensorMatrix makeTensor(Rng r, Map<String, Object> cfg) {
    int rows = cfgInt(cfg, "rows", 1024);
    int cols = cfgInt(cfg, "cols", 1024);
    return new TensorMatrix(rows, cols, f32Fill(r, rows * cols, true));
  }

  /** Row-major. Position ids are the column index and do not draw from the RNG. */
  private static Prompt makePrompt(Rng r, Map<String, Object> cfg) {
    int batch = cfgInt(cfg, "batch", 4);
    int seq = cfgInt(cfg, "seq", 256);
    int vocab = cfgInt(cfg, "vocab", 32000);
    int n = batch * seq;
    long[] inputIds = new long[n];
    long[] attentionMask = new long[n];
    long[] positionIds = new long[n];
    int lo = Math.max(1, seq / 2);
    for (int row = 0; row < batch; row++) {
      int content = r.nextInt(lo, seq);
      for (int col = 0; col < seq; col++) {
        int i = row * seq + col;
        if (col < content) {
          inputIds[i] = r.nextInt(1, vocab - 1);
          attentionMask[i] = 1L;
        } else {
          inputIds[i] = 0L;
          attentionMask[i] = 0L;
        }
        positionIds[i] = col;
      }
    }
    return new Prompt(batch, seq, inputIds, attentionMask, positionIds);
  }

  /** Fill order: embedding, attention, feed-forward, norm. No pinned NaN. */
  private static Shard makeShard(Rng r, Map<String, Object> cfg) {
    int vocab = cfgInt(cfg, "vocab", 1024);
    int hidden = cfgInt(cfg, "hidden", 256);
    int ffn = cfgInt(cfg, "ffn", 512);
    return new Shard(
        vocab,
        hidden,
        ffn,
        f32Fill(r, vocab * hidden, false),
        f32Fill(r, hidden * hidden, false),
        f32Fill(r, ffn * hidden, false),
        f32Fill(r, hidden, false));
  }

  /** Call order: request id, model name, temperature, then the prompt. */
  private static Request makeRequest(Rng r, Map<String, Object> cfg) {
    int[] sl = slen(cfg, 3, 16);
    return new Request(
        r.nextInt(1, 1_000_000_000),
        r.word(sl[0], sl[1]),
        (float) (r.nextF64() * 2.0),
        makePrompt(r, cfg));
  }
}
