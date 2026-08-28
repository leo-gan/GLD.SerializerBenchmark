package benchmark.serializers

import benchmark.model.Fixture
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromStream
import kotlinx.serialization.json.encodeToStream
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * kotlinx.serialization JSON — canonical Kotlin serialization (compiler-generated serializers).
 *
 * Hot path: reuse [Json]; cache [KSerializer]; [Json.encodeToStream] / [Json.decodeFromStream].
 */
class KotlinxJsonSer : BenchSerializer {
    private val json = Json { encodeDefaults = true }
    private lateinit var serializer: KSerializer<Any>
    private val baos = ByteArrayOutputStream(4096)

    override fun name() = "kotlinx-json"

    override fun version() = Versions.of("kotlinx.serialization.json.Json")

    override fun streamMode() = "native"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
        baos.reset()
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        baos.reset()
        json.encodeToStream(serializer, fx.value, baos)
        return baos.toByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any =
        json.decodeFromStream(serializer, ByteArrayInputStream(data))

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val cos = CountingOutputStream(out)
        json.encodeToStream(serializer, fx.value, cos)
        return cos.count
    }

    override fun deserializeStream(input: InputStream): Any = json.decodeFromStream(serializer, input)
}
