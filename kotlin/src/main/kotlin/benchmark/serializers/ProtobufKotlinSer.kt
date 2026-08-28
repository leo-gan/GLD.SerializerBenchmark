package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.DocumentItem
import benchmark.model.v2.DocumentMeta
import benchmark.model.v2.Event
import benchmark.model.v2.EventAttr
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import benchmark.v2.batchDocument
import benchmark.v2.batchEvent
import benchmark.v2.batchMessage
import benchmark.v2.batchStrings
import benchmark.v2.batchTelemetry
import benchmark.v2.document
import benchmark.v2.documentItem
import benchmark.v2.documentMeta
import benchmark.v2.event
import benchmark.v2.eventAttr
import benchmark.v2.message
import benchmark.v2.strings
import benchmark.v2.telemetry
import com.google.protobuf.MessageLite
import com.google.protobuf.Parser
import java.io.InputStream
import java.io.OutputStream

/**
 * Protocol Buffers Kotlin generated API (`protobuf-kotlin` + `protoc --kotlin_out`).
 *
 * Timed path uses the Kotlin DSL builders (`message { … }`) then `toByteArray` / `parseFrom`.
 * Distinct from [ProtobufSer], which uses the Java `newBuilder()` API.
 */
class ProtobufKotlinSer : BenchSerializer {
    private lateinit var parser: Parser<out MessageLite>
    private var typeId: String = ""
    private var batch = false

    override fun name() = "protobuf-kotlin"

    override fun version() = Versions.of("com.google.protobuf.kotlin.DslProxy")

    override fun streamMode() = "native"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        parser = toProto(fx).parserForType
    }

    override fun serializeBytes(fx: Fixture): ByteArray = toProto(fx).toByteArray()

    override fun deserializeBytes(data: ByteArray): Any = fromProto(parser.parseFrom(data))

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val msg = toProto(fx)
        msg.writeTo(out)
        return msg.serializedSize
    }

    override fun deserializeStream(input: InputStream): Any = fromProto(parser.parseFrom(input))

    private fun toProto(fx: Fixture): MessageLite {
        if (fx.value is List<*>) {
            return when (fx.name) {
                "message" -> batchMessage { fx.value.forEach { items += toMessage(it as Message) } }
                "document" -> batchDocument { fx.value.forEach { items += toDocument(it as Document) } }
                "telemetry" -> batchTelemetry { fx.value.forEach { items += toTelemetry(it as Telemetry) } }
                "strings" -> batchStrings { fx.value.forEach { items += toStrings(it as Strings) } }
                "event" -> batchEvent { fx.value.forEach { items += toEvent(it as Event) } }
                else -> throw IllegalArgumentException(fx.name)
            }
        }
        return when (fx.name) {
            "message" -> toMessage(fx.value as Message)
            "document" -> toDocument(fx.value as Document)
            "telemetry" -> toTelemetry(fx.value as Telemetry)
            "strings" -> toStrings(fx.value as Strings)
            "event" -> toEvent(fx.value as Event)
            else -> throw IllegalArgumentException(fx.name)
        }
    }

    private fun fromProto(ml: MessageLite): Any {
        if (batch) {
            return when (typeId) {
                "message" -> (ml as benchmark.v2.BatchMessage).itemsList.map { fromMessage(it) }.toMutableList()
                "document" -> (ml as benchmark.v2.BatchDocument).itemsList.map { fromDocument(it) }.toMutableList()
                "telemetry" -> (ml as benchmark.v2.BatchTelemetry).itemsList.map { fromTelemetry(it) }.toMutableList()
                "strings" -> (ml as benchmark.v2.BatchStrings).itemsList.map { fromStrings(it) }.toMutableList()
                "event" -> (ml as benchmark.v2.BatchEvent).itemsList.map { fromEvent(it) }.toMutableList()
                else -> ml
            }
        }
        return when (typeId) {
            "message" -> fromMessage(ml as benchmark.v2.Message)
            "document" -> fromDocument(ml as benchmark.v2.Document)
            "telemetry" -> fromTelemetry(ml as benchmark.v2.Telemetry)
            "strings" -> fromStrings(ml as benchmark.v2.Strings)
            "event" -> fromEvent(ml as benchmark.v2.Event)
            else -> ml
        }
    }

    private fun toMessage(m: Message) =
        message {
            fBool = m.fBool
            fInt32 = m.fInt32
            fInt64 = m.fInt64
            fFloat64 = m.fFloat64
            fString = m.fString
            fBool2 = m.fBool2
            fInt322 = m.fInt32_2
            fString2 = m.fString2
        }

    private fun fromMessage(m: benchmark.v2.Message) =
        Message(m.fBool, m.fInt32, m.fInt64, m.fFloat64, m.fString, m.fBool2, m.fInt322, m.fString2)

    private fun toDocument(d: Document) =
        document {
            id = d.id
            status = d.status
            meta = documentMeta {
                region = d.meta.region
                version = d.meta.version
            }
            d.items.forEach { it ->
                items += documentItem {
                    sku = it.sku
                    qty = it.qty
                    priceMinor = it.priceMinor
                }
            }
        }

    private fun fromDocument(d: benchmark.v2.Document): Document {
        val meta =
            if (d.hasMeta()) DocumentMeta(d.meta.region, d.meta.version) else DocumentMeta()
        val items = d.itemsList.map { DocumentItem(it.sku, it.qty, it.priceMinor) }.toMutableList()
        return Document(d.id, d.status, meta, items)
    }

    private fun toTelemetry(t: Telemetry) =
        telemetry {
            source = t.source
            ts = t.ts
            tags += t.tags
            values += t.values
        }

    private fun fromTelemetry(t: benchmark.v2.Telemetry) =
        Telemetry(t.source, t.ts, t.tagsList.toMutableList(), t.valuesList.toMutableList())

    private fun toStrings(s: Strings) = strings { items += s.items }

    private fun fromStrings(s: benchmark.v2.Strings) = Strings(s.itemsList.toMutableList())

    private fun toEvent(e: Event) =
        event {
            eventId = e.eventId
            eventType = e.eventType
            occurredAt = e.occurredAt
            producer = e.producer
            e.attrs.forEach { a ->
                attrs += eventAttr {
                    key = a.key
                    value = a.value
                }
            }
        }

    private fun fromEvent(e: benchmark.v2.Event) =
        Event(
            e.eventId,
            e.eventType,
            e.occurredAt,
            e.producer,
            e.attrsList.map { EventAttr(it.key, it.value) }.toMutableList(),
        )
}
