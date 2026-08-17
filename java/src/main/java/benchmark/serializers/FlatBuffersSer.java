package benchmark.serializers;

import benchmark.fb.Document;
import benchmark.fb.DocumentItem;
import benchmark.fb.DocumentMeta;
import benchmark.fb.Event;
import benchmark.fb.EventAttr;
import benchmark.fb.Message;
import benchmark.fb.Strings;
import benchmark.fb.Telemetry;
import benchmark.model.Fixture;
import com.google.flatbuffers.FlatBufferBuilder;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

/**
 * Official FlatBuffers Java runtime + generated tables from {@code cpp/schemas/benchmark.fbs}.
 *
 * @see <a href="https://flatbuffers.dev/tutorial/">FlatBuffers tutorial</a>
 */
public final class FlatBuffersSer implements BenchSerializer {
  private final FlatBufferBuilder builder = new FlatBufferBuilder(1024);
  private String typeId;
  private boolean batch;

  @Override
  public String name() {
    return "flatbuffers";
  }

  @Override
  public String version() {
    return Versions.of(FlatBufferBuilder.class);
  }

  @Override
  public String nativeKind() {
    return "schema";
  }

  @Override
  public void prepare(Fixture fx) {
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    builder.clear();
    int root;
    if (batch) {
      root = packList(fx.value);
    } else {
      root = packOne(fx.value);
    }
    builder.finish(root);
    ByteBuffer bb = builder.dataBuffer();
    byte[] out = new byte[bb.remaining()];
    bb.get(out);
    return out;
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    ByteBuffer bb = ByteBuffer.wrap(data);
    if (batch) {
      return unpackList(bb);
    }
    return unpackOne(bb);
  }

  @Override
  public Object toDomain(Object decoded) {
    return decoded;
  }

  private int packOne(Object value) {
    return switch (typeId) {
      case "message" -> packMessage((benchmark.model.v2.Message) value);
      case "document" -> packDocument((benchmark.model.v2.Document) value);
      case "telemetry" -> packTelemetry((benchmark.model.v2.Telemetry) value);
      case "strings" -> packStrings((benchmark.model.v2.Strings) value);
      case "event" -> packEvent((benchmark.model.v2.Event) value);
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private int packList(Object value) {
    List<?> list = (List<?>) value;
    int[] offs = new int[list.size()];
    for (int i = 0; i < list.size(); i++) {
      offs[i] = packOne(list.get(i));
    }
    return switch (typeId) {
      case "message" -> benchmark.fb.BatchMessage.createBatchMessage(
          builder, benchmark.fb.BatchMessage.createItemsVector(builder, offs));
      case "document" -> benchmark.fb.BatchDocument.createBatchDocument(
          builder, benchmark.fb.BatchDocument.createItemsVector(builder, offs));
      case "telemetry" -> benchmark.fb.BatchTelemetry.createBatchTelemetry(
          builder, benchmark.fb.BatchTelemetry.createItemsVector(builder, offs));
      case "strings" -> benchmark.fb.BatchStrings.createBatchStrings(
          builder, benchmark.fb.BatchStrings.createItemsVector(builder, offs));
      case "event" -> benchmark.fb.BatchEvent.createBatchEvent(
          builder, benchmark.fb.BatchEvent.createItemsVector(builder, offs));
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private int packMessage(benchmark.model.v2.Message m) {
    int s1 = builder.createString(nz(m.fString));
    int s2 = builder.createString(nz(m.fString2));
    return Message.createMessage(
        builder, m.fBool, m.fInt32, m.fInt64, m.fFloat64, s1, m.fBool2, m.fInt32_2, s2);
  }

  private int packDocument(benchmark.model.v2.Document d) {
    int id = builder.createString(nz(d.id));
    var metaIn = d.meta != null ? d.meta : new benchmark.model.v2.Document.DocumentMeta();
    int meta =
        DocumentMeta.createDocumentMeta(builder, builder.createString(nz(metaIn.region)), metaIn.version);
    List<benchmark.model.v2.Document.DocumentItem> items =
        d.items != null ? d.items : List.of();
    int[] itemOffs = new int[items.size()];
    for (int i = 0; i < items.size(); i++) {
      var it = items.get(i);
      itemOffs[i] =
          DocumentItem.createDocumentItem(
              builder, builder.createString(nz(it.sku)), it.qty, it.priceMinor);
    }
    int itemsOff = Document.createItemsVector(builder, itemOffs);
    return Document.createDocument(builder, id, d.status, meta, itemsOff);
  }

  private int packTelemetry(benchmark.model.v2.Telemetry t) {
    int src = builder.createString(nz(t.source));
    List<String> tags = t.tags != null ? t.tags : List.of();
    int[] tagOffs = new int[tags.size()];
    for (int i = 0; i < tags.size(); i++) {
      tagOffs[i] = builder.createString(nz(tags.get(i)));
    }
    int tagsOff = Telemetry.createTagsVector(builder, tagOffs);
    double[] vals = t.values != null ? t.values : new double[0];
    int valsOff = Telemetry.createValuesVector(builder, vals);
    return Telemetry.createTelemetry(builder, src, t.ts, tagsOff, valsOff);
  }

  private int packStrings(benchmark.model.v2.Strings s) {
    List<String> items = s.items != null ? s.items : List.of();
    int[] offs = new int[items.size()];
    for (int i = 0; i < items.size(); i++) {
      offs[i] = builder.createString(nz(items.get(i)));
    }
    return Strings.createStrings(builder, Strings.createItemsVector(builder, offs));
  }

  private int packEvent(benchmark.model.v2.Event e) {
    int id = builder.createString(nz(e.eventId));
    int typ = builder.createString(nz(e.eventType));
    int prod = builder.createString(nz(e.producer));
    List<benchmark.model.v2.Event.EventAttr> attrs = e.attrs != null ? e.attrs : List.of();
    int[] attrOffs = new int[attrs.size()];
    for (int i = 0; i < attrs.size(); i++) {
      var a = attrs.get(i);
      attrOffs[i] =
          EventAttr.createEventAttr(
              builder, builder.createString(nz(a.key)), builder.createString(nz(a.value)));
    }
    return Event.createEvent(
        builder, id, typ, e.occurredAt, prod, Event.createAttrsVector(builder, attrOffs));
  }

  private Object unpackOne(ByteBuffer bb) {
    return switch (typeId) {
      case "message" -> fromMessage(Message.getRootAsMessage(bb));
      case "document" -> fromDocument(Document.getRootAsDocument(bb));
      case "telemetry" -> fromTelemetry(Telemetry.getRootAsTelemetry(bb));
      case "strings" -> fromStrings(Strings.getRootAsStrings(bb));
      case "event" -> fromEvent(Event.getRootAsEvent(bb));
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private Object unpackList(ByteBuffer bb) {
    return switch (typeId) {
      case "message" -> {
        var b = benchmark.fb.BatchMessage.getRootAsBatchMessage(bb);
        List<benchmark.model.v2.Message> out = new ArrayList<>(b.itemsLength());
        for (int i = 0; i < b.itemsLength(); i++) out.add(fromMessage(b.items(i)));
        yield out;
      }
      case "document" -> {
        var b = benchmark.fb.BatchDocument.getRootAsBatchDocument(bb);
        List<benchmark.model.v2.Document> out = new ArrayList<>(b.itemsLength());
        for (int i = 0; i < b.itemsLength(); i++) out.add(fromDocument(b.items(i)));
        yield out;
      }
      case "telemetry" -> {
        var b = benchmark.fb.BatchTelemetry.getRootAsBatchTelemetry(bb);
        List<benchmark.model.v2.Telemetry> out = new ArrayList<>(b.itemsLength());
        for (int i = 0; i < b.itemsLength(); i++) out.add(fromTelemetry(b.items(i)));
        yield out;
      }
      case "strings" -> {
        var b = benchmark.fb.BatchStrings.getRootAsBatchStrings(bb);
        List<benchmark.model.v2.Strings> out = new ArrayList<>(b.itemsLength());
        for (int i = 0; i < b.itemsLength(); i++) out.add(fromStrings(b.items(i)));
        yield out;
      }
      case "event" -> {
        var b = benchmark.fb.BatchEvent.getRootAsBatchEvent(bb);
        List<benchmark.model.v2.Event> out = new ArrayList<>(b.itemsLength());
        for (int i = 0; i < b.itemsLength(); i++) out.add(fromEvent(b.items(i)));
        yield out;
      }
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static benchmark.model.v2.Message fromMessage(Message m) {
    return new benchmark.model.v2.Message(
        m.fBool(),
        m.fInt32(),
        m.fInt64(),
        m.fFloat64(),
        nz(m.fString()),
        m.fBool2(),
        m.fInt322(),
        nz(m.fString2()));
  }

  private static benchmark.model.v2.Document fromDocument(Document d) {
    var meta = new benchmark.model.v2.Document.DocumentMeta();
    if (d.meta() != null) {
      meta.region = nz(d.meta().region());
      meta.version = d.meta().version();
    }
    List<benchmark.model.v2.Document.DocumentItem> items = new ArrayList<>(d.itemsLength());
    for (int i = 0; i < d.itemsLength(); i++) {
      var src = d.items(i);
      items.add(
          new benchmark.model.v2.Document.DocumentItem(nz(src.sku()), src.qty(), src.priceMinor()));
    }
    return new benchmark.model.v2.Document(nz(d.id()), d.status(), meta, items);
  }

  private static benchmark.model.v2.Telemetry fromTelemetry(Telemetry t) {
    List<String> tags = new ArrayList<>(t.tagsLength());
    for (int i = 0; i < t.tagsLength(); i++) tags.add(nz(t.tags(i)));
    double[] vals = new double[t.valuesLength()];
    for (int i = 0; i < vals.length; i++) vals[i] = t.values(i);
    return new benchmark.model.v2.Telemetry(nz(t.source()), t.ts(), tags, vals);
  }

  private static benchmark.model.v2.Strings fromStrings(Strings s) {
    List<String> items = new ArrayList<>(s.itemsLength());
    for (int i = 0; i < s.itemsLength(); i++) items.add(nz(s.items(i)));
    return new benchmark.model.v2.Strings(items);
  }

  private static benchmark.model.v2.Event fromEvent(Event e) {
    List<benchmark.model.v2.Event.EventAttr> attrs = new ArrayList<>(e.attrsLength());
    for (int i = 0; i < e.attrsLength(); i++) {
      var a = e.attrs(i);
      attrs.add(new benchmark.model.v2.Event.EventAttr(nz(a.key()), nz(a.value())));
    }
    return new benchmark.model.v2.Event(
        nz(e.eventId()), nz(e.eventType()), e.occurredAt(), nz(e.producer()), attrs);
  }

  private static String nz(String s) {
    return s == null ? "" : s;
  }
}
