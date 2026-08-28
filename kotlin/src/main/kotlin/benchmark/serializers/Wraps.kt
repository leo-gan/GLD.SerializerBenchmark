package benchmark.serializers

import benchmark.model.v2.Document
import benchmark.model.v2.Event
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable

/** Table-root wrappers for formats that cannot encode a bare list (HOCON, Properties). */
object Wraps {
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

    fun serializer(typeId: String): KSerializer<Any> {
        @Suppress("UNCHECKED_CAST")
        return when (typeId) {
            "message" -> MessageWrap.serializer()
            "document" -> DocumentWrap.serializer()
            "telemetry" -> TelemetryWrap.serializer()
            "strings" -> StringsWrap.serializer()
            "event" -> EventWrap.serializer()
            else -> throw IllegalArgumentException(typeId)
        } as KSerializer<Any>
    }

    @Suppress("UNCHECKED_CAST")
    fun wrap(typeId: String, items: List<*>): Any =
        when (typeId) {
            "message" -> MessageWrap(items as List<Message>)
            "document" -> DocumentWrap(items as List<Document>)
            "telemetry" -> TelemetryWrap(items as List<Telemetry>)
            "strings" -> StringsWrap(items as List<Strings>)
            "event" -> EventWrap(items as List<Event>)
            else -> throw IllegalArgumentException(typeId)
        }

    fun unwrap(typeId: String, decoded: Any): Any =
        when (typeId) {
            "message" -> (decoded as MessageWrap).items
            "document" -> (decoded as DocumentWrap).items
            "telemetry" -> (decoded as TelemetryWrap).items
            "strings" -> (decoded as StringsWrap).items
            "event" -> (decoded as EventWrap).items
            else -> decoded
        }
}
