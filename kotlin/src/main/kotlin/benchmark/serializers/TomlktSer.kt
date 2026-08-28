package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.Event
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
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
        serializer =
            if (batch) {
                wrapSerializer(typeId) as KSerializer<Any>
            } else {
                TypeUtil.kotlinxSerializer(fx.value)
            }
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        val value: Any =
            if (batch) {
                wrap(typeId, fx.value as List<*>)
            } else {
                fx.value
            }
        return toml.encodeToString(serializer, value).toByteArray(StandardCharsets.UTF_8)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val decoded = toml.decodeFromString(serializer, String(data, StandardCharsets.UTF_8))
        return if (batch) unwrap(typeId, decoded) else decoded
    }

    @Serializable
    data class MessageWrap(val items: List<Message>)

    @Serializable
    data class DocumentWrap(val items: List<Document>)

    @Serializable
    data class TelemetryWrap(val items: List<Telemetry>)

    @Serializable
    data class StringsWrap(val items: List<Strings>)

    @Serializable
    data class EventWrap(val items: List<Event>)

    private fun wrapSerializer(typeId: String): KSerializer<*> =
        when (typeId) {
            "message" -> MessageWrap.serializer()
            "document" -> DocumentWrap.serializer()
            "telemetry" -> TelemetryWrap.serializer()
            "strings" -> StringsWrap.serializer()
            "event" -> EventWrap.serializer()
            else -> throw IllegalArgumentException(typeId)
        }

    @Suppress("UNCHECKED_CAST")
    private fun wrap(typeId: String, items: List<*>): Any =
        when (typeId) {
            "message" -> MessageWrap(items as List<Message>)
            "document" -> DocumentWrap(items as List<Document>)
            "telemetry" -> TelemetryWrap(items as List<Telemetry>)
            "strings" -> StringsWrap(items as List<Strings>)
            "event" -> EventWrap(items as List<Event>)
            else -> throw IllegalArgumentException(typeId)
        }

    private fun unwrap(typeId: String, decoded: Any): Any =
        when (typeId) {
            "message" -> (decoded as MessageWrap).items
            "document" -> (decoded as DocumentWrap).items
            "telemetry" -> (decoded as TelemetryWrap).items
            "strings" -> (decoded as StringsWrap).items
            "event" -> (decoded as EventWrap).items
            else -> decoded
        }
}
