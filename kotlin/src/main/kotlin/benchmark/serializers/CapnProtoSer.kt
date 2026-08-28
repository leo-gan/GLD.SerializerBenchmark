package benchmark.serializers

import benchmark.capnp.BenchmarkCapnp
import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.DocumentItem
import benchmark.model.v2.DocumentMeta
import benchmark.model.v2.Event
import benchmark.model.v2.EventAttr
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import org.capnproto.ArrayInputStream
import org.capnproto.ArrayOutputStream
import org.capnproto.MessageBuilder
import org.capnproto.MessageReader
import org.capnproto.Serialize
import org.capnproto.Text
import org.capnproto.TextList
import java.nio.ByteBuffer
import java.nio.channels.Channels

/**
 * Official Cap'n Proto Java runtime (`org.capnproto:runtime`) from Kotlin,
 * plus generated [BenchmarkCapnp] from the suite `.capnp` schema.
 */
class CapnProtoSer : BenchSerializer {
    private var typeId: String = ""
    private var batch = false
    private var writeBufSize = 64 * 1024

    override fun name() = "capnproto"

    override fun version() = Versions.of(Serialize::class.java)

    override fun streamMode() = "adapted"

    override fun nativeKind() = "schema"

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        writeBufSize = sizedBuffer(fx)
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val mb = MessageBuilder()
        fill(mb, fx.value)
        val os = ArrayOutputStream(ByteBuffer.allocate(writeBufSize))
        Serialize.write(os, mb)
        val bb = os.writeBuffer.duplicate()
        bb.flip()
        val out = ByteArray(bb.remaining())
        bb.get(out)
        return out
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val reader = Serialize.read(ArrayInputStream(ByteBuffer.wrap(data)))
        return readRoot(reader)
    }

    override fun serializeStream(fx: Fixture, out: java.io.OutputStream): Int {
        val raw = serializeBytes(fx)
        out.write(raw)
        return raw.size
    }

    override fun deserializeStream(input: java.io.InputStream): Any {
        val reader = Serialize.read(Channels.newChannel(input))
        return readRoot(reader)
    }

    private fun sizedBuffer(fx: Fixture): Int {
        val mb = MessageBuilder()
        fill(mb, fx.value)
        var size = 64 * 1024
        while (size <= 16 * 1024 * 1024) {
            try {
                Serialize.write(ArrayOutputStream(ByteBuffer.allocate(size)), mb)
                return size
            } catch (_: Exception) {
                size *= 2
            }
        }
        throw IllegalStateException("capnproto payload exceeds 16 MiB")
    }

    private fun fill(mb: MessageBuilder, value: Any) {
        if (batch) {
            fillBatch(mb, value as List<*>)
            return
        }
        when (typeId) {
            "message" -> fillMessage(mb.initRoot(BenchmarkCapnp.Message.factory), value as Message)
            "document" -> fillDocument(mb.initRoot(BenchmarkCapnp.Document.factory), value as Document)
            "telemetry" -> fillTelemetry(mb.initRoot(BenchmarkCapnp.Telemetry.factory), value as Telemetry)
            "strings" -> fillStrings(mb.initRoot(BenchmarkCapnp.Strings.factory), value as Strings)
            "event" -> fillEvent(mb.initRoot(BenchmarkCapnp.Event.factory), value as Event)
            else -> throw IllegalArgumentException(typeId)
        }
    }

    private fun fillBatch(mb: MessageBuilder, list: List<*>) {
        when (typeId) {
            "message" -> {
                val items = mb.initRoot(BenchmarkCapnp.BatchMessage.factory).initItems(list.size)
                for (i in list.indices) fillMessage(items[i], list[i] as Message)
            }
            "document" -> {
                val items = mb.initRoot(BenchmarkCapnp.BatchDocument.factory).initItems(list.size)
                for (i in list.indices) fillDocument(items[i], list[i] as Document)
            }
            "telemetry" -> {
                val items = mb.initRoot(BenchmarkCapnp.BatchTelemetry.factory).initItems(list.size)
                for (i in list.indices) fillTelemetry(items[i], list[i] as Telemetry)
            }
            "strings" -> {
                val items = mb.initRoot(BenchmarkCapnp.BatchStrings.factory).initItems(list.size)
                for (i in list.indices) fillStrings(items[i], list[i] as Strings)
            }
            "event" -> {
                val items = mb.initRoot(BenchmarkCapnp.BatchEvent.factory).initItems(list.size)
                for (i in list.indices) fillEvent(items[i], list[i] as Event)
            }
            else -> throw IllegalArgumentException(typeId)
        }
    }

    private fun fillMessage(b: BenchmarkCapnp.Message.Builder, m: Message) {
        b.fBool = m.fBool
        b.fInt32 = m.fInt32
        b.fInt64 = m.fInt64
        b.fFloat64 = m.fFloat64
        b.setFString(m.fString)
        b.fBool2 = m.fBool2
        b.fInt32B = m.fInt32_2
        b.setFStringB(m.fString2)
    }

    private fun fillDocument(b: BenchmarkCapnp.Document.Builder, d: Document) {
        b.setId(d.id)
        b.status = d.status
        val mb = b.initMeta()
        mb.setRegion(d.meta.region)
        mb.version = d.meta.version
        val ib = b.initItems(d.items.size)
        for (i in d.items.indices) {
            val it = d.items[i]
            val slot = ib[i]
            slot.setSku(it.sku)
            slot.qty = it.qty
            slot.priceMinor = it.priceMinor
        }
    }

    private fun fillTelemetry(b: BenchmarkCapnp.Telemetry.Builder, t: Telemetry) {
        b.setSource(t.source)
        b.ts = t.ts
        val tb: TextList.Builder = b.initTags(t.tags.size)
        for (i in t.tags.indices) tb.set(i, Text.Reader(t.tags[i]))
        val vb = b.initValues(t.values.size)
        for (i in t.values.indices) vb.set(i, t.values[i])
    }

    private fun fillStrings(b: BenchmarkCapnp.Strings.Builder, s: Strings) {
        val tb = b.initItems(s.items.size)
        for (i in s.items.indices) tb.set(i, Text.Reader(s.items[i]))
    }

    private fun fillEvent(b: BenchmarkCapnp.Event.Builder, e: Event) {
        b.setEventId(e.eventId)
        b.setEventType(e.eventType)
        b.occurredAt = e.occurredAt
        b.setProducer(e.producer)
        val ab = b.initAttrs(e.attrs.size)
        for (i in e.attrs.indices) {
            val a = e.attrs[i]
            val slot = ab[i]
            slot.setKey(a.key)
            slot.setValue(a.value)
        }
    }

    private fun readRoot(reader: MessageReader): Any {
        if (batch) return readBatch(reader)
        return when (typeId) {
            "message" -> fromMessage(reader.getRoot(BenchmarkCapnp.Message.factory))
            "document" -> fromDocument(reader.getRoot(BenchmarkCapnp.Document.factory))
            "telemetry" -> fromTelemetry(reader.getRoot(BenchmarkCapnp.Telemetry.factory))
            "strings" -> fromStrings(reader.getRoot(BenchmarkCapnp.Strings.factory))
            "event" -> fromEvent(reader.getRoot(BenchmarkCapnp.Event.factory))
            else -> throw IllegalArgumentException(typeId)
        }
    }

    private fun readBatch(reader: MessageReader): Any =
        when (typeId) {
            "message" -> {
                val items = reader.getRoot(BenchmarkCapnp.BatchMessage.factory).items
                MutableList(items.size()) { fromMessage(items[it]) }
            }
            "document" -> {
                val items = reader.getRoot(BenchmarkCapnp.BatchDocument.factory).items
                MutableList(items.size()) { fromDocument(items[it]) }
            }
            "telemetry" -> {
                val items = reader.getRoot(BenchmarkCapnp.BatchTelemetry.factory).items
                MutableList(items.size()) { fromTelemetry(items[it]) }
            }
            "strings" -> {
                val items = reader.getRoot(BenchmarkCapnp.BatchStrings.factory).items
                MutableList(items.size()) { fromStrings(items[it]) }
            }
            "event" -> {
                val items = reader.getRoot(BenchmarkCapnp.BatchEvent.factory).items
                MutableList(items.size()) { fromEvent(items[it]) }
            }
            else -> throw IllegalArgumentException(typeId)
        }

    private fun fromMessage(r: BenchmarkCapnp.Message.Reader) =
        Message(r.fBool, r.fInt32, r.fInt64, r.fFloat64, r.fString.toString(), r.fBool2, r.fInt32B, r.fStringB.toString())

    private fun fromDocument(r: BenchmarkCapnp.Document.Reader): Document {
        val meta =
            if (r.hasMeta()) DocumentMeta(r.meta.region.toString(), r.meta.version) else DocumentMeta()
        val itemsIn = r.items
        val items =
            MutableList(itemsIn.size()) { i ->
                val it = itemsIn[i]
                DocumentItem(it.sku.toString(), it.qty, it.priceMinor)
            }
        return Document(r.id.toString(), r.status, meta, items)
    }

    private fun fromTelemetry(r: BenchmarkCapnp.Telemetry.Reader): Telemetry {
        val tagsIn = r.tags
        val tags = MutableList(tagsIn.size()) { tagsIn[it].toString() }
        val valsIn = r.values
        val vals = MutableList(valsIn.size()) { valsIn[it] }
        return Telemetry(r.source.toString(), r.ts, tags, vals)
    }

    private fun fromStrings(r: BenchmarkCapnp.Strings.Reader): Strings {
        val itemsIn = r.items
        return Strings(MutableList(itemsIn.size()) { itemsIn[it].toString() })
    }

    private fun fromEvent(r: BenchmarkCapnp.Event.Reader): Event {
        val attrsIn = r.attrs
        val attrs =
            MutableList(attrsIn.size()) { i ->
                val a = attrsIn[i]
                EventAttr(a.key.toString(), a.value.toString())
            }
        return Event(r.eventId.toString(), r.eventType.toString(), r.occurredAt, r.producer.toString(), attrs)
    }
}
