package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.Prompt;
import benchmark.model.v2.Request;
import benchmark.model.v2.Shard;
import benchmark.model.v2.Strings;
import benchmark.model.v2.Telemetry;
import benchmark.model.v2.TensorMatrix;
import io.github.leogan.kiln.Kiln;
import io.github.leogan.kiln.NumericPool;
import io.github.leogan.kiln.Schema;
import io.github.leogan.kiln.Wire;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * gld-kiln 0.2.0 — positional little-endian structs. Schema is built once in {@link #prepare}.
 * The timed path is {@link Kiln#encodeTo} and {@link Kiln#decode} with a {@link NumericPool}.
 * Domain maps are built in prepare. {@code tensor_view} decode borrows the encoded bytes.
 *
 * <p>{@code tensor_view} decode returns a slice of the encoded buffer and does not copy the
 * float32 payload. Fidelity compares raw float32 bits, including negative zero and NaN.
 *
 * @see <a href="https://leo-gan.github.io/gld-kiln/spec/">Kiln wire v2</a>
 */
public final class KilnSer implements BenchSerializer {
  private static final Schema MESSAGE =
      Schema.struct(
          "Message",
          Schema.field("f_bool", Schema.BOOL),
          Schema.field("f_int32", Schema.I32),
          Schema.field("f_int64", Schema.I64),
          Schema.field("f_float64", Schema.F64),
          Schema.field("f_string", Schema.STR),
          Schema.field("f_bool_2", Schema.BOOL),
          Schema.field("f_int32_2", Schema.I32),
          Schema.field("f_string_2", Schema.STR));

  private static final Schema DOCUMENT_META =
      Schema.struct(
          "DocumentMeta", Schema.field("region", Schema.STR), Schema.field("version", Schema.I32));

  private static final Schema DOCUMENT_ITEM =
      Schema.struct(
          "DocumentItem",
          Schema.field("sku", Schema.STR),
          Schema.field("qty", Schema.I32),
          Schema.field("price_minor", Schema.I64));

  private static final Schema DOCUMENT =
      Schema.struct(
          "Document",
          Schema.field("id", Schema.STR),
          Schema.field("status", Schema.I32),
          Schema.field("meta", DOCUMENT_META),
          Schema.field("items", Schema.list(DOCUMENT_ITEM)));

  private static final Schema TELEMETRY =
      Schema.struct(
          "Telemetry",
          Schema.field("source", Schema.STR),
          Schema.field("ts", Schema.I64),
          Schema.field("tags", Schema.list(Schema.STR)),
          Schema.field("values", Schema.list(Schema.F64)));

  private static final Schema STRINGS =
      Schema.struct("Strings", Schema.field("items", Schema.list(Schema.STR)));

  private static final Schema EVENT_ATTR =
      Schema.struct(
          "EventAttr", Schema.field("key", Schema.STR), Schema.field("value", Schema.STR));

  private static final Schema EVENT =
      Schema.struct(
          "Event",
          Schema.field("event_id", Schema.STR),
          Schema.field("event_type", Schema.STR),
          Schema.field("occurred_at", Schema.I64),
          Schema.field("producer", Schema.STR),
          Schema.field("attrs", Schema.list(EVENT_ATTR)));

  private static final Schema TENSOR =
      Schema.struct(
          "Tensor",
          Schema.field("rows", Schema.I32),
          Schema.field("cols", Schema.I32),
          Schema.field("values", Schema.list(Schema.F32)));

  private static final Schema PROMPT =
      Schema.struct(
          "Prompt",
          Schema.field("batch", Schema.I32),
          Schema.field("seq", Schema.I32),
          Schema.field("input_ids", Schema.list(Schema.I64)),
          Schema.field("attention_mask", Schema.list(Schema.I64)),
          Schema.field("position_ids", Schema.list(Schema.I64)));

  private static final Schema SHARD =
      Schema.struct(
          "Shard",
          Schema.field("vocab", Schema.I32),
          Schema.field("hidden", Schema.I32),
          Schema.field("ffn", Schema.I32),
          Schema.field("tok_emb", Schema.list(Schema.F32)),
          Schema.field("attn", Schema.list(Schema.F32)),
          Schema.field("ffn_weight", Schema.list(Schema.F32)),
          Schema.field("norm", Schema.list(Schema.F32)));

  private static final Schema REQUEST =
      Schema.struct(
          "Request",
          Schema.field("request_id", Schema.I64),
          Schema.field("model", Schema.STR),
          Schema.field("temperature", Schema.F32),
          Schema.field("inputs", PROMPT));

  private static final Map<String, Schema> SCHEMAS =
      Map.of(
          "message", MESSAGE,
          "document", DOCUMENT,
          "telemetry", TELEMETRY,
          "strings", STRINGS,
          "event", EVENT,
          "tensor", TENSOR,
          "tensor_view", TENSOR,
          "prompt", PROMPT,
          "shard", SHARD,
          "request", REQUEST);

  private Schema schema;
  private Object prepared;
  private String typeId;
  private boolean batch;
  private boolean directSuite;
  /** tensor_view at N=1 borrows the encoded f32 bytes instead of copying them. */
  private boolean borrow;
  private byte[] buf = new byte[256];
  private final Wire.Out out = new Wire.Out(4096);
  private final NumericPool pool = new NumericPool();
  private final Kiln.Options pooled = Kiln.Options.defaults().withPool(pool);

  @Override
  public String name() {
    return "gld-kiln";
  }

  @Override
  public String version() {
    return Versions.of(Kiln.class);
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public String nativeKind() {
    return "dict";
  }

  @Override
  public boolean supports(String testDataName) {
    return SCHEMAS.containsKey(testDataName);
  }

  private static boolean isSuiteType(String name) {
    return "message".equals(name)
        || "document".equals(name)
        || "telemetry".equals(name)
        || "strings".equals(name)
        || "event".equals(name);
  }

  @Override
  public void prepare(Fixture fx) {
    Schema base = SCHEMAS.get(fx.name);
    if (base == null) {
      throw new IllegalArgumentException(fx.name);
    }
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    borrow = "tensor_view".equals(typeId) && !batch;
    directSuite = isSuiteType(typeId);
    schema = batch ? Schema.list(base) : base;
    if (directSuite) {
      prepared = fx.value;
      out.reset();
      writeDirectSuite(out, typeId, batch, prepared);
      return;
    }
    prepared = toKiln(fx.name, fx.value);
    fitBuffer();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    if (directSuite) {
      out.reset();
      writeDirectSuite(out, typeId, batch, prepared);
      return out.finish();
    }
    int end = Kiln.encodeTo(schema, prepared, buf, 0);
    if (end == buf.length) {
      return buf;
    }
    return Arrays.copyOf(buf, end);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    if (directSuite) {
      Wire.In in = Wire.In.of(data);
      Object res = readDirectSuite(in, typeId, batch);
      in.finish();
      return res;
    }
    if (borrow) {
      return borrowTensor(data);
    }
    return Kiln.decode(schema, data, pooled);
  }

  @Override
  public Object toDomain(Object decoded) {
    if (directSuite || borrow) {
      return decoded;
    }
    if (batch) {
      List<?> list = (List<?>) decoded;
      List<Object> outList = new ArrayList<>(list.size());
      for (Object item : list) {
        outList.add(one(typeId, item));
      }
      return outList;
    }
    return one(typeId, decoded);
  }

  @SuppressWarnings("unchecked")
  private static void writeDirectSuite(Wire.Out w, String typeId, boolean batch, Object value) {
    if (batch) {
      List<?> list = (List<?>) value;
      int n = list.size();
      w.count(n);
      switch (typeId) {
        case "message" -> {
          for (int i = 0; i < n; i++) writeMessage(w, (Message) list.get(i));
        }
        case "document" -> {
          for (int i = 0; i < n; i++) writeDocument(w, (Document) list.get(i));
        }
        case "telemetry" -> {
          for (int i = 0; i < n; i++) writeTelemetry(w, (Telemetry) list.get(i));
        }
        case "strings" -> {
          for (int i = 0; i < n; i++) writeStrings(w, (Strings) list.get(i));
        }
        case "event" -> {
          for (int i = 0; i < n; i++) writeEvent(w, (Event) list.get(i));
        }
        default -> throw new IllegalArgumentException(typeId);
      }
      return;
    }
    switch (typeId) {
      case "message" -> writeMessage(w, (Message) value);
      case "document" -> writeDocument(w, (Document) value);
      case "telemetry" -> writeTelemetry(w, (Telemetry) value);
      case "strings" -> writeStrings(w, (Strings) value);
      case "event" -> writeEvent(w, (Event) value);
      default -> throw new IllegalArgumentException(typeId);
    }
  }

  private static void writeMessage(Wire.Out w, Message m) {
    w.bool(m.fBool);
    w.i32(m.fInt32);
    w.i64(m.fInt64);
    w.f64(m.fFloat64);
    w.str(m.fString);
    w.bool(m.fBool2);
    w.i32(m.fInt32_2);
    w.str(m.fString2);
  }

  private static void writeDocument(Wire.Out w, Document d) {
    w.str(d.id);
    w.i32(d.status);
    w.str(d.meta.region);
    w.i32(d.meta.version);
    List<Document.DocumentItem> items = d.items;
    int n = items == null ? 0 : items.size();
    w.count(n);
    for (int i = 0; i < n; i++) {
      Document.DocumentItem it = items.get(i);
      w.str(it.sku);
      w.i32(it.qty);
      w.i64(it.priceMinor);
    }
  }

  private static void writeTelemetry(Wire.Out w, Telemetry t) {
    w.str(t.source);
    w.i64(t.ts);
    List<String> tags = t.tags;
    int nt = tags == null ? 0 : tags.size();
    w.count(nt);
    for (int i = 0; i < nt; i++) {
      w.str(tags.get(i));
    }
    w.f64s(t.values);
  }

  private static void writeStrings(Wire.Out w, Strings s) {
    List<String> items = s.items;
    int n = items == null ? 0 : items.size();
    w.count(n);
    for (int i = 0; i < n; i++) {
      w.str(items.get(i));
    }
  }

  private static void writeEvent(Wire.Out w, Event e) {
    w.str(e.eventId);
    w.str(e.eventType);
    w.i64(e.occurredAt);
    w.str(e.producer);
    List<Event.EventAttr> attrs = e.attrs;
    int n = attrs == null ? 0 : attrs.size();
    w.count(n);
    for (int i = 0; i < n; i++) {
      Event.EventAttr a = attrs.get(i);
      w.str(a.key);
      w.str(a.value);
    }
  }

  private static Object readDirectSuite(Wire.In in, String typeId, boolean batch) {
    if (batch) {
      return switch (typeId) {
        case "message" -> {
          int n = in.count(34);
          List<Message> list = new ArrayList<>(n);
          for (int i = 0; i < n; i++) list.add(readMessage(in));
          yield list;
        }
        case "document" -> {
          int n = in.count(20);
          List<Document> list = new ArrayList<>(n);
          for (int i = 0; i < n; i++) list.add(readDocument(in));
          yield list;
        }
        case "telemetry" -> {
          int n = in.count(20);
          List<Telemetry> list = new ArrayList<>(n);
          for (int i = 0; i < n; i++) list.add(readTelemetry(in));
          yield list;
        }
        case "strings" -> {
          int n = in.count(4);
          List<Strings> list = new ArrayList<>(n);
          for (int i = 0; i < n; i++) list.add(readStrings(in));
          yield list;
        }
        case "event" -> {
          int n = in.count(24);
          List<Event> list = new ArrayList<>(n);
          for (int i = 0; i < n; i++) list.add(readEvent(in));
          yield list;
        }
        default -> throw new IllegalArgumentException(typeId);
      };
    }
    return switch (typeId) {
      case "message" -> readMessage(in);
      case "document" -> readDocument(in);
      case "telemetry" -> readTelemetry(in);
      case "strings" -> readStrings(in);
      case "event" -> readEvent(in);
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static Message readMessage(Wire.In in) {
    return new Message(
        in.bool(), in.i32(), in.i64(), in.f64(), in.str(), in.bool(), in.i32(), in.str());
  }

  private static Document readDocument(Wire.In in) {
    String id = in.str();
    int status = in.i32();
    Document.DocumentMeta meta = new Document.DocumentMeta(in.str(), in.i32());
    int n = in.count(16);
    List<Document.DocumentItem> items = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      items.add(new Document.DocumentItem(in.str(), in.i32(), in.i64()));
    }
    return new Document(id, status, meta, items);
  }

  private static Telemetry readTelemetry(Wire.In in) {
    String source = in.str();
    long ts = in.i64();
    int nt = in.count(4);
    List<String> tags = new ArrayList<>(nt);
    for (int i = 0; i < nt; i++) {
      tags.add(in.str());
    }
    double[] values = Wire.readF64s(in, null);
    return new Telemetry(source, ts, tags, values);
  }

  private static Strings readStrings(Wire.In in) {
    int n = in.count(4);
    List<String> items = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      items.add(in.str());
    }
    return new Strings(items);
  }

  private static Event readEvent(Wire.In in) {
    String id = in.str();
    String type = in.str();
    long occurredAt = in.i64();
    String producer = in.str();
    int n = in.count(8);
    List<Event.EventAttr> attrs = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      attrs.add(new Event.EventAttr(in.str(), in.str()));
    }
    return new Event(id, type, occurredAt, producer, attrs);
  }

  private void fitBuffer() {
    while (true) {
      try {
        int end = Kiln.encodeTo(schema, prepared, buf, 0);
        if (end != buf.length) {
          buf = Arrays.copyOf(buf, end);
        }
        return;
      } catch (IllegalArgumentException ex) {
        if (ex.getMessage() == null || !ex.getMessage().contains("short buffer")) {
          throw ex;
        }
        buf = new byte[buf.length * 2];
      }
    }
  }

  private static Object toKiln(String typeId, Object value) {
    if (value instanceof List<?> list) {
      List<Object> out = new ArrayList<>(list.size());
      for (Object item : list) {
        out.add(oneKiln(typeId, item));
      }
      return out;
    }
    return oneKiln(typeId, value);
  }

  private static Object oneKiln(String typeId, Object value) {
    return switch (typeId) {
      case "message" -> {
        Message m = (Message) value;
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("f_bool", m.fBool);
        map.put("f_int32", m.fInt32);
        map.put("f_int64", m.fInt64);
        map.put("f_float64", m.fFloat64);
        map.put("f_string", m.fString);
        map.put("f_bool_2", m.fBool2);
        map.put("f_int32_2", m.fInt32_2);
        map.put("f_string_2", m.fString2);
        yield map;
      }
      case "document" -> {
        Document d = (Document) value;
        List<Map<String, Object>> items = new ArrayList<>();
        if (d.items != null) {
          for (Document.DocumentItem it : d.items) {
            LinkedHashMap<String, Object> row = new LinkedHashMap<>();
            row.put("sku", it.sku);
            row.put("qty", it.qty);
            row.put("price_minor", it.priceMinor);
            items.add(row);
          }
        }
        LinkedHashMap<String, Object> meta = new LinkedHashMap<>();
        meta.put("region", d.meta.region);
        meta.put("version", d.meta.version);
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("id", d.id);
        map.put("status", d.status);
        map.put("meta", meta);
        map.put("items", items);
        yield map;
      }
      case "telemetry" -> {
        Telemetry t = (Telemetry) value;
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("source", t.source);
        map.put("ts", t.ts);
        map.put("tags", t.tags);
        map.put("values", t.values);
        yield map;
      }
      case "strings" -> {
        Strings s = (Strings) value;
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("items", s.items);
        yield map;
      }
      case "event" -> {
        Event e = (Event) value;
        List<Map<String, Object>> attrs = new ArrayList<>();
        if (e.attrs != null) {
          for (Event.EventAttr a : e.attrs) {
            LinkedHashMap<String, Object> row = new LinkedHashMap<>();
            row.put("key", a.key);
            row.put("value", a.value);
            attrs.add(row);
          }
        }
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("event_id", e.eventId);
        map.put("event_type", e.eventType);
        map.put("occurred_at", e.occurredAt);
        map.put("producer", e.producer);
        map.put("attrs", attrs);
        yield map;
      }
      case "tensor", "tensor_view" -> {
        TensorMatrix t = (TensorMatrix) value;
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("rows", t.rows);
        map.put("cols", t.cols);
        map.put("values", t.values);
        yield map;
      }
      case "prompt" -> promptMap((Prompt) value);
      case "shard" -> {
        Shard s = (Shard) value;
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("vocab", s.vocab);
        map.put("hidden", s.hidden);
        map.put("ffn", s.ffn);
        map.put("tok_emb", s.tokEmb);
        map.put("attn", s.attn);
        map.put("ffn_weight", s.ffnWeight);
        map.put("norm", s.norm);
        yield map;
      }
      case "request" -> {
        Request q = (Request) value;
        LinkedHashMap<String, Object> map = new LinkedHashMap<>();
        map.put("request_id", q.requestId);
        map.put("model", q.model);
        map.put("temperature", q.temperature);
        map.put("inputs", promptMap(q.inputs));
        yield map;
      }
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  @SuppressWarnings("unchecked")
  private static Object one(String typeId, Object value) {
    Map<String, Object> map = (Map<String, Object>) value;
    return switch (typeId) {
      case "message" ->
          new Message(
              bool(map.get("f_bool")),
              i32(map.get("f_int32")),
              i64(map.get("f_int64")),
              f64(map.get("f_float64")),
              str(map.get("f_string")),
              bool(map.get("f_bool_2")),
              i32(map.get("f_int32_2")),
              str(map.get("f_string_2")));
      case "document" -> {
        Map<String, Object> meta = (Map<String, Object>) map.get("meta");
        List<Map<String, Object>> rawItems = (List<Map<String, Object>>) map.get("items");
        List<Document.DocumentItem> items = new ArrayList<>(rawItems.size());
        for (Map<String, Object> row : rawItems) {
          items.add(
              new Document.DocumentItem(str(row.get("sku")), i32(row.get("qty")), i64(row.get("price_minor"))));
        }
        yield new Document(
            str(map.get("id")),
            i32(map.get("status")),
            new Document.DocumentMeta(str(meta.get("region")), i32(meta.get("version"))),
            items);
      }
      case "telemetry" ->
          new Telemetry(
              str(map.get("source")),
              i64(map.get("ts")),
              (List<String>) map.get("tags"),
              (double[]) map.get("values"));
      case "strings" -> new Strings((List<String>) map.get("items"));
      case "event" -> {
        List<Map<String, Object>> raw = (List<Map<String, Object>>) map.get("attrs");
        List<Event.EventAttr> attrs = new ArrayList<>(raw.size());
        for (Map<String, Object> row : raw) {
          attrs.add(new Event.EventAttr(str(row.get("key")), str(row.get("value"))));
        }
        yield new Event(
            str(map.get("event_id")),
            str(map.get("event_type")),
            i64(map.get("occurred_at")),
            str(map.get("producer")),
            attrs);
      }
      case "tensor", "tensor_view" ->
          new TensorMatrix(i32(map.get("rows")), i32(map.get("cols")), f32s(map.get("values")));
      case "prompt" -> promptFrom(map);
      case "shard" ->
          new Shard(
              i32(map.get("vocab")),
              i32(map.get("hidden")),
              i32(map.get("ffn")),
              f32s(map.get("tok_emb")),
              f32s(map.get("attn")),
              f32s(map.get("ffn_weight")),
              f32s(map.get("norm")));
      case "request" ->
          new Request(
              i64(map.get("request_id")),
              str(map.get("model")),
              f32(map.get("temperature")),
              promptFrom(map.get("inputs")));
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  /** Header plus a view of the f32 payload. Does not allocate the matrix. */
  private static TensorMatrix.View borrowTensor(byte[] data) {
    if (data == null || data.length < 12) {
      throw new IllegalArgumentException("tensor_view");
    }
    int rows = Wire.getI32(data, 0);
    int cols = Wire.getI32(data, 4);
    int count = Wire.getI32(data, 8);
    long body = (long) count * 4L;
    if (count < 0 || 12L + body != data.length) {
      throw new IllegalArgumentException("tensor_view length");
    }
    return new TensorMatrix.View(rows, cols, data, 12, (int) body);
  }

  private static LinkedHashMap<String, Object> promptMap(Prompt p) {
    LinkedHashMap<String, Object> map = new LinkedHashMap<>();
    map.put("batch", p.batch);
    map.put("seq", p.seq);
    map.put("input_ids", p.inputIds);
    map.put("attention_mask", p.attentionMask);
    map.put("position_ids", p.positionIds);
    return map;
  }

  @SuppressWarnings("unchecked")
  private static Prompt promptFrom(Object value) {
    Map<String, Object> map = (Map<String, Object>) value;
    return new Prompt(
        i32(map.get("batch")),
        i32(map.get("seq")),
        (long[]) map.get("input_ids"),
        (long[]) map.get("attention_mask"),
        (long[]) map.get("position_ids"));
  }

  private static boolean bool(Object v) {
    return (Boolean) v;
  }

  private static int i32(Object v) {
    return ((Number) v).intValue();
  }

  private static long i64(Object v) {
    return ((Number) v).longValue();
  }

  private static double f64(Object v) {
    return ((Number) v).doubleValue();
  }

  private static float f32(Object v) {
    return ((Number) v).floatValue();
  }

  private static float[] f32s(Object v) {
    return (float[]) v;
  }

  private static String str(Object v) {
    return (String) v;
  }
}
