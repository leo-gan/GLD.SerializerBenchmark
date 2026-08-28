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
import org.apache.thrift.protocol.TCompactProtocol
import org.apache.thrift.protocol.TField
import org.apache.thrift.protocol.TList
import org.apache.thrift.protocol.TProtocol
import org.apache.thrift.protocol.TStruct
import org.apache.thrift.protocol.TType
import org.apache.thrift.transport.TMemoryBuffer
import org.apache.thrift.transport.TMemoryInputTransport

/**
 * Apache Thrift compact protocol — official libthrift used from Kotlin.
 *
 * Field ids match the shared protobuf schema. Timed path writes/reads TCompactProtocol
 * via [TMemoryBuffer] / [TMemoryInputTransport].
 */
class ThriftSer : BenchSerializer {
    private var typeId: String = ""
    private var batch = false

    override fun name() = "thrift"

    override fun version() = Versions.of("org.apache.thrift.TSerializer")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "schema"

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val buf = TMemoryBuffer(256)
        val proto = TCompactProtocol(buf)
        writeValue(proto, fx)
        val n = buf.length()
        val raw = buf.array
        return if (raw.size == n) raw else raw.copyOf(n)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val transport = TMemoryInputTransport(data)
        val proto = TCompactProtocol(transport)
        return readValue(proto)
    }

    private fun writeValue(p: TProtocol, fx: Fixture) {
        if (batch) {
            p.writeStructBegin(TStruct("Batch"))
            p.writeFieldBegin(TField("items", TType.LIST, 1))
            val list = fx.value as List<*>
            p.writeListBegin(TList(TType.STRUCT, list.size))
            for (item in list) writeOne(p, typeId, item!!)
            p.writeListEnd()
            p.writeFieldEnd()
            p.writeFieldStop()
            p.writeStructEnd()
        } else {
            writeOne(p, typeId, fx.value)
        }
    }

    private fun readValue(p: TProtocol): Any {
        if (batch) {
            p.readStructBegin()
            val out = mutableListOf<Any>()
            while (true) {
                val f = p.readFieldBegin()
                if (f.type == TType.STOP) break
                if (f.id.toInt() == 1 && f.type == TType.LIST) {
                    val lst = p.readListBegin()
                    repeat(lst.size) { out.add(readOne(p, typeId)) }
                    p.readListEnd()
                } else {
                    org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
                }
                p.readFieldEnd()
            }
            p.readStructEnd()
            return out
        }
        return readOne(p, typeId)
    }

    private fun writeOne(p: TProtocol, typeId: String, value: Any) {
        when (typeId) {
            "message" -> writeMessage(p, value as Message)
            "document" -> writeDocument(p, value as Document)
            "telemetry" -> writeTelemetry(p, value as Telemetry)
            "strings" -> writeStrings(p, value as Strings)
            "event" -> writeEvent(p, value as Event)
            else -> throw IllegalArgumentException(typeId)
        }
    }

    private fun readOne(p: TProtocol, typeId: String): Any =
        when (typeId) {
            "message" -> readMessage(p)
            "document" -> readDocument(p)
            "telemetry" -> readTelemetry(p)
            "strings" -> readStrings(p)
            "event" -> readEvent(p)
            else -> throw IllegalArgumentException(typeId)
        }

    private fun writeMessage(p: TProtocol, m: Message) {
        p.writeStructBegin(TStruct("Message"))
        writeBool(p, 1, m.fBool)
        writeI32(p, 2, m.fInt32)
        writeI64(p, 3, m.fInt64)
        writeDouble(p, 4, m.fFloat64)
        writeString(p, 5, m.fString)
        writeBool(p, 6, m.fBool2)
        writeI32(p, 7, m.fInt32_2)
        writeString(p, 8, m.fString2)
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readMessage(p: TProtocol): Message {
        val m = Message()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            when (f.id.toInt()) {
                1 -> m.fBool = p.readBool()
                2 -> m.fInt32 = p.readI32()
                3 -> m.fInt64 = p.readI64()
                4 -> m.fFloat64 = p.readDouble()
                5 -> m.fString = p.readString()
                6 -> m.fBool2 = p.readBool()
                7 -> m.fInt32_2 = p.readI32()
                8 -> m.fString2 = p.readString()
                else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return m
    }

    private fun writeDocument(p: TProtocol, d: Document) {
        p.writeStructBegin(TStruct("Document"))
        writeString(p, 1, d.id)
        writeI32(p, 2, d.status)
        p.writeFieldBegin(TField("meta", TType.STRUCT, 3))
        writeMeta(p, d.meta)
        p.writeFieldEnd()
        p.writeFieldBegin(TField("items", TType.LIST, 4))
        p.writeListBegin(TList(TType.STRUCT, d.items.size))
        for (it in d.items) writeItem(p, it)
        p.writeListEnd()
        p.writeFieldEnd()
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readDocument(p: TProtocol): Document {
        val d = Document()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            when (f.id.toInt()) {
                1 -> d.id = p.readString()
                2 -> d.status = p.readI32()
                3 -> d.meta = readMeta(p)
                4 -> {
                    val lst = p.readListBegin()
                    d.items = MutableList(lst.size) { readItem(p) }
                    p.readListEnd()
                }
                else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return d
    }

    private fun writeMeta(p: TProtocol, m: DocumentMeta) {
        p.writeStructBegin(TStruct("DocumentMeta"))
        writeString(p, 1, m.region)
        writeI32(p, 2, m.version)
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readMeta(p: TProtocol): DocumentMeta {
        val m = DocumentMeta()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            when (f.id.toInt()) {
                1 -> m.region = p.readString()
                2 -> m.version = p.readI32()
                else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return m
    }

    private fun writeItem(p: TProtocol, it: DocumentItem) {
        p.writeStructBegin(TStruct("DocumentItem"))
        writeString(p, 1, it.sku)
        writeI32(p, 2, it.qty)
        writeI64(p, 3, it.priceMinor)
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readItem(p: TProtocol): DocumentItem {
        val it = DocumentItem()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            when (f.id.toInt()) {
                1 -> it.sku = p.readString()
                2 -> it.qty = p.readI32()
                3 -> it.priceMinor = p.readI64()
                else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return it
    }

    private fun writeTelemetry(p: TProtocol, t: Telemetry) {
        p.writeStructBegin(TStruct("Telemetry"))
        writeString(p, 1, t.source)
        writeI64(p, 2, t.ts)
        p.writeFieldBegin(TField("tags", TType.LIST, 3))
        p.writeListBegin(TList(TType.STRING, t.tags.size))
        for (s in t.tags) p.writeString(s)
        p.writeListEnd()
        p.writeFieldEnd()
        p.writeFieldBegin(TField("values", TType.LIST, 4))
        p.writeListBegin(TList(TType.DOUBLE, t.values.size))
        for (v in t.values) p.writeDouble(v)
        p.writeListEnd()
        p.writeFieldEnd()
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readTelemetry(p: TProtocol): Telemetry {
        val t = Telemetry()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            when (f.id.toInt()) {
                1 -> t.source = p.readString()
                2 -> t.ts = p.readI64()
                3 -> {
                    val lst = p.readListBegin()
                    t.tags = MutableList(lst.size) { p.readString() }
                    p.readListEnd()
                }
                4 -> {
                    val lst = p.readListBegin()
                    t.values = MutableList(lst.size) { p.readDouble() }
                    p.readListEnd()
                }
                else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return t
    }

    private fun writeStrings(p: TProtocol, s: Strings) {
        p.writeStructBegin(TStruct("Strings"))
        p.writeFieldBegin(TField("items", TType.LIST, 1))
        p.writeListBegin(TList(TType.STRING, s.items.size))
        for (it in s.items) p.writeString(it)
        p.writeListEnd()
        p.writeFieldEnd()
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readStrings(p: TProtocol): Strings {
        val s = Strings()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            if (f.id.toInt() == 1) {
                val lst = p.readListBegin()
                s.items = MutableList(lst.size) { p.readString() }
                p.readListEnd()
            } else {
                org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return s
    }

    private fun writeEvent(p: TProtocol, e: Event) {
        p.writeStructBegin(TStruct("Event"))
        writeString(p, 1, e.eventId)
        writeString(p, 2, e.eventType)
        writeI64(p, 3, e.occurredAt)
        writeString(p, 4, e.producer)
        p.writeFieldBegin(TField("attrs", TType.LIST, 5))
        p.writeListBegin(TList(TType.STRUCT, e.attrs.size))
        for (a in e.attrs) {
            p.writeStructBegin(TStruct("EventAttr"))
            writeString(p, 1, a.key)
            writeString(p, 2, a.value)
            p.writeFieldStop()
            p.writeStructEnd()
        }
        p.writeListEnd()
        p.writeFieldEnd()
        p.writeFieldStop()
        p.writeStructEnd()
    }

    private fun readEvent(p: TProtocol): Event {
        val e = Event()
        p.readStructBegin()
        while (true) {
            val f = p.readFieldBegin()
            if (f.type == TType.STOP) break
            when (f.id.toInt()) {
                1 -> e.eventId = p.readString()
                2 -> e.eventType = p.readString()
                3 -> e.occurredAt = p.readI64()
                4 -> e.producer = p.readString()
                5 -> {
                    val lst = p.readListBegin()
                    e.attrs =
                        MutableList(lst.size) {
                            val a = EventAttr()
                            p.readStructBegin()
                            while (true) {
                                val af = p.readFieldBegin()
                                if (af.type == TType.STOP) break
                                when (af.id.toInt()) {
                                    1 -> a.key = p.readString()
                                    2 -> a.value = p.readString()
                                    else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, af.type)
                                }
                                p.readFieldEnd()
                            }
                            p.readStructEnd()
                            a
                        }
                    p.readListEnd()
                }
                else -> org.apache.thrift.protocol.TProtocolUtil.skip(p, f.type)
            }
            p.readFieldEnd()
        }
        p.readStructEnd()
        return e
    }

    private fun writeBool(p: TProtocol, id: Short, v: Boolean) {
        p.writeFieldBegin(TField("", TType.BOOL, id))
        p.writeBool(v)
        p.writeFieldEnd()
    }

    private fun writeI32(p: TProtocol, id: Short, v: Int) {
        p.writeFieldBegin(TField("", TType.I32, id))
        p.writeI32(v)
        p.writeFieldEnd()
    }

    private fun writeI64(p: TProtocol, id: Short, v: Long) {
        p.writeFieldBegin(TField("", TType.I64, id))
        p.writeI64(v)
        p.writeFieldEnd()
    }

    private fun writeDouble(p: TProtocol, id: Short, v: Double) {
        p.writeFieldBegin(TField("", TType.DOUBLE, id))
        p.writeDouble(v)
        p.writeFieldEnd()
    }

    private fun writeString(p: TProtocol, id: Short, v: String) {
        p.writeFieldBegin(TField("", TType.STRING, id))
        p.writeString(v)
        p.writeFieldEnd()
    }
}
