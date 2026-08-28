package benchmark.serializers

import benchmark.model.Fixture
import kotlinx.serialization.KSerializer
import net.orandja.obor.codec.Cbor

/**
 * Obor — alternative Kotlin CBOR implementation on kotlinx.serialization.
 *
 * Hot path: reuse [Cbor]; cache [KSerializer]; encodeToByteArray / decodeFromByteArray.
 */
class OborSer : BenchSerializer {
    private val cbor = Cbor
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "obor"

    override fun version() = Versions.of("net.orandja.obor.codec.Cbor")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray = cbor.encodeToByteArray(serializer, fx.value)

    override fun deserializeBytes(data: ByteArray): Any = cbor.decodeFromByteArray(serializer, data)
}
