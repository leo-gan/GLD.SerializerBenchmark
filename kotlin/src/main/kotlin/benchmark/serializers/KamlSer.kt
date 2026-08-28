package benchmark.serializers

import benchmark.model.Fixture
import com.charleskorn.kaml.Yaml
import com.charleskorn.kaml.YamlConfiguration
import kotlinx.serialization.KSerializer
import java.nio.charset.StandardCharsets

/**
 * kaml — YAML for kotlinx.serialization (same @Serializable domain types).
 *
 * Hot path: reuse [Yaml]; cache [KSerializer]; encodeToString / decodeFromString.
 */
class KamlSer : BenchSerializer {
    private val yaml = Yaml(configuration = YamlConfiguration(encodeDefaults = true, strictMode = false))
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "kaml"

    override fun version() = Versions.of("com.charleskorn.kaml.Yaml")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray =
        yaml.encodeToString(serializer, fx.value).toByteArray(StandardCharsets.UTF_8)

    override fun deserializeBytes(data: ByteArray): Any =
        yaml.decodeFromString(serializer, String(data, StandardCharsets.UTF_8))
}
