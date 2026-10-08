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
            Entry("arrow-ipc", ::ArrowIpcSer),
            Entry("parquet", ::ParquetSer),
            Entry("parquet-uncompressed", ::ParquetUncompressedSer),
            Entry("orc", ::OrcSer),
            Entry("orc-uncompressed", ::OrcUncompressedSer),
            Entry("sbe", ::SbeSer),
        )

    fun names(): List<String> = entries.map { it.name }

    fun all(): List<BenchSerializer> = select("")

    /**
     * Empty selects every name. A filter with no comma is a case-insensitive substring.
     * A comma-separated list is case-insensitive exact names, in registry order.
     * "protobuf" still matches protobuf-kotlin. "protobuf," and "protobuf,avro" do not.
     */
    fun select(nameSubstring: String?): List<BenchSerializer> {
        val filter = nameSubstring ?: ""
        if (filter.isEmpty()) return entries.map { it.factory() }
        val chosen =
            if (!filter.contains(',')) {
                val needle = filter.lowercase(Locale.ROOT)
                entries.filter { it.name.lowercase(Locale.ROOT).contains(needle) }
            } else {
                // Kotlin rejects Java's split limit -1. Limit 0 drops trailing empties;
                // empty pieces are dropped below, so "protobuf," is exact "protobuf".
                val want =
                    filter.split(",", limit = 0)
                        .map { it.trim().lowercase(Locale.ROOT) }
                        .filter { it.isNotEmpty() }
                        .toSet()
                entries.filter { it.name.lowercase(Locale.ROOT) in want }
            }
        return chosen.map { it.factory() }
    }
}
