package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Signal;
import benchmark.model.v2.Strings;
import benchmark.model.v2.TableRow;
import benchmark.model.v2.Telemetry;
import benchmark.model.v2.V2Rows;
import benchmark.v2.BatchDocument;
import benchmark.v2.BatchEvent;
import benchmark.v2.BatchMessage;
import benchmark.v2.BatchNestedRow;
import benchmark.v2.BatchSignal;
import benchmark.v2.BatchStrings;
import benchmark.v2.BatchTable;
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
        case "table", "table_project" -> {
          BatchTable.Builder b = BatchTable.newBuilder();
          for (Object o : list) b.addItems(toTable((TableRow) o));
          yield b.build();
        }
        case "nested_table" -> {
          BatchNestedRow.Builder b = BatchNestedRow.newBuilder();
          for (Object o : list) b.addItems(toNested((NestedRow) o));
          yield b.build();
        }
        case "signal" -> {
          BatchSignal.Builder b = BatchSignal.newBuilder();
          for (Object o : list) b.addItems(toSignal((Signal) o));
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
      case "table", "table_project" -> toTable((TableRow) fx.value);
      case "nested_table" -> toNested((NestedRow) fx.value);
      case "signal" -> toSignal((Signal) fx.value);
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
        case "table" -> {
          List<TableRow> out = new ArrayList<>();
          for (benchmark.v2.Table t : ((BatchTable) ml).getItemsList()) out.add(fromTable(t));
          yield out;
        }
        case "table_project" -> {
          List<TableRow> out = new ArrayList<>();
          for (benchmark.v2.Table t : ((BatchTable) ml).getItemsList()) out.add(fromTable(t));
          yield V2Rows.float0(out);
        }
        case "nested_table" -> {
          List<NestedRow> out = new ArrayList<>();
          for (benchmark.v2.NestedRow n : ((BatchNestedRow) ml).getItemsList()) out.add(fromNested(n));
          yield out;
        }
        case "signal" -> {
          List<Signal> out = new ArrayList<>();
          for (benchmark.v2.Signal s : ((BatchSignal) ml).getItemsList()) out.add(fromSignal(s));
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
      case "table" -> fromTable((benchmark.v2.Table) ml);
      case "table_project" -> V2Rows.float0(fromTable((benchmark.v2.Table) ml));
      case "nested_table" -> fromNested((benchmark.v2.NestedRow) ml);
      case "signal" -> fromSignal((benchmark.v2.Signal) ml);
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

  private static benchmark.v2.Table toTable(TableRow row) {
    return benchmark.v2.Table.newBuilder()
        .setFFloat0(row.fFloat0)
        .setFFloat1(row.fFloat1)
        .setFFloat2(row.fFloat2)
        .setFFloat3(row.fFloat3)
        .setFFloat4(row.fFloat4)
        .setFFloat5(row.fFloat5)
        .setFFloat6(row.fFloat6)
        .setFFloat7(row.fFloat7)
        .setFFloat8(row.fFloat8)
        .setFFloat9(row.fFloat9)
        .setFFloat10(row.fFloat10)
        .setFFloat11(row.fFloat11)
        .setFFloat12(row.fFloat12)
        .setFFloat13(row.fFloat13)
        .setFFloat14(row.fFloat14)
        .setFFloat15(row.fFloat15)
        .setFInt0(row.fInt0)
        .setFInt1(row.fInt1)
        .setFInt2(row.fInt2)
        .setFInt3(row.fInt3)
        .setFStr0(nullToEmpty(row.fStr0))
        .setFStr1(nullToEmpty(row.fStr1))
        .build();
  }

  private static TableRow fromTable(benchmark.v2.Table t) {
    TableRow row = new TableRow();
    row.fFloat0 = t.getFFloat0();
    row.fFloat1 = t.getFFloat1();
    row.fFloat2 = t.getFFloat2();
    row.fFloat3 = t.getFFloat3();
    row.fFloat4 = t.getFFloat4();
    row.fFloat5 = t.getFFloat5();
    row.fFloat6 = t.getFFloat6();
    row.fFloat7 = t.getFFloat7();
    row.fFloat8 = t.getFFloat8();
    row.fFloat9 = t.getFFloat9();
    row.fFloat10 = t.getFFloat10();
    row.fFloat11 = t.getFFloat11();
    row.fFloat12 = t.getFFloat12();
    row.fFloat13 = t.getFFloat13();
    row.fFloat14 = t.getFFloat14();
    row.fFloat15 = t.getFFloat15();
    row.fInt0 = t.getFInt0();
    row.fInt1 = t.getFInt1();
    row.fInt2 = t.getFInt2();
    row.fInt3 = t.getFInt3();
    row.fStr0 = t.getFStr0();
    row.fStr1 = t.getFStr1();
    return row;
  }

  private static benchmark.v2.NestedRow toNested(NestedRow row) {
    benchmark.v2.NestedRow.Builder b =
        benchmark.v2.NestedRow.newBuilder().setId(nullToEmpty(row.id)).setStatus(row.status);
    if (row.meta != null) {
      b.setMeta(
          benchmark.v2.NestedMeta.newBuilder()
              .setRegion(nullToEmpty(row.meta.region))
              .setVersion(row.meta.version)
              .build());
    }
    if (row.items != null) {
      for (NestedRow.NestedItem it : row.items) {
        b.addItems(
            benchmark.v2.NestedItem.newBuilder()
                .setSku(nullToEmpty(it.sku))
                .setQty(it.qty)
                .setPriceMinor(it.priceMinor)
                .build());
      }
    }
    return b.build();
  }

  private static NestedRow fromNested(benchmark.v2.NestedRow n) {
    NestedRow.NestedMeta meta =
        n.hasMeta()
            ? new NestedRow.NestedMeta(n.getMeta().getRegion(), n.getMeta().getVersion())
            : new NestedRow.NestedMeta("", 0);
    NestedRow row = new NestedRow(n.getId(), n.getStatus(), meta, new ArrayList<>());
    for (benchmark.v2.NestedItem it : n.getItemsList()) {
      row.items.add(new NestedRow.NestedItem(it.getSku(), it.getQty(), it.getPriceMinor()));
    }
    return row;
  }

  private static benchmark.v2.Signal toSignal(Signal s) {
    benchmark.v2.Signal.Builder b =
        benchmark.v2.Signal.newBuilder()
            .setSeq(s.seq)
            .setTs(s.ts)
            .setPriceMantissa(s.priceMantissa)
            .setQty(s.qty)
            .setFlags(s.flags)
            .setSymbol(nullToEmpty(s.symbol))
            .setVenue(nullToEmpty(s.venue));
    if (s.legs != null) {
      for (Signal.SignalLeg leg : s.legs) {
        b.addLegs(
            benchmark.v2.SignalLeg.newBuilder()
                .setLegId(leg.legId)
                .setLegQty(leg.legQty)
                .setLegPad(leg.legPad)
                .build());
      }
    }
    return b.build();
  }

  private static Signal fromSignal(benchmark.v2.Signal s) {
    Signal row =
        new Signal(
            s.getSeq(),
            s.getTs(),
            s.getPriceMantissa(),
            s.getQty(),
            s.getFlags(),
            s.getSymbol(),
            s.getVenue(),
            new ArrayList<>());
    for (benchmark.v2.SignalLeg leg : s.getLegsList()) {
      row.legs.add(new Signal.SignalLeg(leg.getLegId(), leg.getLegQty(), leg.getLegPad()));
    }
    return row;
  }

  private static String nullToEmpty(String s) {
    return s == null ? "" : s;
  }
}
