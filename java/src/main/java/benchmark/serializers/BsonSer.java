package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.Strings;
import benchmark.model.v2.Telemetry;
import org.bson.BsonBinaryReader;
import org.bson.BsonBinaryWriter;
import org.bson.BsonDocument;
import org.bson.codecs.DecoderContext;
import org.bson.codecs.DocumentCodec;
import org.bson.codecs.EncoderContext;
import org.bson.io.BasicOutputBuffer;
import org.bson.io.ByteBufferBsonInput;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

/**
 * MongoDB BSON (org.bson) — document binary format.
 *
 * <p>Recommended: encode domain → {@link org.bson.Document} in prepare (untimed); timed path
 * uses {@link BsonBinaryWriter}/{@link BsonBinaryReader} with {@link DocumentCodec}.
 *
 * @see <a href="https://www.mongodb.com/docs/manual/reference/bson-types/">BSON types</a>
 */
public final class BsonSer implements BenchSerializer {
  private static final DocumentCodec CODEC = new DocumentCodec();
  private final BasicOutputBuffer buffer = new BasicOutputBuffer(4096);
  private org.bson.Document prepared;
  private String typeId;
  private boolean batch;

  @Override
  public String name() {
    return "bson";
  }

  @Override
  public String version() {
    return Versions.of(BsonDocument.class);
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
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    prepared = toBson(fx);
    buffer.truncateToPosition(0);
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    buffer.truncateToPosition(0);
    BsonBinaryWriter writer = new BsonBinaryWriter(buffer);
    try {
      CODEC.encode(writer, prepared, EncoderContext.builder().build());
    } finally {
      writer.close();
    }
    return buffer.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    try (BsonBinaryReader reader =
        new BsonBinaryReader(
            new ByteBufferBsonInput(new org.bson.ByteBufNIO(ByteBuffer.wrap(data))))) {
      org.bson.Document doc = CODEC.decode(reader, DecoderContext.builder().build());
      return fromBson(typeId, batch, doc);
    }
  }

  private static org.bson.Document toBson(Fixture fx) {
    if (fx.value instanceof List<?> list) {
      List<org.bson.Document> items = new ArrayList<>(list.size());
      for (Object o : list) items.add(toDoc(fx.name, o));
      return new org.bson.Document("items", items);
    }
    return toDoc(fx.name, fx.value);
  }

  private static org.bson.Document toDoc(String typeId, Object o) {
    return switch (typeId) {
      case "message" -> {
        Message m = (Message) o;
        yield new org.bson.Document()
            .append("fBool", m.fBool)
            .append("fInt32", m.fInt32)
            .append("fInt64", m.fInt64)
            .append("fFloat64", m.fFloat64)
            .append("fString", m.fString)
            .append("fBool2", m.fBool2)
            .append("fInt32_2", m.fInt32_2)
            .append("fString2", m.fString2);
      }
      case "document" -> {
        Document d = (Document) o;
        List<org.bson.Document> items = new ArrayList<>();
        if (d.items != null) {
          for (Document.DocumentItem it : d.items) {
            items.add(
                new org.bson.Document("sku", it.sku)
                    .append("qty", it.qty)
                    .append("priceMinor", it.priceMinor));
          }
        }
        org.bson.Document meta =
            d.meta == null
                ? new org.bson.Document()
                : new org.bson.Document("region", d.meta.region).append("version", d.meta.version);
        yield new org.bson.Document("id", d.id)
            .append("status", d.status)
            .append("meta", meta)
            .append("items", items);
      }
      case "telemetry" -> {
        Telemetry t = (Telemetry) o;
        List<Double> vals = new ArrayList<>();
        if (t.values != null) for (double v : t.values) vals.add(v);
        yield new org.bson.Document("source", t.source)
            .append("ts", t.ts)
            .append("tags", t.tags)
            .append("values", vals);
      }
      case "strings" -> {
        Strings s = (Strings) o;
        yield new org.bson.Document("items", s.items);
      }
      case "event" -> {
        Event e = (Event) o;
        List<org.bson.Document> attrs = new ArrayList<>();
        if (e.attrs != null) {
          for (Event.EventAttr a : e.attrs) {
            attrs.add(new org.bson.Document("key", a.key).append("value", a.value));
          }
        }
        yield new org.bson.Document("eventId", e.eventId)
            .append("eventType", e.eventType)
            .append("occurredAt", e.occurredAt)
            .append("producer", e.producer)
            .append("attrs", attrs);
      }
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static Object fromBson(String typeId, boolean batch, org.bson.Document doc) {
    if (batch) {
      List<org.bson.Document> items = doc.getList("items", org.bson.Document.class);
      List<Object> out = new ArrayList<>(items.size());
      for (org.bson.Document it : items) out.add(fromDoc(typeId, it));
      return castList(typeId, out);
    }
    return fromDoc(typeId, doc);
  }

  private static Object castList(String typeId, List<Object> out) {
    return switch (typeId) {
      case "message" -> {
        List<Message> l = new ArrayList<>(out.size());
        for (Object o : out) l.add((Message) o);
        yield l;
      }
      case "document" -> {
        List<Document> l = new ArrayList<>(out.size());
        for (Object o : out) l.add((Document) o);
        yield l;
      }
      case "telemetry" -> {
        List<Telemetry> l = new ArrayList<>(out.size());
        for (Object o : out) l.add((Telemetry) o);
        yield l;
      }
      case "strings" -> {
        List<Strings> l = new ArrayList<>(out.size());
        for (Object o : out) l.add((Strings) o);
        yield l;
      }
      case "event" -> {
        List<Event> l = new ArrayList<>(out.size());
        for (Object o : out) l.add((Event) o);
        yield l;
      }
      default -> out;
    };
  }

  private static long longVal(org.bson.Document d, String key) {
    Object v = d.get(key);
    if (v instanceof Number n) return n.longValue();
    return 0L;
  }

  private static int intVal(org.bson.Document d, String key) {
    Object v = d.get(key);
    if (v instanceof Number n) return n.intValue();
    return 0;
  }

  private static double doubleVal(org.bson.Document d, String key) {
    Object v = d.get(key);
    if (v instanceof Number n) return n.doubleValue();
    return 0.0;
  }

  private static Object fromDoc(String typeId, org.bson.Document d) {
    return switch (typeId) {
      case "message" ->
          new Message(
              d.getBoolean("fBool", false),
              intVal(d, "fInt32"),
              longVal(d, "fInt64"),
              doubleVal(d, "fFloat64"),
              d.getString("fString"),
              d.getBoolean("fBool2", false),
              intVal(d, "fInt32_2"),
              d.getString("fString2"));
      case "document" -> {
        org.bson.Document meta = d.get("meta", org.bson.Document.class);
        List<Document.DocumentItem> items = new ArrayList<>();
        List<org.bson.Document> rawItems = d.getList("items", org.bson.Document.class);
        if (rawItems != null) {
          for (org.bson.Document it : rawItems) {
            items.add(
                new Document.DocumentItem(
                    it.getString("sku"), intVal(it, "qty"), longVal(it, "priceMinor")));
          }
        }
        yield new Document(
            d.getString("id"),
            intVal(d, "status"),
            meta == null
                ? new Document.DocumentMeta("", 0)
                : new Document.DocumentMeta(meta.getString("region"), intVal(meta, "version")),
            items);
      }
      case "telemetry" -> {
        List<?> vals = d.getList("values", Object.class);
        double[] arr = new double[vals == null ? 0 : vals.size()];
        if (vals != null) {
          for (int i = 0; i < vals.size(); i++) {
            Object v = vals.get(i);
            arr[i] = v instanceof Number n ? n.doubleValue() : 0;
          }
        }
        List<String> tags = d.getList("tags", String.class);
        yield new Telemetry(
            d.getString("source"),
            longVal(d, "ts"),
            tags == null ? new ArrayList<>() : new ArrayList<>(tags),
            arr);
      }
      case "strings" -> {
        List<String> items = d.getList("items", String.class);
        yield new Strings(items == null ? new ArrayList<>() : new ArrayList<>(items));
      }
      case "event" -> {
        List<Event.EventAttr> attrs = new ArrayList<>();
        List<org.bson.Document> raw = d.getList("attrs", org.bson.Document.class);
        if (raw != null) {
          for (org.bson.Document a : raw) {
            attrs.add(new Event.EventAttr(a.getString("key"), a.getString("value")));
          }
        }
        yield new Event(
            d.getString("eventId"),
            d.getString("eventType"),
            longVal(d, "occurredAt"),
            d.getString("producer"),
            attrs);
      }
      default -> throw new IllegalArgumentException(typeId);
    };
  }
}
