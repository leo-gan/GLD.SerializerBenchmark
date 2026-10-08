package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.DocumentItem
import benchmark.model.v2.DocumentMeta
import benchmark.model.v2.Event
import benchmark.model.v2.EventAttr
import benchmark.model.v2.Message
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.Strings
import benchmark.model.v2.TableRow
import benchmark.model.v2.Telemetry
import benchmark.model.v2.V2Rows
import benchmark.v2.BatchDocument
import benchmark.v2.BatchEvent
import benchmark.v2.BatchMessage
import benchmark.v2.BatchNestedRow
import benchmark.v2.BatchSignal
import benchmark.v2.BatchStrings
import benchmark.v2.BatchTable
import benchmark.v2.BatchTelemetry
import com.google.protobuf.MessageLite
import com.google.protobuf.Parser
import java.io.InputStream
import java.io.OutputStream

/**
 * Protocol Buffers (protobuf-java) — official Google runtime, used from Kotlin.
 *
 * Timed path: domain → generated Message → bytes → generated Message → domain.
 * Conversion is inside serialize/deserialize so the pair is comparable with Protostuff.
 */
class ProtobufSer : BenchSerializer {
    private lateinit var parser: Parser<out MessageLite>
    private var typeId: String = ""
    private var batch = false

    override fun name() = "protobuf"

    override fun version() = Versions.of(MessageLite::class.java)

    override fun streamMode() = "native"

    override fun nativeKind() = "message"

    override fun supports(testDataName: String) = TypeUtil.originalOrColumnar(testDataName)

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        parser = toProto(fx).parserForType
    }

    override fun serializeBytes(fx: Fixture): ByteArray = toProto(fx).toByteArray()

    override fun deserializeBytes(data: ByteArray): Any = fromProto(typeId, batch, parser.parseFrom(data))

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val msg = toProto(fx)
        msg.writeTo(out)
        return msg.serializedSize
    }

    override fun deserializeStream(input: InputStream): Any =
        fromProto(typeId, batch, parser.parseFrom(input))

    companion object {
        private fun toProto(fx: Fixture): MessageLite {
            if (fx.value is List<*>) {
                return when (fx.name) {
                    "message" -> {
                        val b = BatchMessage.newBuilder()
                        for (o in fx.value) b.addItems(toMessage(o as Message))
                        b.build()
                    }
                    "document" -> {
                        val b = BatchDocument.newBuilder()
                        for (o in fx.value) b.addItems(toDocument(o as Document))
                        b.build()
                    }
                    "telemetry" -> {
                        val b = BatchTelemetry.newBuilder()
                        for (o in fx.value) b.addItems(toTelemetry(o as Telemetry))
                        b.build()
                    }
                    "strings" -> {
                        val b = BatchStrings.newBuilder()
                        for (o in fx.value) b.addItems(toStrings(o as Strings))
                        b.build()
                    }
                    "event" -> {
                        val b = BatchEvent.newBuilder()
                        for (o in fx.value) b.addItems(toEvent(o as Event))
                        b.build()
                    }
                    "table", "table_project" -> {
                        val b = BatchTable.newBuilder()
                        for (o in fx.value) b.addItems(toTable(o as TableRow))
                        b.build()
                    }
                    "nested_table" -> {
                        val b = BatchNestedRow.newBuilder()
                        for (o in fx.value) b.addItems(toNested(o as NestedRow))
                        b.build()
                    }
                    "signal" -> {
                        val b = BatchSignal.newBuilder()
                        for (o in fx.value) b.addItems(toSignal(o as Signal))
                        b.build()
                    }
                    else -> throw IllegalArgumentException(fx.name)
                }
            }
            return when (fx.name) {
                "message" -> toMessage(fx.value as Message)
                "document" -> toDocument(fx.value as Document)
                "telemetry" -> toTelemetry(fx.value as Telemetry)
                "strings" -> toStrings(fx.value as Strings)
                "event" -> toEvent(fx.value as Event)
                "table", "table_project" -> toTable(fx.value as TableRow)
                "nested_table" -> toNested(fx.value as NestedRow)
                "signal" -> toSignal(fx.value as Signal)
                else -> throw IllegalArgumentException(fx.name)
            }
        }

        private fun fromProto(typeId: String, batch: Boolean, ml: MessageLite): Any {
            if (batch) {
                return when (typeId) {
                    "message" -> (ml as BatchMessage).itemsList.map { fromMessage(it) }.toMutableList()
                    "document" -> (ml as BatchDocument).itemsList.map { fromDocument(it) }.toMutableList()
                    "telemetry" -> (ml as BatchTelemetry).itemsList.map { fromTelemetry(it) }.toMutableList()
                    "strings" -> (ml as BatchStrings).itemsList.map { fromStrings(it) }.toMutableList()
                    "event" -> (ml as BatchEvent).itemsList.map { fromEvent(it) }.toMutableList()
                    "table" -> (ml as BatchTable).itemsList.map { fromTable(it) }.toMutableList()
                    "table_project" -> V2Rows.float0((ml as BatchTable).itemsList.map { fromTable(it) })
                    "nested_table" -> (ml as BatchNestedRow).itemsList.map { fromNested(it) }.toMutableList()
                    "signal" -> (ml as BatchSignal).itemsList.map { fromSignal(it) }.toMutableList()
                    else -> ml
                }
            }
            return when (typeId) {
                "message" -> fromMessage(ml as benchmark.v2.Message)
                "document" -> fromDocument(ml as benchmark.v2.Document)
                "telemetry" -> fromTelemetry(ml as benchmark.v2.Telemetry)
                "strings" -> fromStrings(ml as benchmark.v2.Strings)
                "event" -> fromEvent(ml as benchmark.v2.Event)
                "table" -> fromTable(ml as benchmark.v2.Table)
                "table_project" -> V2Rows.float0(fromTable(ml as benchmark.v2.Table))
                "nested_table" -> fromNested(ml as benchmark.v2.NestedRow)
                "signal" -> fromSignal(ml as benchmark.v2.Signal)
                else -> ml
            }
        }

        private fun toMessage(m: Message): benchmark.v2.Message =
            benchmark.v2.Message.newBuilder()
                .setFBool(m.fBool)
                .setFInt32(m.fInt32)
                .setFInt64(m.fInt64)
                .setFFloat64(m.fFloat64)
                .setFString(m.fString)
                .setFBool2(m.fBool2)
                .setFInt322(m.fInt32_2)
                .setFString2(m.fString2)
                .build()

        private fun fromMessage(m: benchmark.v2.Message): Message =
            Message(m.fBool, m.fInt32, m.fInt64, m.fFloat64, m.fString, m.fBool2, m.fInt322, m.fString2)

        private fun toDocument(d: Document): benchmark.v2.Document {
            val b = benchmark.v2.Document.newBuilder().setId(d.id).setStatus(d.status)
            b.meta =
                benchmark.v2.DocumentMeta.newBuilder()
                    .setRegion(d.meta.region)
                    .setVersion(d.meta.version)
                    .build()
            for (it in d.items) {
                b.addItems(
                    benchmark.v2.DocumentItem.newBuilder()
                        .setSku(it.sku)
                        .setQty(it.qty)
                        .setPriceMinor(it.priceMinor)
                        .build(),
                )
            }
            return b.build()
        }

        private fun fromDocument(d: benchmark.v2.Document): Document {
            val meta =
                if (d.hasMeta()) DocumentMeta(d.meta.region, d.meta.version) else DocumentMeta("", 0)
            val items = d.itemsList.map { DocumentItem(it.sku, it.qty, it.priceMinor) }.toMutableList()
            return Document(d.id, d.status, meta, items)
        }

        private fun toTelemetry(t: Telemetry): benchmark.v2.Telemetry {
            val b = benchmark.v2.Telemetry.newBuilder().setSource(t.source).setTs(t.ts)
            b.addAllTags(t.tags)
            b.addAllValues(t.values)
            return b.build()
        }

        private fun fromTelemetry(t: benchmark.v2.Telemetry): Telemetry =
            Telemetry(t.source, t.ts, t.tagsList.toMutableList(), t.valuesList.toMutableList())

        private fun toStrings(s: Strings): benchmark.v2.Strings =
            benchmark.v2.Strings.newBuilder().addAllItems(s.items).build()

        private fun fromStrings(s: benchmark.v2.Strings): Strings = Strings(s.itemsList.toMutableList())

        private fun toEvent(e: Event): benchmark.v2.Event {
            val b =
                benchmark.v2.Event.newBuilder()
                    .setEventId(e.eventId)
                    .setEventType(e.eventType)
                    .setOccurredAt(e.occurredAt)
                    .setProducer(e.producer)
            for (a in e.attrs) {
                b.addAttrs(benchmark.v2.EventAttr.newBuilder().setKey(a.key).setValue(a.value).build())
            }
            return b.build()
        }

        private fun fromEvent(e: benchmark.v2.Event): Event =
            Event(
                e.eventId,
                e.eventType,
                e.occurredAt,
                e.producer,
                e.attrsList.map { EventAttr(it.key, it.value) }.toMutableList(),
            )

        private fun toTable(row: TableRow): benchmark.v2.Table =
            benchmark.v2.Table.newBuilder()
                .setFFloat0(row.fFloat0)
                .setFFloat1(row.fFloat1)
                .setFFloat2(row.fFloat2)
                .setFFloat3(row.fFloat3)
                .setFFloat4(row.fFloat4)
                .setFFloat5(row.fFloat5)
                .setFFloat6(row.fFloat6)
                .setFFloat7(row.fFloat7)
                .setFFloat8(row.fFloat8)
                .setFFloat9(row.fFloat9)
                .setFFloat10(row.fFloat10)
                .setFFloat11(row.fFloat11)
                .setFFloat12(row.fFloat12)
                .setFFloat13(row.fFloat13)
                .setFFloat14(row.fFloat14)
                .setFFloat15(row.fFloat15)
                .setFInt0(row.fInt0)
                .setFInt1(row.fInt1)
                .setFInt2(row.fInt2)
                .setFInt3(row.fInt3)
                .setFStr0(row.fStr0)
                .setFStr1(row.fStr1)
                .build()

        private fun fromTable(t: benchmark.v2.Table): TableRow =
            TableRow(
                fFloat0 = t.fFloat0,
                fFloat1 = t.fFloat1,
                fFloat2 = t.fFloat2,
                fFloat3 = t.fFloat3,
                fFloat4 = t.fFloat4,
                fFloat5 = t.fFloat5,
                fFloat6 = t.fFloat6,
                fFloat7 = t.fFloat7,
                fFloat8 = t.fFloat8,
                fFloat9 = t.fFloat9,
                fFloat10 = t.fFloat10,
                fFloat11 = t.fFloat11,
                fFloat12 = t.fFloat12,
                fFloat13 = t.fFloat13,
                fFloat14 = t.fFloat14,
                fFloat15 = t.fFloat15,
                fInt0 = t.fInt0,
                fInt1 = t.fInt1,
                fInt2 = t.fInt2,
                fInt3 = t.fInt3,
                fStr0 = t.fStr0,
                fStr1 = t.fStr1,
            )

        private fun toNested(row: NestedRow): benchmark.v2.NestedRow {
            val b =
                benchmark.v2.NestedRow.newBuilder()
                    .setId(row.id)
                    .setStatus(row.status)
                    .setMeta(
                        benchmark.v2.NestedMeta.newBuilder()
                            .setRegion(row.meta.region)
                            .setVersion(row.meta.version)
                            .build(),
                    )
            for (it in row.items) {
                b.addItems(
                    benchmark.v2.NestedItem.newBuilder()
                        .setSku(it.sku)
                        .setQty(it.qty)
                        .setPriceMinor(it.priceMinor)
                        .build(),
                )
            }
            return b.build()
        }

        private fun fromNested(n: benchmark.v2.NestedRow): NestedRow {
            val meta =
                if (n.hasMeta()) NestedRow.NestedMeta(n.meta.region, n.meta.version) else NestedRow.NestedMeta("", 0)
            val items =
                n.itemsList.map { NestedRow.NestedItem(it.sku, it.qty, it.priceMinor) }.toMutableList()
            return NestedRow(n.id, n.status, meta, items)
        }

        private fun toSignal(row: Signal): benchmark.v2.Signal {
            val b =
                benchmark.v2.Signal.newBuilder()
                    .setSeq(row.seq)
                    .setTs(row.ts)
                    .setPriceMantissa(row.priceMantissa)
                    .setQty(row.qty)
                    .setFlags(row.flags)
                    .setSymbol(row.symbol)
                    .setVenue(row.venue)
            for (leg in row.legs) {
                b.addLegs(
                    benchmark.v2.SignalLeg.newBuilder()
                        .setLegId(leg.legId)
                        .setLegQty(leg.legQty)
                        .setLegPad(leg.legPad)
                        .build(),
                )
            }
            return b.build()
        }

        private fun fromSignal(s: benchmark.v2.Signal): Signal =
            Signal(
                s.seq,
                s.ts,
                s.priceMantissa,
                s.qty,
                s.flags,
                s.symbol,
                s.venue,
                s.legsList.map { Signal.SignalLeg(it.legId, it.legQty, it.legPad) }.toMutableList(),
            )
    }
}
