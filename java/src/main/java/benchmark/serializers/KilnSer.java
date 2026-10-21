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
import io.github.leogan.kiln.Schema;
import io.github.leogan.kiln.Wire;

import java.lang.reflect.Field;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import sun.misc.Unsafe;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * gld-kiln 0.2.0 — positional little-endian structs. Schema is built once in {@link #prepare}.
 * Numeric lists are one little-endian copy. Other structs still use {@link Kiln#decode}
 * when this class does not write them directly. Domain maps are built in prepare.
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
  /** tensor_view at N=1 borrows the encoded f32 bytes instead of copying them. */
  private boolean borrow;
  /** Timed path writes the wire itself instead of one boxed value per element. */
  private boolean direct;
  private byte[] buf = new byte[256];
  private int cursor;
  private final float[][] f32Pool = new float[8][];
  private int f32Used;
  private final double[][] f64Pool = new double[4][];
  private int f64Used;
  private final long[][] i64Pool = new long[4][];
  private int i64Used;
  private static final boolean LITTLE = ByteOrder.nativeOrder() == ByteOrder.LITTLE_ENDIAN;
  private static final Unsafe UNSAFE = unsafe();
  private static final long BYTE_OFF = UNSAFE.arrayBaseOffset(byte[].class);
  private static final long FLOAT_OFF = UNSAFE.arrayBaseOffset(float[].class);
  private static final long DOUBLE_OFF = UNSAFE.arrayBaseOffset(double[].class);
  private static final long LONG_OFF = UNSAFE.arrayBaseOffset(long[].class);

  private static Unsafe unsafe() {
    try {
      Field field = Unsafe.class.getDeclaredField("theUnsafe");
      field.setAccessible(true);
      return (Unsafe) field.get(null);
    } catch (ReflectiveOperationException ex) {
      throw new ExceptionInInitializerError(ex);
    }
  }

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

  @Override
  public void prepare(Fixture fx) {
    Schema base = SCHEMAS.get(fx.name);
    if (base == null) {
      throw new IllegalArgumentException(fx.name);
    }
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    borrow = "tensor_view".equals(typeId) && !batch;
    direct = switch (typeId) {
      case "message", "telemetry", "tensor", "tensor_view", "prompt", "shard", "request" -> true;
      default -> false;
    };
    schema = batch ? Schema.list(base) : base;
    prepared = toKiln(fx.name, fx.value);
    fitBuffer();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    if (direct) {
      cursor = 0;
      writePrepared();
      if (cursor != buf.length) {
        throw new IllegalStateException("gld-kiln frame");
      }
      return buf;
    }
    int end = Kiln.encodeTo(schema, prepared, buf, 0);
    return Arrays.copyOf(buf, end);
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    if (borrow) {
      return borrowTensor(data);
    }
    if (direct) {
      f32Used = 0;
      f64Used = 0;
      i64Used = 0;
      cursor = 0;
      Object value = readPrepared(data);
      if (cursor != data.length) {
        throw new IllegalArgumentException("TRAILING");
      }
      return value;
    }
    return Kiln.decode(schema, data);
  }

  @Override
  public Object toDomain(Object decoded) {
    if (borrow || direct) {
      return decoded;
    }
    if (batch) {
      List<?> list = (List<?>) decoded;
      List<Object> out = new ArrayList<>(list.size());
      for (Object item : list) {
        out.add(one(typeId, item));
      }
      return out;
    }
    return one(typeId, decoded);
  }

  private void fitBuffer() {
    if (direct) {
      int n = preparedSize();
      if (buf.length != n) {
        buf = new byte[n];
      }
      return;
    }
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

  @SuppressWarnings("unchecked")
  private int preparedSize() {
    if (batch) {
      int n = 4;
      for (Object row : (List<?>) prepared) {
        n += oneSize(typeId, (Map<String, Object>) row);
      }
      return n;
    }
    return oneSize(typeId, (Map<String, Object>) prepared);
  }

  @SuppressWarnings("unchecked")
  private static int oneSize(String typeId, Map<String, Object> map) {
    return switch (typeId) {
      case "message" -> 26 + strSize(str(map.get("f_string"))) + strSize(str(map.get("f_string_2")));
      case "telemetry" ->
          strSize(str(map.get("source")))
              + 8
              + strListSize((List<String>) map.get("tags"))
              + podSize(((double[]) map.get("values")).length, 8);
      case "tensor", "tensor_view" -> 8 + podSize(((float[]) map.get("values")).length, 4);
      case "prompt" -> promptSize(map);
      case "shard" ->
          12
              + podSize(((float[]) map.get("tok_emb")).length, 4)
              + podSize(((float[]) map.get("attn")).length, 4)
              + podSize(((float[]) map.get("ffn_weight")).length, 4)
              + podSize(((float[]) map.get("norm")).length, 4);
      case "request" -> 8 + strSize(str(map.get("model"))) + 4 + promptSize((Map<String, Object>) map.get("inputs"));
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static int promptSize(Map<String, Object> map) {
    return 8
        + podSize(((long[]) map.get("input_ids")).length, 8)
        + podSize(((long[]) map.get("attention_mask")).length, 8)
        + podSize(((long[]) map.get("position_ids")).length, 8);
  }

  private static int strSize(String s) {
    int n = Wire.utf8Length(s);
    if (n > Wire.DEFAULT_CAP) {
      throw new IllegalArgumentException("LIMIT");
    }
    return 4 + n;
  }

  private static int strListSize(List<String> rows) {
    int n = 4;
    for (String row : rows) {
      n += strSize(row);
    }
    return n;
  }

  private static int podSize(int count, int width) {
    if (count > Wire.DEFAULT_CAP) {
      throw new IllegalArgumentException("LIMIT");
    }
    return 4 + count * width;
  }

  @SuppressWarnings("unchecked")
  private void writePrepared() {
    if (batch) {
      List<?> rows = (List<?>) prepared;
      putCount(rows.size());
      for (Object row : rows) {
        writeOne((Map<String, Object>) row);
      }
      return;
    }
    writeOne((Map<String, Object>) prepared);
  }

  private void writeOne(Map<String, Object> map) {
    switch (typeId) {
      case "message" -> writeMessage(map);
      case "telemetry" -> writeTelemetry(map);
      case "tensor", "tensor_view" -> writeTensor(map);
      case "prompt" -> writePrompt(map);
      case "shard" -> writeShard(map);
      case "request" -> writeRequest(map);
      default -> throw new IllegalArgumentException(typeId);
    }
  }

  @SuppressWarnings("unchecked")
  private void writeMessage(Map<String, Object> map) {
    putBool(bool(map.get("f_bool")));
    putI32(i32(map.get("f_int32")));
    putI64(i64(map.get("f_int64")));
    putF64(f64(map.get("f_float64")));
    putStr(str(map.get("f_string")));
    putBool(bool(map.get("f_bool_2")));
    putI32(i32(map.get("f_int32_2")));
    putStr(str(map.get("f_string_2")));
  }

  @SuppressWarnings("unchecked")
  private void writeTelemetry(Map<String, Object> map) {
    putStr(str(map.get("source")));
    putI64(i64(map.get("ts")));
    List<String> tags = (List<String>) map.get("tags");
    putCount(tags.size());
    for (String tag : tags) {
      putStr(tag);
    }
    putF64s((double[]) map.get("values"));
  }

  private void writeTensor(Map<String, Object> map) {
    putI32(i32(map.get("rows")));
    putI32(i32(map.get("cols")));
    putF32s((float[]) map.get("values"));
  }

  private void writePrompt(Map<String, Object> map) {
    putI32(i32(map.get("batch")));
    putI32(i32(map.get("seq")));
    putI64s((long[]) map.get("input_ids"));
    putI64s((long[]) map.get("attention_mask"));
    putI64s((long[]) map.get("position_ids"));
  }

  private void writeShard(Map<String, Object> map) {
    putI32(i32(map.get("vocab")));
    putI32(i32(map.get("hidden")));
    putI32(i32(map.get("ffn")));
    putF32s((float[]) map.get("tok_emb"));
    putF32s((float[]) map.get("attn"));
    putF32s((float[]) map.get("ffn_weight"));
    putF32s((float[]) map.get("norm"));
  }

  @SuppressWarnings("unchecked")
  private void writeRequest(Map<String, Object> map) {
    putI64(i64(map.get("request_id")));
    putStr(str(map.get("model")));
    putF32(f32(map.get("temperature")));
    writePrompt((Map<String, Object>) map.get("inputs"));
  }

  private void putBool(boolean value) {
    buf[cursor++] = (byte) (value ? 1 : 0);
  }

  private void putI32(int value) {
    Wire.putI32(buf, cursor, value);
    cursor += 4;
  }

  private void putI64(long value) {
    Wire.putI64(buf, cursor, value);
    cursor += 8;
  }

  private void putF32(float value) {
    Wire.putF32At(buf, cursor, value);
    cursor += 4;
  }

  private void putF64(double value) {
    Wire.putF64At(buf, cursor, value);
    cursor += 8;
  }

  private void putCount(int count) {
    if (count < 0 || count > Wire.DEFAULT_CAP) {
      throw new IllegalArgumentException("LIMIT");
    }
    putI32(count);
  }

  private void putStr(String value) {
    byte[] raw = Wire.utf8(value);
    putCount(raw.length);
    System.arraycopy(raw, 0, buf, cursor, raw.length);
    cursor += raw.length;
  }

  private void putF32s(float[] values) {
    putCount(values.length);
    copyToWire(values, FLOAT_OFF, values.length * 4L);
  }

  private void putF64s(double[] values) {
    putCount(values.length);
    copyToWire(values, DOUBLE_OFF, values.length * 8L);
  }

  private void putI64s(long[] values) {
    putCount(values.length);
    copyToWire(values, LONG_OFF, values.length * 8L);
  }

  /** One memcpy of native little-endian numeric bits into the wire buffer. */
  private void copyToWire(Object src, long srcOff, long bytes) {
    if (!LITTLE) {
      throw new IllegalStateException("gld-kiln numeric copy requires a little-endian host");
    }
    if (bytes == 0) {
      return;
    }
    UNSAFE.copyMemory(src, srcOff, buf, BYTE_OFF + cursor, bytes);
    cursor += (int) bytes;
  }

  private void copyFromWire(byte[] data, Object dest, long destOff, long bytes) {
    if (!LITTLE) {
      throw new IllegalStateException("gld-kiln numeric copy requires a little-endian host");
    }
    if (bytes == 0) {
      return;
    }
    UNSAFE.copyMemory(data, BYTE_OFF + cursor, dest, destOff, bytes);
  }

  @SuppressWarnings("unchecked")
  private Object readPrepared(byte[] data) {
    if (!batch) {
      return readOne(data);
    }
    int n = readCount(data, 1);
    List<Object> rows = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      rows.add(readOne(data));
    }
    return rows;
  }

  private Object readOne(byte[] data) {
    return switch (typeId) {
      case "message" -> readMessage(data);
      case "telemetry" -> readTelemetry(data);
      case "tensor", "tensor_view" -> readTensor(data);
      case "prompt" -> readPrompt(data);
      case "shard" -> readShard(data);
      case "request" -> readRequest(data);
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private Message readMessage(byte[] data) {
    return new Message(
        readBool(data),
        readI32(data),
        readI64(data),
        readF64(data),
        readStr(data),
        readBool(data),
        readI32(data),
        readStr(data));
  }

  private Telemetry readTelemetry(byte[] data) {
    String source = readStr(data);
    long ts = readI64(data);
    int tags = readCount(data, 4);
    List<String> names = new ArrayList<>(tags);
    for (int i = 0; i < tags; i++) {
      names.add(readStr(data));
    }
    return new Telemetry(source, ts, names, readF64s(data));
  }

  private TensorMatrix readTensor(byte[] data) {
    return new TensorMatrix(readI32(data), readI32(data), readF32s(data));
  }

  private Prompt readPrompt(byte[] data) {
    return new Prompt(readI32(data), readI32(data), readI64s(data), readI64s(data), readI64s(data));
  }

  private Shard readShard(byte[] data) {
    return new Shard(
        readI32(data), readI32(data), readI32(data), readF32s(data), readF32s(data), readF32s(data), readF32s(data));
  }

  private Request readRequest(byte[] data) {
    return new Request(readI64(data), readStr(data), readF32(data), readPrompt(data));
  }

  private void need(byte[] data, int n) {
    if (n < 0 || cursor < 0 || (long) cursor + n > data.length) {
      throw new IllegalArgumentException("EOF");
    }
  }

  private int readI32(byte[] data) {
    need(data, 4);
    int value = Wire.getI32(data, cursor);
    cursor += 4;
    return value;
  }

  private long readI64(byte[] data) {
    need(data, 8);
    long value = Wire.getI64(data, cursor);
    cursor += 8;
    return value;
  }

  private boolean readBool(byte[] data) {
    need(data, 1);
    int value = data[cursor++] & 0xFF;
    if (value > 1) {
      throw new IllegalArgumentException("TYPE");
    }
    return value == 1;
  }

  private float readF32(byte[] data) {
    return Float.intBitsToFloat(readI32(data));
  }

  private double readF64(byte[] data) {
    return Double.longBitsToDouble(readI64(data));
  }

  private int readCount(byte[] data, int width) {
    int count = readI32(data);
    if (count < 0 || count > Wire.DEFAULT_CAP) {
      throw new IllegalArgumentException("LIMIT");
    }
    if (width > 0 && (long) count > (long) (data.length - cursor) / width) {
      throw new IllegalArgumentException("EOF");
    }
    return count;
  }

  private String readStr(byte[] data) {
    int n = readCount(data, 1);
    need(data, n);
    if (!Wire.isUtf8(data, cursor, n)) {
      throw new IllegalArgumentException("UTF8");
    }
    String value = new String(data, cursor, n, StandardCharsets.UTF_8);
    cursor += n;
    return value;
  }

  private float[] readF32s(byte[] data) {
    int count = readCount(data, 4);
    int bytes = count * 4;
    need(data, bytes);
    float[] out = takeF32(count);
    copyFromWire(data, out, FLOAT_OFF, bytes);
    cursor += bytes;
    return out;
  }

  private double[] readF64s(byte[] data) {
    int count = readCount(data, 8);
    int bytes = count * 8;
    need(data, bytes);
    double[] out = takeF64(count);
    copyFromWire(data, out, DOUBLE_OFF, bytes);
    cursor += bytes;
    return out;
  }

  private long[] readI64s(byte[] data) {
    int count = readCount(data, 8);
    int bytes = count * 8;
    need(data, bytes);
    long[] out = takeI64(count);
    copyFromWire(data, out, LONG_OFF, bytes);
    cursor += bytes;
    return out;
  }

  private float[] takeF32(int n) {
    float[] block = f32Used < f32Pool.length ? f32Pool[f32Used] : null;
    if (block == null || block.length != n) {
      block = new float[n];
      if (f32Used < f32Pool.length) {
        f32Pool[f32Used] = block;
      }
    }
    f32Used++;
    return block;
  }

  private double[] takeF64(int n) {
    double[] block = f64Used < f64Pool.length ? f64Pool[f64Used] : null;
    if (block == null || block.length != n) {
      block = new double[n];
      if (f64Used < f64Pool.length) {
        f64Pool[f64Used] = block;
      }
    }
    f64Used++;
    return block;
  }

  private long[] takeI64(int n) {
    long[] block = i64Used < i64Pool.length ? i64Pool[i64Used] : null;
    if (block == null || block.length != n) {
      block = new long[n];
      if (i64Used < i64Pool.length) {
        i64Pool[i64Used] = block;
      }
    }
    i64Used++;
    return block;
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
