package benchmark.serializers

import benchmark.model.Fixture
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.decodeFromByteArray
import kotlinx.serialization.encodeToByteArray
import kotlinx.serialization.protobuf.ProtoBuf

/**
 * kotlinx.serialization ProtoBuf — official Kotlin schema-style binary (no .proto).
 *
 * Hot path: reuse [ProtoBuf]; cache [KSerializer]; encodeToByteArray / decodeFromByteArray.
 */
@OptIn(ExperimentalSerializationApi::class)
class KotlinxProtobufSer : BenchSerializer {
    private val proto = ProtoBuf { encodeDefaults = true }
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "kotlinx-protobuf"

    override fun version() = Versions.of("kotlinx.serialization.protobuf.ProtoBuf")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "schema"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray = proto.encodeToByteArray(serializer, fx.value)

    override fun deserializeBytes(data: ByteArray): Any = proto.decodeFromByteArray(serializer, data)
}
