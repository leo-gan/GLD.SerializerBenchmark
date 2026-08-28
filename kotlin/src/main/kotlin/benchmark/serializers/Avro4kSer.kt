package benchmark.serializers

import benchmark.model.Fixture
import com.github.avrokotlin.avro4k.Avro
import kotlinx.serialization.KSerializer
import java.io.InputStream
import java.io.OutputStream

/**
 * Avro4k — Kotlin-native Apache Avro via kotlinx.serialization.
 *
 * Hot path: reuse [Avro]; cache [KSerializer]; encodeToByteArray / decodeFromByteArray.
 */
class Avro4kSer : BenchSerializer {
    private val avro = Avro
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "avro4k"

    override fun version() = Versions.of("com.github.avro4k.Avro")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "schema"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray = avro.encodeToByteArray(serializer, fx.value)

    override fun deserializeBytes(data: ByteArray): Any = avro.decodeFromByteArray(serializer, data)

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val bytes = serializeBytes(fx)
        out.write(bytes)
        return bytes.size
    }

    override fun deserializeStream(input: InputStream): Any = deserializeBytes(input.readAllBytes())
}
