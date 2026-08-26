package benchmark.serializers;

import benchmark.capnp.BenchmarkCapnp;
import benchmark.model.Fixture;
import org.capnproto.ArrayInputStream;
import org.capnproto.ArrayOutputStream;
import org.capnproto.MessageBuilder;
import org.capnproto.MessageReader;
import org.capnproto.Serialize;
import org.capnproto.TextList;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.util.ArrayList;
import java.util.List;

/**
 * Official Cap'n Proto Java runtime ({@code org.capnproto:runtime}) plus generated
 * {@link BenchmarkCapnp} from the suite {@code .capnp} schema.
 *
 * @see <a href="https://github.com/capnproto/capnproto-java">capnproto-java</a>
 */
public final class CapnProtoSer implements BenchSerializer {
  private String typeId;
  private boolean batch;
  /** Sized in {@link #prepare} so the timed path does not grow or miss. */
  private int writeBufSize = 64 * 1024;

  @Override
  public String name() {
    return "capnproto";
  }

  @Override
  public String version() {
    return Versions.of(Serialize.class);
  }

  @Override
  public String nativeKind() {
    return "schema";
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public void prepare(Fixture fx) {
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    writeBufSize = sizedBuffer(fx);
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    MessageBuilder mb = new MessageBuilder();
    fill(mb, fx.value);
    ArrayOutputStream os = new ArrayOutputStream(ByteBuffer.allocate(writeBufSize));
    Serialize.write(os, mb);
    ByteBuffer bb = os.getWriteBuffer().duplicate();
    bb.flip();
    byte[] out = new byte[bb.remaining()];
    bb.get(out);
    return out;
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    MessageReader reader = Serialize.read(new ArrayInputStream(ByteBuffer.wrap(data)));
    return readRoot(reader);
  }

  @Override
  public int serializeStream(Fixture fx, java.io.OutputStream out) throws Exception {
    byte[] raw = serializeBytes(fx);
    out.write(raw);
    return raw.length;
  }

  @Override
  public Object deserializeStream(java.io.InputStream in) throws Exception {
    MessageReader reader = Serialize.read(Channels.newChannel(in));
    return readRoot(reader);
  }

  private int sizedBuffer(Fixture fx) {
    MessageBuilder mb = new MessageBuilder();
    fill(mb, fx.value);
    int size = 64 * 1024;
    while (size <= 16 * 1024 * 1024) {
      try {
        Serialize.write(new ArrayOutputStream(ByteBuffer.allocate(size)), mb);
        return size;
      } catch (IOException e) {
        size *= 2;
      }
    }
    throw new IllegalStateException("capnproto payload exceeds 16 MiB");
  }

  private void fill(MessageBuilder mb, Object value) {
    if (batch) {
      fillBatch(mb, (List<?>) value);
      return;
    }
    switch (typeId) {
      case "message" -> fillMessage(mb.initRoot(BenchmarkCapnp.Message.factory), (benchmark.model.v2.Message) value);
      case "document" -> fillDocument(mb.initRoot(BenchmarkCapnp.Document.factory), (benchmark.model.v2.Document) value);
      case "telemetry" -> fillTelemetry(mb.initRoot(BenchmarkCapnp.Telemetry.factory), (benchmark.model.v2.Telemetry) value);
      case "strings" -> fillStrings(mb.initRoot(BenchmarkCapnp.Strings.factory), (benchmark.model.v2.Strings) value);
      case "event" -> fillEvent(mb.initRoot(BenchmarkCapnp.Event.factory), (benchmark.model.v2.Event) value);
      default -> throw new IllegalArgumentException(typeId);
    }
  }

  private void fillBatch(MessageBuilder mb, List<?> list) {
    switch (typeId) {
      case "message" -> {
        var b = mb.initRoot(BenchmarkCapnp.BatchMessage.factory);
        var items = b.initItems(list.size());
        for (int i = 0; i < list.size(); i++) {
          fillMessage(items.get(i), (benchmark.model.v2.Message) list.get(i));
        }
      }
      case "document" -> {
        var b = mb.initRoot(BenchmarkCapnp.BatchDocument.factory);
        var items = b.initItems(list.size());
        for (int i = 0; i < list.size(); i++) {
          fillDocument(items.get(i), (benchmark.model.v2.Document) list.get(i));
        }
      }
      case "telemetry" -> {
        var b = mb.initRoot(BenchmarkCapnp.BatchTelemetry.factory);
        var items = b.initItems(list.size());
        for (int i = 0; i < list.size(); i++) {
          fillTelemetry(items.get(i), (benchmark.model.v2.Telemetry) list.get(i));
        }
      }
      case "strings" -> {
        var b = mb.initRoot(BenchmarkCapnp.BatchStrings.factory);
        var items = b.initItems(list.size());
        for (int i = 0; i < list.size(); i++) {
          fillStrings(items.get(i), (benchmark.model.v2.Strings) list.get(i));
        }
      }
      case "event" -> {
        var b = mb.initRoot(BenchmarkCapnp.BatchEvent.factory);
        var items = b.initItems(list.size());
        for (int i = 0; i < list.size(); i++) {
          fillEvent(items.get(i), (benchmark.model.v2.Event) list.get(i));
        }
      }
      default -> throw new IllegalArgumentException(typeId);
    }
  }

  private static void fillMessage(BenchmarkCapnp.Message.Builder b, benchmark.model.v2.Message m) {
    b.setFBool(m.fBool);
    b.setFInt32(m.fInt32);
    b.setFInt64(m.fInt64);
    b.setFFloat64(m.fFloat64);
    b.setFString(nz(m.fString));
    b.setFBool2(m.fBool2);
    b.setFInt32B(m.fInt32_2);
    b.setFStringB(nz(m.fString2));
  }

  private static void fillDocument(BenchmarkCapnp.Document.Builder b, benchmark.model.v2.Document d) {
    b.setId(nz(d.id));
    b.setStatus(d.status);
    var meta = d.meta != null ? d.meta : new benchmark.model.v2.Document.DocumentMeta();
    var mb = b.initMeta();
    mb.setRegion(nz(meta.region));
    mb.setVersion(meta.version);
    List<benchmark.model.v2.Document.DocumentItem> items = d.items != null ? d.items : List.of();
    var ib = b.initItems(items.size());
    for (int i = 0; i < items.size(); i++) {
      var it = items.get(i);
      var slot = ib.get(i);
      slot.setSku(nz(it.sku));
      slot.setQty(it.qty);
      slot.setPriceMinor(it.priceMinor);
    }
  }

  private static void fillTelemetry(BenchmarkCapnp.Telemetry.Builder b, benchmark.model.v2.Telemetry t) {
    b.setSource(nz(t.source));
    b.setTs(t.ts);
    List<String> tags = t.tags != null ? t.tags : List.of();
    TextList.Builder tb = b.initTags(tags.size());
    for (int i = 0; i < tags.size(); i++) tb.set(i, new org.capnproto.Text.Reader(nz(tags.get(i))));
    double[] vals = t.values != null ? t.values : new double[0];
    var vb = b.initValues(vals.length);
    for (int i = 0; i < vals.length; i++) vb.set(i, vals[i]);
  }

  private static void fillStrings(BenchmarkCapnp.Strings.Builder b, benchmark.model.v2.Strings s) {
    List<String> items = s.items != null ? s.items : List.of();
    TextList.Builder tb = b.initItems(items.size());
    for (int i = 0; i < items.size(); i++) tb.set(i, new org.capnproto.Text.Reader(nz(items.get(i))));
  }

  private static void fillEvent(BenchmarkCapnp.Event.Builder b, benchmark.model.v2.Event e) {
    b.setEventId(nz(e.eventId));
    b.setEventType(nz(e.eventType));
    b.setOccurredAt(e.occurredAt);
    b.setProducer(nz(e.producer));
    List<benchmark.model.v2.Event.EventAttr> attrs = e.attrs != null ? e.attrs : List.of();
    var ab = b.initAttrs(attrs.size());
    for (int i = 0; i < attrs.size(); i++) {
      var a = attrs.get(i);
      var slot = ab.get(i);
      slot.setKey(nz(a.key));
      slot.setValue(nz(a.value));
    }
  }

  private Object readRoot(MessageReader reader) {
    if (batch) return readBatch(reader);
    return switch (typeId) {
      case "message" -> fromMessage(reader.getRoot(BenchmarkCapnp.Message.factory));
      case "document" -> fromDocument(reader.getRoot(BenchmarkCapnp.Document.factory));
      case "telemetry" -> fromTelemetry(reader.getRoot(BenchmarkCapnp.Telemetry.factory));
      case "strings" -> fromStrings(reader.getRoot(BenchmarkCapnp.Strings.factory));
      case "event" -> fromEvent(reader.getRoot(BenchmarkCapnp.Event.factory));
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private Object readBatch(MessageReader reader) {
    return switch (typeId) {
      case "message" -> {
        var items = reader.getRoot(BenchmarkCapnp.BatchMessage.factory).getItems();
        List<benchmark.model.v2.Message> out = new ArrayList<>(items.size());
        for (int i = 0; i < items.size(); i++) out.add(fromMessage(items.get(i)));
        yield out;
      }
      case "document" -> {
        var items = reader.getRoot(BenchmarkCapnp.BatchDocument.factory).getItems();
        List<benchmark.model.v2.Document> out = new ArrayList<>(items.size());
        for (int i = 0; i < items.size(); i++) out.add(fromDocument(items.get(i)));
        yield out;
      }
      case "telemetry" -> {
        var items = reader.getRoot(BenchmarkCapnp.BatchTelemetry.factory).getItems();
        List<benchmark.model.v2.Telemetry> out = new ArrayList<>(items.size());
        for (int i = 0; i < items.size(); i++) out.add(fromTelemetry(items.get(i)));
        yield out;
      }
      case "strings" -> {
        var items = reader.getRoot(BenchmarkCapnp.BatchStrings.factory).getItems();
        List<benchmark.model.v2.Strings> out = new ArrayList<>(items.size());
        for (int i = 0; i < items.size(); i++) out.add(fromStrings(items.get(i)));
        yield out;
      }
      case "event" -> {
        var items = reader.getRoot(BenchmarkCapnp.BatchEvent.factory).getItems();
        List<benchmark.model.v2.Event> out = new ArrayList<>(items.size());
        for (int i = 0; i < items.size(); i++) out.add(fromEvent(items.get(i)));
        yield out;
      }
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static benchmark.model.v2.Message fromMessage(BenchmarkCapnp.Message.Reader r) {
    return new benchmark.model.v2.Message(
        r.getFBool(),
        r.getFInt32(),
        r.getFInt64(),
        r.getFFloat64(),
        r.getFString().toString(),
        r.getFBool2(),
        r.getFInt32B(),
        r.getFStringB().toString());
  }

  private static benchmark.model.v2.Document fromDocument(BenchmarkCapnp.Document.Reader r) {
    var meta = new benchmark.model.v2.Document.DocumentMeta();
    if (r.hasMeta()) {
      meta.region = r.getMeta().getRegion().toString();
      meta.version = r.getMeta().getVersion();
    }
    var itemsIn = r.getItems();
    List<benchmark.model.v2.Document.DocumentItem> items = new ArrayList<>(itemsIn.size());
    for (int i = 0; i < itemsIn.size(); i++) {
      var it = itemsIn.get(i);
      items.add(
          new benchmark.model.v2.Document.DocumentItem(
              it.getSku().toString(), it.getQty(), it.getPriceMinor()));
    }
    return new benchmark.model.v2.Document(r.getId().toString(), r.getStatus(), meta, items);
  }

  private static benchmark.model.v2.Telemetry fromTelemetry(BenchmarkCapnp.Telemetry.Reader r) {
    var tagsIn = r.getTags();
    List<String> tags = new ArrayList<>(tagsIn.size());
    for (int i = 0; i < tagsIn.size(); i++) tags.add(tagsIn.get(i).toString());
    var valsIn = r.getValues();
    double[] vals = new double[valsIn.size()];
    for (int i = 0; i < vals.length; i++) vals[i] = valsIn.get(i);
    return new benchmark.model.v2.Telemetry(r.getSource().toString(), r.getTs(), tags, vals);
  }

  private static benchmark.model.v2.Strings fromStrings(BenchmarkCapnp.Strings.Reader r) {
    var itemsIn = r.getItems();
    List<String> items = new ArrayList<>(itemsIn.size());
    for (int i = 0; i < itemsIn.size(); i++) items.add(itemsIn.get(i).toString());
    return new benchmark.model.v2.Strings(items);
  }

  private static benchmark.model.v2.Event fromEvent(BenchmarkCapnp.Event.Reader r) {
    var attrsIn = r.getAttrs();
    List<benchmark.model.v2.Event.EventAttr> attrs = new ArrayList<>(attrsIn.size());
    for (int i = 0; i < attrsIn.size(); i++) {
      var a = attrsIn.get(i);
      attrs.add(new benchmark.model.v2.Event.EventAttr(a.getKey().toString(), a.getValue().toString()));
    }
    return new benchmark.model.v2.Event(
        r.getEventId().toString(),
        r.getEventType().toString(),
        r.getOccurredAt(),
        r.getProducer().toString(),
        attrs);
  }

  private static String nz(String s) {
    return s == null ? "" : s;
  }
}
