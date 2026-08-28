package benchmark.serializers

import benchmark.model.Fixture
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.cbor.Cbor
import kotlinx.serialization.decodeFromByteArray
import kotlinx.serialization.encodeToByteArray

/**
 * kotlinx.serialization CBOR — official Kotlin binary format.
 *
 * Hot path: reuse [Cbor]; cache [KSerializer]; [Cbor.encodeToByteArray] / [Cbor.decodeFromByteArray].
 */
@OptIn(ExperimentalSerializationApi::class)
class KotlinxCborSer : BenchSerializer {
    private val cbor = Cbor { encodeDefaults = true }
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "kotlinx-cbor"

    override fun version() = Versions.of("kotlinx.serialization.cbor.Cbor")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray = cbor.encodeToByteArray(serializer, fx.value)

    override fun deserializeBytes(data: ByteArray): Any = cbor.decodeFromByteArray(serializer, data)
}
