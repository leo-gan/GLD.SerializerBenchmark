package benchmark.serializers

import java.util.Locale

/** Registered serializers in stable display order (lazy construction). */
object Registry {
    private data class Entry(val name: String, val factory: () -> BenchSerializer)

    private val entries: List<Entry> =
        listOf(
            // JSON family
            Entry("kotlinx-json", ::KotlinxJsonSer),
            Entry("kotlinx-properties", ::KotlinxPropertiesSer),
            Entry("kotlinx-hocon", ::KotlinxHoconSer),
            Entry("kaml", ::KamlSer),
            Entry("jackson", ::JacksonKotlinSer),
            Entry("moshi-codegen", ::MoshiCodegenSer),
            Entry("moshi-reflect", ::MoshiReflectSer),
            Entry("gson", ::GsonSer),
            // Binary / document
            Entry("kotlinx-cbor", ::KotlinxCborSer),
            Entry("jackson-cbor", ::JacksonCborSer),
            Entry("obor", ::OborSer),
            Entry("msgpack", ::MsgpackSer),
            Entry("kryo", ::KryoSer),
            Entry("fory", ::ForySer),
            Entry("protostuff", ::ProtostuffSer),
            Entry("kbson", ::KBsonSer),
            Entry("kotlinx-ion", ::KotlinxIonSer),
            Entry("tomlkt", ::TomlktSer),
            // Schema
            Entry("kotlinx-protobuf", ::KotlinxProtobufSer),
            Entry("protobuf", ::ProtobufSer),
            Entry("protobuf-kotlin", ::ProtobufKotlinSer),
            Entry("avro4k", ::Avro4kSer),
            Entry("avro", ::AvroSer),
            Entry("thrift", ::ThriftSer),
            Entry("flatbuffers", ::FlatBuffersSer),
            Entry("capnproto", ::CapnProtoSer),
        )

    fun all(): List<BenchSerializer> = select("")

    fun select(nameSubstring: String?): List<BenchSerializer> {
        val filter = nameSubstring?.lowercase(Locale.ROOT) ?: ""
        return entries
            .filter { filter.isEmpty() || it.name.contains(filter) }
            .map { it.factory() }
    }
}
