package benchmark.serializers

import benchmark.model.Fixture
import com.typesafe.config.ConfigFactory
import com.typesafe.config.ConfigRenderOptions
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.hocon.Hocon
import kotlinx.serialization.hocon.decodeFromConfig
import kotlinx.serialization.hocon.encodeToConfig
import java.nio.charset.StandardCharsets

/**
 * kotlinx.serialization HOCON — official JVM-only format family member (Lightbend Config).
 *
 * Hot path: reuse [Hocon] with encodeDefaults; [Hocon.encodeToConfig] / [Hocon.decodeFromConfig].
 * HOCON cannot encode a root array, so batches are wrapped as `{ items = [...] }`.
 */
@OptIn(ExperimentalSerializationApi::class)
class KotlinxHoconSer : BenchSerializer {
    private val hocon = Hocon { encodeDefaults = true }
    private val render = ConfigRenderOptions.concise().setJson(false)
    private lateinit var serializer: KSerializer<Any>
    private var batch = false
    private var typeId: String = ""

    override fun name() = "kotlinx-hocon"

    override fun version() = Versions.of("kotlinx.serialization.hocon.Hocon")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        batch = TypeUtil.isList(fx.value)
        typeId = fx.name
        serializer = if (batch) Wraps.serializer(typeId) else TypeUtil.kotlinxSerializer(fx.value)
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        val value = if (batch) Wraps.wrap(typeId, fx.value as List<*>) else fx.value
        val cfg = hocon.encodeToConfig(serializer, value)
        return cfg.root().render(render).toByteArray(StandardCharsets.UTF_8)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val cfg = ConfigFactory.parseString(String(data, StandardCharsets.UTF_8))
        val decoded = hocon.decodeFromConfig(serializer, cfg)
        return if (batch) Wraps.unwrap(typeId, decoded) else decoded
    }
}
