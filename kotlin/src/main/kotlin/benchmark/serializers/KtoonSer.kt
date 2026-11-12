package benchmark.serializers

import benchmark.model.Fixture
import com.lukelast.ktoon.Ktoon
import kotlinx.serialization.KSerializer
import java.nio.charset.StandardCharsets

/**
 * ktoon — TOON for kotlinx.serialization. There is no official Kotlin port.
 * The timed path is encodeToString / decodeFromString. Size is UTF-8 bytes.
 * https://github.com/lukelast/ktoon
 */
class KtoonSer : BenchSerializer {
    private val format = Ktoon.Default
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "ktoon"

    override fun version() = Versions.of("com.lukelast.ktoon.Ktoon")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray =
        format.encodeToString(serializer, fx.value).toByteArray(StandardCharsets.UTF_8)

    override fun deserializeBytes(data: ByteArray): Any =
        format.decodeFromString(serializer, String(data, StandardCharsets.UTF_8))
}
