package benchmark.serializers

import benchmark.model.v2.Document
import benchmark.model.v2.Event
import benchmark.model.v2.Message
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.Strings
import benchmark.model.v2.TableRow
import benchmark.model.v2.Telemetry
import com.fasterxml.jackson.core.type.TypeReference
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.serializer

/** Helpers for typed empty targets, list TypeReferences, and kotlinx serializers. */
object TypeUtil {
    val ORIGINAL_IDS = setOf("message", "document", "telemetry", "strings", "event")
    val COLUMNAR_IDS = setOf("table", "table_project", "nested_table", "signal")

    fun originalOrColumnar(id: String): Boolean = id in ORIGINAL_IDS || id in COLUMNAR_IDS

    fun isList(value: Any): Boolean = value is List<*>

    fun elementClass(value: Any): Class<*> {
        if (value is List<*> && value.isNotEmpty()) {
            return value[0]!!.javaClass
        }
        return value.javaClass
    }

    fun listTypeRef(prototype: Any): TypeReference<*> {
        val list = prototype as? List<*> ?: throw IllegalArgumentException("expected List prototype")
        if (list.isEmpty()) throw IllegalArgumentException("expected non-empty List prototype")
        return when (list[0]) {
            is Message -> object : TypeReference<List<Message>>() {}
            is Document -> object : TypeReference<List<Document>>() {}
            is Telemetry -> object : TypeReference<List<Telemetry>>() {}
            is Strings -> object : TypeReference<List<Strings>>() {}
            is Event -> object : TypeReference<List<Event>>() {}
            is TableRow -> object : TypeReference<List<TableRow>>() {}
            is NestedRow -> object : TypeReference<List<NestedRow>>() {}
            is Signal -> object : TypeReference<List<Signal>>() {}
            else -> object : TypeReference<List<Any>>() {}
        }
    }

    @Suppress("UNCHECKED_CAST")
    fun kotlinxSerializer(value: Any): KSerializer<Any> {
        if (value is List<*>) {
            val first = value.firstOrNull() ?: throw IllegalArgumentException("empty list")
            val el = elementSerializer(first)
            return ListSerializer(el) as KSerializer<Any>
        }
        return elementSerializer(value) as KSerializer<Any>
    }

    @Suppress("UNCHECKED_CAST")
    fun elementSerializer(value: Any): KSerializer<Any> {
        return when (value) {
            is Message -> Message.serializer() as KSerializer<Any>
            is Document -> Document.serializer() as KSerializer<Any>
            is Telemetry -> Telemetry.serializer() as KSerializer<Any>
            is Strings -> Strings.serializer() as KSerializer<Any>
            is Event -> Event.serializer() as KSerializer<Any>
            is TableRow -> TableRow.serializer() as KSerializer<Any>
            is NestedRow -> NestedRow.serializer() as KSerializer<Any>
            is Signal -> Signal.serializer() as KSerializer<Any>
            else -> serializer(value::class.java) as KSerializer<Any>
        }
    }
}
