package benchmark.serializers;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.function.Supplier;

/** Registered serializers in stable display order (lazy construction). */
public final class Registry {
  private record Entry(String name, Supplier<BenchSerializer> factory) {}

  private static final List<Entry> ENTRIES =
      List.of(
          // JSON family
          new Entry("jackson", JacksonSer::new),
          new Entry("gson", GsonSer::new),
          new Entry("fastjson2", Fastjson2Ser::new),
          new Entry("dsl-json", DslJsonSer::new),
          new Entry("moshi", MoshiSer::new),
          new Entry("jsoniter", JsoniterSer::new),
          // Binary / native
          new Entry("kryo", KryoSer::new),
          new Entry("fory", ForySer::new),
          new Entry("protostuff", ProtostuffSer::new),
          new Entry("hessian", HessianSer::new),
          new Entry("java-serialization", JavaSerializationSer::new),
          new Entry("msgpack", MsgpackSer::new),
          new Entry("jackson-cbor", JacksonCborSer::new),
          new Entry("jackson-smile", JacksonSmileSer::new),
          new Entry("ion", IonSer::new),
          new Entry("bson", BsonSer::new),
          new Entry("jackson-yaml", JacksonYamlSer::new),
          // Schema
          new Entry("protobuf", ProtobufSer::new),
          new Entry("avro", AvroSer::new),
          new Entry("flatbuffers", FlatBuffersSer::new),
          new Entry("capnproto", CapnProtoSer::new));

  private Registry() {}

  public static List<BenchSerializer> all() {
    return select("");
  }

  public static List<BenchSerializer> select(String nameSubstring) {
    String filter = nameSubstring == null ? "" : nameSubstring.toLowerCase(Locale.ROOT);
    List<BenchSerializer> list = new ArrayList<>();
    for (Entry e : ENTRIES) {
      if (!filter.isEmpty() && !e.name().contains(filter)) {
        continue;
      }
      list.add(e.factory().get());
    }
    return list;
  }
}
