package benchmark.serializers

import benchmark.model.Fixture
import kotlinx.serialization.KSerializer
import net.peanuuutz.tomlkt.Toml
import java.nio.charset.StandardCharsets

/**
 * tomlkt — TOML 1.0 via kotlinx.serialization.
 *
 * TOML cannot encode a root array, so batch fixtures are wrapped as `{ items = [...] }`.
 */
class TomlktSer : BenchSerializer {
    private val toml = Toml { ignoreUnknownKeys = true }
    private lateinit var serializer: KSerializer<Any>
    private var batch = false
    private var typeId: String = ""

    override fun name() = "tomlkt"

    override fun version() = Versions.of("net.peanuuutz.tomlkt.Toml")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    @Suppress("UNCHECKED_CAST")
    override fun prepare(fx: Fixture) {
        batch = TypeUtil.isList(fx.value)
        typeId = fx.name
        serializer = if (batch) Wraps.serializer(typeId) else TypeUtil.kotlinxSerializer(fx.value)
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        val value = if (batch) Wraps.wrap(typeId, fx.value as List<*>) else fx.value
        return toml.encodeToString(serializer, value).toByteArray(StandardCharsets.UTF_8)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val decoded = toml.decodeFromString(serializer, String(data, StandardCharsets.UTF_8))
        return if (batch) Wraps.unwrap(typeId, decoded) else decoded
    }
}
