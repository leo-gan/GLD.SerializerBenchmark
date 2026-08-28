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
    data class MessageWrap(val batch: List<Message>)

    @Serializable
    data class DocumentWrap(val batch: List<Document>)

    @Serializable
    data class TelemetryWrap(val batch: List<Telemetry>)

    @Serializable
    data class StringsWrap(val batch: List<Strings>)

    @Serializable
    data class EventWrap(val batch: List<Event>)

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
            "message" -> (decoded as MessageWrap).batch
            "document" -> (decoded as DocumentWrap).batch
            "telemetry" -> (decoded as TelemetryWrap).batch
            "strings" -> (decoded as StringsWrap).batch
            "event" -> (decoded as EventWrap).batch
            else -> decoded
        }
}
