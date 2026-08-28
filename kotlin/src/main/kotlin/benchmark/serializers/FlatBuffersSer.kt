package benchmark.serializers

import benchmark.fb.BatchDocument
import benchmark.fb.BatchEvent
import benchmark.fb.BatchMessage
import benchmark.fb.BatchStrings
import benchmark.fb.BatchTelemetry
import benchmark.fb.DocumentItem
import benchmark.fb.DocumentMeta
import benchmark.fb.EventAttr
import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.Event
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import com.google.flatbuffers.FlatBufferBuilder
import java.nio.ByteBuffer

/**
 * Official FlatBuffers Java/Kotlin runtime + generated tables from the suite `.fbs`.
 *
 * Hot path: reuse [FlatBufferBuilder]; timed pack → `finish` / `getRootAs*`.
 */
class FlatBuffersSer : BenchSerializer {
    private val builder = FlatBufferBuilder(1024)
    private var typeId: String = ""
    private var batch = false

    override fun name() = "flatbuffers"

    override fun version() = Versions.of(FlatBufferBuilder::class.java)

    override fun streamMode() = "adapted"

    override fun nativeKind() = "schema"

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        builder.clear()
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        builder.clear()
        val root = if (batch) packList(fx.value as List<*>) else packOne(fx.value)
        builder.finish(root)
        val bb = builder.dataBuffer()
        val out = ByteArray(bb.remaining())
        bb.get(out)
        return out
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val bb = ByteBuffer.wrap(data)
        return if (batch) unpackList(bb) else unpackOne(bb)
    }

    private fun packOne(value: Any): Int =
        when (typeId) {
            "message" -> packMessage(value as Message)
            "document" -> packDocument(value as Document)
            "telemetry" -> packTelemetry(value as Telemetry)
            "strings" -> packStrings(value as Strings)
            "event" -> packEvent(value as Event)
            else -> throw IllegalArgumentException(typeId)
        }

    private fun packList(list: List<*>): Int {
        val offs = IntArray(list.size) { packOne(list[it]!!) }
        return when (typeId) {
            "message" -> BatchMessage.createBatchMessage(builder, BatchMessage.createItemsVector(builder, offs))
            "document" -> BatchDocument.createBatchDocument(builder, BatchDocument.createItemsVector(builder, offs))
            "telemetry" -> BatchTelemetry.createBatchTelemetry(builder, BatchTelemetry.createItemsVector(builder, offs))
            "strings" -> BatchStrings.createBatchStrings(builder, BatchStrings.createItemsVector(builder, offs))
            "event" -> BatchEvent.createBatchEvent(builder, BatchEvent.createItemsVector(builder, offs))
            else -> throw IllegalArgumentException(typeId)
        }
    }

    private fun packMessage(m: Message): Int {
        val s1 = builder.createString(m.fString)
        val s2 = builder.createString(m.fString2)
        return benchmark.fb.Message.createMessage(
            builder, m.fBool, m.fInt32, m.fInt64, m.fFloat64, s1, m.fBool2, m.fInt32_2, s2,
        )
    }

    private fun packDocument(d: Document): Int {
        val id = builder.createString(d.id)
        val meta =
            DocumentMeta.createDocumentMeta(builder, builder.createString(d.meta.region), d.meta.version)
        val itemOffs =
            IntArray(d.items.size) { i ->
                val it = d.items[i]
                DocumentItem.createDocumentItem(builder, builder.createString(it.sku), it.qty, it.priceMinor)
            }
        return benchmark.fb.Document.createDocument(
            builder, id, d.status, meta, benchmark.fb.Document.createItemsVector(builder, itemOffs),
        )
    }

    private fun packTelemetry(t: Telemetry): Int {
        val src = builder.createString(t.source)
        val tagOffs = IntArray(t.tags.size) { builder.createString(t.tags[it]) }
        val tagsOff = benchmark.fb.Telemetry.createTagsVector(builder, tagOffs)
        val valsOff = benchmark.fb.Telemetry.createValuesVector(builder, t.values.toDoubleArray())
        return benchmark.fb.Telemetry.createTelemetry(builder, src, t.ts, tagsOff, valsOff)
    }

    private fun packStrings(s: Strings): Int {
        val offs = IntArray(s.items.size) { builder.createString(s.items[it]) }
        return benchmark.fb.Strings.createStrings(builder, benchmark.fb.Strings.createItemsVector(builder, offs))
    }

    private fun packEvent(e: Event): Int {
        val id = builder.createString(e.eventId)
        val typ = builder.createString(e.eventType)
        val prod = builder.createString(e.producer)
        val attrOffs =
            IntArray(e.attrs.size) { i ->
                val a = e.attrs[i]
                EventAttr.createEventAttr(builder, builder.createString(a.key), builder.createString(a.value))
            }
        return benchmark.fb.Event.createEvent(
            builder, id, typ, e.occurredAt, prod, benchmark.fb.Event.createAttrsVector(builder, attrOffs),
        )
    }

    private fun unpackOne(bb: ByteBuffer): Any =
        when (typeId) {
            "message" -> fromMessage(benchmark.fb.Message.getRootAsMessage(bb))
            "document" -> fromDocument(benchmark.fb.Document.getRootAsDocument(bb))
            "telemetry" -> fromTelemetry(benchmark.fb.Telemetry.getRootAsTelemetry(bb))
            "strings" -> fromStrings(benchmark.fb.Strings.getRootAsStrings(bb))
            "event" -> fromEvent(benchmark.fb.Event.getRootAsEvent(bb))
            else -> throw IllegalArgumentException(typeId)
        }

    private fun unpackList(bb: ByteBuffer): Any =
        when (typeId) {
            "message" -> {
                val b = BatchMessage.getRootAsBatchMessage(bb)
                MutableList(b.itemsLength()) { fromMessage(b.items(it)!!) }
            }
            "document" -> {
                val b = BatchDocument.getRootAsBatchDocument(bb)
                MutableList(b.itemsLength()) { fromDocument(b.items(it)!!) }
            }
            "telemetry" -> {
                val b = BatchTelemetry.getRootAsBatchTelemetry(bb)
                MutableList(b.itemsLength()) { fromTelemetry(b.items(it)!!) }
            }
            "strings" -> {
                val b = BatchStrings.getRootAsBatchStrings(bb)
                MutableList(b.itemsLength()) { fromStrings(b.items(it)!!) }
            }
            "event" -> {
                val b = BatchEvent.getRootAsBatchEvent(bb)
                MutableList(b.itemsLength()) { fromEvent(b.items(it)!!) }
            }
            else -> throw IllegalArgumentException(typeId)
        }

    private fun fromMessage(m: benchmark.fb.Message) =
        Message(m.fBool(), m.fInt32(), m.fInt64(), m.fFloat64(), m.fString() ?: "", m.fBool2(), m.fInt322(), m.fString2() ?: "")

    private fun fromDocument(d: benchmark.fb.Document): Document {
        val metaSrc = d.meta()
        val meta = benchmark.model.v2.DocumentMeta(metaSrc?.region() ?: "", metaSrc?.version() ?: 0)
        val items =
            MutableList(d.itemsLength()) { i ->
                val src = d.items(i)!!
                benchmark.model.v2.DocumentItem(src.sku() ?: "", src.qty(), src.priceMinor())
            }
        return Document(d.id() ?: "", d.status(), meta, items)
    }

    private fun fromTelemetry(t: benchmark.fb.Telemetry): Telemetry {
        val tags = MutableList(t.tagsLength()) { t.tags(it) ?: "" }
        val vals = MutableList(t.valuesLength()) { t.values(it) }
        return Telemetry(t.source() ?: "", t.ts(), tags, vals)
    }

    private fun fromStrings(s: benchmark.fb.Strings) =
        Strings(MutableList(s.itemsLength()) { s.items(it) ?: "" })

    private fun fromEvent(e: benchmark.fb.Event): Event {
        val attrs =
            MutableList(e.attrsLength()) { i ->
                val a = e.attrs(i)!!
                benchmark.model.v2.EventAttr(a.key() ?: "", a.value() ?: "")
            }
        return Event(e.eventId() ?: "", e.eventType() ?: "", e.occurredAt(), e.producer() ?: "", attrs)
    }
}
