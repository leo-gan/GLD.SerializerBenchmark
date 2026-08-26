package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.Strings;
import benchmark.model.v2.Telemetry;
import benchmark.v2.BatchDocument;
import benchmark.v2.BatchEvent;
import benchmark.v2.BatchMessage;
import benchmark.v2.BatchStrings;
import benchmark.v2.BatchTelemetry;
import benchmark.v2.DocumentItem;
import benchmark.v2.DocumentMeta;
import benchmark.v2.EventAttr;
import com.google.protobuf.MessageLite;
import com.google.protobuf.Parser;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;

/**
 * Protocol Buffers (protobuf-java) — official Google runtime.
 *
 * <p>401 pair with Protostuff: both time suite value → bytes → suite value. {@code prepare}
 * only binds the parser. Timed serialize is {@code toProto}+{@code toByteArray}; timed
 * deserialize is {@code parseFrom}+{@code fromProto}. {@link #toDomain} is identity.
 *
 * @see <a href="https://protobuf.dev/getting-started/javatutorial/">Protobuf Java tutorial</a>
 */
public final class ProtobufSer implements BenchSerializer {
  private MessageLite prepared;
  private Parser<? extends MessageLite> parser;
  private String typeId;
  private boolean batch;

  @Override
  public String name() {
    return "protobuf";
  }

  @Override
  public String version() {
    return Versions.of(MessageLite.class);
  }

  @Override
  public String streamMode() {
    return "native";
  }

  @Override
  public String nativeKind() {
    return "message";
  }

  @Override
  public void prepare(Fixture fx) throws Exception {
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    prepared = toProto(fx);
    parser = prepared.getParserForType();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    return toProto(fx).toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    return fromProto(typeId, batch, parser.parseFrom(data));
  }

  @Override
  public int serializeStream(Fixture fx, OutputStream out) throws Exception {
    MessageLite msg = toProto(fx);
    msg.writeTo(out);
    return msg.getSerializedSize();
  }

  @Override
  public Object deserializeStream(InputStream in) throws Exception {
    return fromProto(typeId, batch, parser.parseFrom(in));
  }

  @Override
  public Object toDomain(Object decoded) {
    return decoded;
  }

  private static MessageLite toProto(Fixture fx) {
    if (fx.value instanceof List<?> list) {
      return switch (fx.name) {
        case "message" -> {
          BatchMessage.Builder b = BatchMessage.newBuilder();
          for (Object o : list) b.addItems(toMessage((Message) o));
          yield b.build();
        }
        case "document" -> {
          BatchDocument.Builder b = BatchDocument.newBuilder();
          for (Object o : list) b.addItems(toDocument((Document) o));
          yield b.build();
        }
        case "telemetry" -> {
          BatchTelemetry.Builder b = BatchTelemetry.newBuilder();
          for (Object o : list) b.addItems(toTelemetry((Telemetry) o));
          yield b.build();
        }
        case "strings" -> {
          BatchStrings.Builder b = BatchStrings.newBuilder();
          for (Object o : list) b.addItems(toStrings((Strings) o));
          yield b.build();
        }
        case "event" -> {
          BatchEvent.Builder b = BatchEvent.newBuilder();
          for (Object o : list) b.addItems(toEvent((Event) o));
          yield b.build();
        }
        default -> throw new IllegalArgumentException(fx.name);
      };
    }
    return switch (fx.name) {
      case "message" -> toMessage((Message) fx.value);
      case "document" -> toDocument((Document) fx.value);
      case "telemetry" -> toTelemetry((Telemetry) fx.value);
      case "strings" -> toStrings((Strings) fx.value);
      case "event" -> toEvent((Event) fx.value);
      default -> throw new IllegalArgumentException(fx.name);
    };
  }

  private static Object fromProto(String typeId, boolean batch, MessageLite ml) {
    if (batch) {
      return switch (typeId) {
        case "message" -> {
          List<Message> out = new ArrayList<>();
          for (benchmark.v2.Message m : ((BatchMessage) ml).getItemsList()) out.add(fromMessage(m));
          yield out;
        }
        case "document" -> {
          List<Document> out = new ArrayList<>();
          for (benchmark.v2.Document d : ((BatchDocument) ml).getItemsList())
            out.add(fromDocument(d));
          yield out;
        }
        case "telemetry" -> {
          List<Telemetry> out = new ArrayList<>();
          for (benchmark.v2.Telemetry t : ((BatchTelemetry) ml).getItemsList())
            out.add(fromTelemetry(t));
          yield out;
        }
        case "strings" -> {
          List<Strings> out = new ArrayList<>();
          for (benchmark.v2.Strings s : ((BatchStrings) ml).getItemsList()) out.add(fromStrings(s));
          yield out;
        }
        case "event" -> {
          List<Event> out = new ArrayList<>();
          for (benchmark.v2.Event e : ((BatchEvent) ml).getItemsList()) out.add(fromEvent(e));
          yield out;
        }
        default -> ml;
      };
    }
    return switch (typeId) {
      case "message" -> fromMessage((benchmark.v2.Message) ml);
      case "document" -> fromDocument((benchmark.v2.Document) ml);
      case "telemetry" -> fromTelemetry((benchmark.v2.Telemetry) ml);
      case "strings" -> fromStrings((benchmark.v2.Strings) ml);
      case "event" -> fromEvent((benchmark.v2.Event) ml);
      default -> ml;
    };
  }

  private static benchmark.v2.Message toMessage(Message m) {
    return benchmark.v2.Message.newBuilder()
        .setFBool(m.fBool)
        .setFInt32(m.fInt32)
        .setFInt64(m.fInt64)
        .setFFloat64(m.fFloat64)
        .setFString(nullToEmpty(m.fString))
        .setFBool2(m.fBool2)
        .setFInt322(m.fInt32_2)
        .setFString2(nullToEmpty(m.fString2))
        .build();
  }

  private static Message fromMessage(benchmark.v2.Message m) {
    return new Message(
        m.getFBool(),
        m.getFInt32(),
        m.getFInt64(),
        m.getFFloat64(),
        m.getFString(),
        m.getFBool2(),
        m.getFInt322(),
        m.getFString2());
  }

  private static benchmark.v2.Document toDocument(Document d) {
    benchmark.v2.Document.Builder b =
        benchmark.v2.Document.newBuilder()
            .setId(nullToEmpty(d.id))
            .setStatus(d.status);
    if (d.meta != null) {
      b.setMeta(
          DocumentMeta.newBuilder()
              .setRegion(nullToEmpty(d.meta.region))
              .setVersion(d.meta.version)
              .build());
    }
    if (d.items != null) {
      for (Document.DocumentItem it : d.items) {
        b.addItems(
            DocumentItem.newBuilder()
                .setSku(nullToEmpty(it.sku))
                .setQty(it.qty)
                .setPriceMinor(it.priceMinor)
                .build());
      }
    }
    return b.build();
  }

  private static Document fromDocument(benchmark.v2.Document d) {
    Document.DocumentMeta meta =
        d.hasMeta()
            ? new Document.DocumentMeta(d.getMeta().getRegion(), d.getMeta().getVersion())
            : new Document.DocumentMeta("", 0);
    List<Document.DocumentItem> items = new ArrayList<>();
    for (DocumentItem it : d.getItemsList()) {
      items.add(new Document.DocumentItem(it.getSku(), it.getQty(), it.getPriceMinor()));
    }
    return new Document(d.getId(), d.getStatus(), meta, items);
  }

  private static benchmark.v2.Telemetry toTelemetry(Telemetry t) {
    benchmark.v2.Telemetry.Builder b =
        benchmark.v2.Telemetry.newBuilder()
            .setSource(nullToEmpty(t.source))
            .setTs(t.ts);
    if (t.tags != null) b.addAllTags(t.tags);
    if (t.values != null) {
      for (double v : t.values) b.addValues(v);
    }
    return b.build();
  }

  private static Telemetry fromTelemetry(benchmark.v2.Telemetry t) {
    double[] vals = new double[t.getValuesCount()];
    for (int i = 0; i < vals.length; i++) vals[i] = t.getValues(i);
    return new Telemetry(t.getSource(), t.getTs(), new ArrayList<>(t.getTagsList()), vals);
  }

  private static benchmark.v2.Strings toStrings(Strings s) {
    benchmark.v2.Strings.Builder b = benchmark.v2.Strings.newBuilder();
    if (s.items != null) b.addAllItems(s.items);
    return b.build();
  }

  private static Strings fromStrings(benchmark.v2.Strings s) {
    return new Strings(new ArrayList<>(s.getItemsList()));
  }

  private static benchmark.v2.Event toEvent(Event e) {
    benchmark.v2.Event.Builder b =
        benchmark.v2.Event.newBuilder()
            .setEventId(nullToEmpty(e.eventId))
            .setEventType(nullToEmpty(e.eventType))
            .setOccurredAt(e.occurredAt)
            .setProducer(nullToEmpty(e.producer));
    if (e.attrs != null) {
      for (Event.EventAttr a : e.attrs) {
        b.addAttrs(
            EventAttr.newBuilder()
                .setKey(nullToEmpty(a.key))
                .setValue(nullToEmpty(a.value))
                .build());
      }
    }
    return b.build();
  }

  private static Event fromEvent(benchmark.v2.Event e) {
    List<Event.EventAttr> attrs = new ArrayList<>();
    for (EventAttr a : e.getAttrsList()) {
      attrs.add(new Event.EventAttr(a.getKey(), a.getValue()));
    }
    return new Event(e.getEventId(), e.getEventType(), e.getOccurredAt(), e.getProducer(), attrs);
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}
