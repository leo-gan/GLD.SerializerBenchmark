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
import ion.Catalog
import ion.EncodeOptions
import ion.IonDoc
import ion.K_LIST
import ion.K_STRUCT
import ion.asBool
import ion.asF64
import ion.asI64
import ion.asString
import ion.decode
import ion.encode
import ion.fieldName

/**
 * gld-ion 0.2.0 binary documents on the vendored `ion.IonDoc` codec.
 *
 * Suite values are structs (a top-level list when N>1). Graph is not a tree, so it is skipped.
 * [prepare] records the type and reuses [EncodeOptions] / [Catalog]; timed calls only build a
 * document and call [encode] / [decode].
 */
class GldIonSer : BenchSerializer {
    private val options = EncodeOptions(binary = true, pretty = false, version = 10)
    private val cat = Catalog()
    private var typeId: String = ""
    private var batch = false

    override fun name() = "gld-ion"

    override fun version() = "0.2.0"

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun supports(testDataName: String): Boolean =
        testDataName != "graph" && testDataName in TypeUtil.ORIGINAL_IDS

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        requireReady()
        val doc = IonDoc()
        val root = if (batch) writeList(doc, fx.value as List<*>) else writeOne(doc, fx.value)
        doc.addTop(root)
        return encode(doc, options, cat)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        requireReady()
        val doc = decode(data, cat)
        if (doc.top.isEmpty()) throw IllegalStateException("empty ion datagram")
        val id = doc.top[0]
        return if (batch) readList(doc, id) else readOne(doc, id)
    }

    private fun requireReady() {
        if (typeId.isEmpty()) throw IllegalStateException("prepare() was not called")
    }

    private fun writeList(doc: IonDoc, values: List<*>): Int {
        val arr = doc.startContainer(K_LIST)
        for (value in values) {
            doc.addChild(arr, writeOne(doc, value!!), -1)
        }
        return arr
    }

    private fun writeOne(doc: IonDoc, value: Any): Int =
        when (typeId) {
            "message" -> writeMessage(doc, value as Message)
            "document" -> writeDocument(doc, value as Document)
            "telemetry" -> writeTelemetry(doc, value as Telemetry)
            "strings" -> writeStrings(doc, value as Strings)
            "event" -> writeEvent(doc, value as Event)
            else -> throw IllegalArgumentException(typeId)
        }

    private fun readList(doc: IonDoc, id: Int): MutableList<Any> {
        val node = doc.nodes[id]
        if (node.kind != K_LIST) throw IllegalStateException("expected ion list")
        val out = ArrayList<Any>(node.nchild)
        var i = 0
        while (i < node.nchild) {
            out.add(readOne(doc, doc.childAt(id, i)))
            i++
        }
        return out
    }

    private fun readOne(doc: IonDoc, id: Int): Any =
        when (typeId) {
            "message" -> readMessage(doc, id)
            "document" -> readDocument(doc, id)
            "telemetry" -> readTelemetry(doc, id)
            "strings" -> readStrings(doc, id)
            "event" -> readEvent(doc, id)
            else -> throw IllegalArgumentException(typeId)
        }

    private fun writeMessage(doc: IonDoc, m: Message): Int {
        val obj = doc.startContainer(K_STRUCT)
        put(doc, obj, "fBool", doc.addBool(m.fBool))
        put(doc, obj, "fInt32", doc.addI64(m.fInt32.toLong()))
        put(doc, obj, "fInt64", doc.addI64(m.fInt64))
        put(doc, obj, "fFloat64", doc.addFloat(8, m.fFloat64.toRawBits()))
        put(doc, obj, "fString", doc.addString(m.fString))
        put(doc, obj, "fBool2", doc.addBool(m.fBool2))
        put(doc, obj, "fInt32_2", doc.addI64(m.fInt32_2.toLong()))
        put(doc, obj, "fString2", doc.addString(m.fString2))
        return obj
    }

    private fun readMessage(doc: IonDoc, id: Int): Message =
        Message(
            fBool = asBool(doc, field(doc, id, "fBool")),
            fInt32 = asI64(doc, field(doc, id, "fInt32")).toInt(),
            fInt64 = asI64(doc, field(doc, id, "fInt64")),
            fFloat64 = asF64(doc, field(doc, id, "fFloat64")),
            fString = asString(doc, field(doc, id, "fString")),
            fBool2 = asBool(doc, field(doc, id, "fBool2")),
            fInt32_2 = asI64(doc, field(doc, id, "fInt32_2")).toInt(),
            fString2 = asString(doc, field(doc, id, "fString2")),
        )

    private fun writeDocument(doc: IonDoc, d: Document): Int {
        val obj = doc.startContainer(K_STRUCT)
        put(doc, obj, "id", doc.addString(d.id))
        put(doc, obj, "status", doc.addI64(d.status.toLong()))
        val meta = doc.startContainer(K_STRUCT)
        put(doc, meta, "region", doc.addString(d.meta.region))
        put(doc, meta, "version", doc.addI64(d.meta.version.toLong()))
        put(doc, obj, "meta", meta)
        val items = doc.startContainer(K_LIST)
        for (item in d.items) {
            doc.addChild(items, writeItem(doc, item), -1)
        }
        put(doc, obj, "items", items)
        return obj
    }

    private fun writeItem(doc: IonDoc, item: DocumentItem): Int {
        val obj = doc.startContainer(K_STRUCT)
        put(doc, obj, "sku", doc.addString(item.sku))
        put(doc, obj, "qty", doc.addI64(item.qty.toLong()))
        put(doc, obj, "priceMinor", doc.addI64(item.priceMinor))
        return obj
    }

    private fun readDocument(doc: IonDoc, id: Int): Document {
        val metaId = field(doc, id, "meta")
        val itemsId = field(doc, id, "items")
        val itemsNode = doc.nodes[itemsId]
        if (itemsNode.kind != K_LIST) throw IllegalStateException("expected ion list")
        val items = ArrayList<DocumentItem>(itemsNode.nchild)
        var i = 0
        while (i < itemsNode.nchild) {
            val item = doc.childAt(itemsId, i)
            items.add(
                DocumentItem(
                    sku = asString(doc, field(doc, item, "sku")),
                    qty = asI64(doc, field(doc, item, "qty")).toInt(),
                    priceMinor = asI64(doc, field(doc, item, "priceMinor")),
                ),
            )
            i++
        }
        return Document(
            id = asString(doc, field(doc, id, "id")),
            status = asI64(doc, field(doc, id, "status")).toInt(),
            meta = DocumentMeta(
                region = asString(doc, field(doc, metaId, "region")),
                version = asI64(doc, field(doc, metaId, "version")).toInt(),
            ),
            items = items,
        )
    }

    private fun writeTelemetry(doc: IonDoc, t: Telemetry): Int {
        val obj = doc.startContainer(K_STRUCT)
        put(doc, obj, "source", doc.addString(t.source))
        put(doc, obj, "ts", doc.addI64(t.ts))
        val tags = doc.startContainer(K_LIST)
        for (tag in t.tags) {
            doc.addChild(tags, doc.addString(tag), -1)
        }
        put(doc, obj, "tags", tags)
        val values = doc.startContainer(K_LIST)
        for (value in t.values) {
            doc.addChild(values, doc.addFloat(8, value.toRawBits()), -1)
        }
        put(doc, obj, "values", values)
        return obj
    }

    private fun readTelemetry(doc: IonDoc, id: Int): Telemetry =
        Telemetry(
            source = asString(doc, field(doc, id, "source")),
            ts = asI64(doc, field(doc, id, "ts")),
            tags = readStringList(doc, field(doc, id, "tags")),
            values = readDoubleList(doc, field(doc, id, "values")),
        )

    private fun writeStrings(doc: IonDoc, s: Strings): Int {
        val obj = doc.startContainer(K_STRUCT)
        val items = doc.startContainer(K_LIST)
        for (item in s.items) {
            doc.addChild(items, doc.addString(item), -1)
        }
        put(doc, obj, "items", items)
        return obj
    }

    private fun readStrings(doc: IonDoc, id: Int): Strings =
        Strings(items = readStringList(doc, field(doc, id, "items")))

    private fun writeEvent(doc: IonDoc, ev: Event): Int {
        val obj = doc.startContainer(K_STRUCT)
        put(doc, obj, "eventId", doc.addString(ev.eventId))
        put(doc, obj, "eventType", doc.addString(ev.eventType))
        put(doc, obj, "occurredAt", doc.addI64(ev.occurredAt))
        put(doc, obj, "producer", doc.addString(ev.producer))
        val attrs = doc.startContainer(K_LIST)
        for (attr in ev.attrs) {
            val one = doc.startContainer(K_STRUCT)
            put(doc, one, "key", doc.addString(attr.key))
            put(doc, one, "value", doc.addString(attr.value))
            doc.addChild(attrs, one, -1)
        }
        put(doc, obj, "attrs", attrs)
        return obj
    }

    private fun readEvent(doc: IonDoc, id: Int): Event {
        val attrsId = field(doc, id, "attrs")
        val node = doc.nodes[attrsId]
        if (node.kind != K_LIST) throw IllegalStateException("expected ion list")
        val attrs = ArrayList<EventAttr>(node.nchild)
        var i = 0
        while (i < node.nchild) {
            val attr = doc.childAt(attrsId, i)
            attrs.add(
                EventAttr(
                    key = asString(doc, field(doc, attr, "key")),
                    value = asString(doc, field(doc, attr, "value")),
                ),
            )
            i++
        }
        return Event(
            eventId = asString(doc, field(doc, id, "eventId")),
            eventType = asString(doc, field(doc, id, "eventType")),
            occurredAt = asI64(doc, field(doc, id, "occurredAt")),
            producer = asString(doc, field(doc, id, "producer")),
            attrs = attrs,
        )
    }

    private fun readStringList(doc: IonDoc, id: Int): MutableList<String> {
        val node = doc.nodes[id]
        if (node.kind != K_LIST) throw IllegalStateException("expected ion list")
        val out = ArrayList<String>(node.nchild)
        var i = 0
        while (i < node.nchild) {
            out.add(asString(doc, doc.childAt(id, i)))
            i++
        }
        return out
    }

    private fun readDoubleList(doc: IonDoc, id: Int): MutableList<Double> {
        val node = doc.nodes[id]
        if (node.kind != K_LIST) throw IllegalStateException("expected ion list")
        val out = ArrayList<Double>(node.nchild)
        var i = 0
        while (i < node.nchild) {
            out.add(asF64(doc, doc.childAt(id, i)))
            i++
        }
        return out
    }

    private fun put(doc: IonDoc, parent: Int, name: String, child: Int) {
        doc.addChild(parent, child, doc.symbolRef(name))
    }

    private fun field(doc: IonDoc, obj: Int, name: String): Int {
        val node = doc.nodes[obj]
        var i = 0
        while (i < node.nchild) {
            if (fieldName(doc, obj, i) == name) return doc.childAt(obj, i)
            i++
        }
        throw IllegalStateException("missing ion field $name")
    }
}
