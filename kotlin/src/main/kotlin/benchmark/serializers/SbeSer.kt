package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.Signal
import benchmark.model.v2.TableRow
import benchmark.model.v2.V2Rows
import benchmark.v2.MessageHeaderDecoder
import benchmark.v2.MessageHeaderEncoder
import benchmark.v2.SignalDecoder
import benchmark.v2.SignalEncoder
import benchmark.v2.TableDecoder
import benchmark.v2.TableEncoder
import org.agrona.ExpandableArrayBuffer
import org.agrona.concurrent.UnsafeBuffer
import java.nio.ByteOrder

/**
 * SBE 1.40.2 flyweights generated from schemas/v2/sbe/signal.xml.
 * Codegen is untimed. The flyweight is filled inside [serializeBytes].
 * nested_table is not in the schema. Wire order for signal is fixed fields, then the legs
 * group, then symbol and venue.
 */
class SbeSer : BenchSerializer {
    private var typeId: String = ""
    private var batch = false

    override fun name() = "sbe"

    override fun version() = "1.40.2"

    override fun nativeKind() = "schema"

    override fun supports(testDataName: String): Boolean =
        testDataName == "table" || testDataName == "table_project" || testDataName == "signal"

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val rows: List<*> =
            when (typeId) {
                "table", "table_project" -> V2Rows.tables(fx.value)
                "signal" -> V2Rows.signals(fx.value)
                else -> throw IllegalArgumentException(typeId)
            }
        val buf = ExpandableArrayBuffer(maxOf(256, rows.size * 256))
        buf.putInt(0, rows.size, ByteOrder.LITTLE_ENDIAN)
        var offset = Int.SIZE_BYTES
        if (typeId == "signal") {
            val header = MessageHeaderEncoder()
            val enc = SignalEncoder()
            for (o in rows) {
                val s = o as Signal
                enc.wrapAndApplyHeader(buf, offset, header)
                enc.seq(s.seq)
                enc.ts(s.ts)
                enc.price_mantissa(s.priceMantissa)
                enc.qty(s.qty)
                enc.flags(s.flags)
                val legs = enc.legsCount(s.legs.size)
                for (leg in s.legs) {
                    legs.next().leg_id(leg.legId).leg_qty(leg.legQty).leg_pad(0)
                }
                enc.symbol(s.symbol)
                enc.venue(s.venue)
                offset = enc.limit()
            }
        } else {
            val header = MessageHeaderEncoder()
            val enc = TableEncoder()
            for (o in rows) {
                val row = o as TableRow
                enc.wrapAndApplyHeader(buf, offset, header)
                enc.f_float_0(row.fFloat0)
                enc.f_float_1(row.fFloat1)
                enc.f_float_2(row.fFloat2)
                enc.f_float_3(row.fFloat3)
                enc.f_float_4(row.fFloat4)
                enc.f_float_5(row.fFloat5)
                enc.f_float_6(row.fFloat6)
                enc.f_float_7(row.fFloat7)
                enc.f_float_8(row.fFloat8)
                enc.f_float_9(row.fFloat9)
                enc.f_float_10(row.fFloat10)
                enc.f_float_11(row.fFloat11)
                enc.f_float_12(row.fFloat12)
                enc.f_float_13(row.fFloat13)
                enc.f_float_14(row.fFloat14)
                enc.f_float_15(row.fFloat15)
                enc.f_int_0(row.fInt0)
                enc.f_int_1(row.fInt1)
                enc.f_int_2(row.fInt2)
                enc.f_int_3(row.fInt3)
                enc.f_str_0(row.fStr0)
                enc.f_str_1(row.fStr1)
                offset = enc.limit()
            }
        }
        val out = ByteArray(offset)
        buf.getBytes(0, out, 0, offset)
        return out
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val buf = UnsafeBuffer(data)
        val count = buf.getInt(0, ByteOrder.LITTLE_ENDIAN)
        var offset = Int.SIZE_BYTES
        if (typeId == "signal") {
            val header = MessageHeaderDecoder()
            val dec = SignalDecoder()
            val rows = ArrayList<Signal>(count)
            for (i in 0 until count) {
                dec.wrapAndApplyHeader(buf, offset, header)
                val s = Signal()
                s.seq = dec.seq()
                s.ts = dec.ts()
                s.priceMantissa = dec.price_mantissa()
                s.qty = dec.qty()
                s.flags = dec.flags()
                val legs = dec.legs()
                val n = legs.count()
                for (j in 0 until n) {
                    legs.next()
                    s.legs.add(Signal.SignalLeg(legs.leg_id(), legs.leg_qty(), legs.leg_pad()))
                }
                s.symbol = dec.symbol()
                s.venue = dec.venue()
                offset = dec.limit()
                rows.add(s)
            }
            return V2Rows.oneOrList(rows, batch)
        }
        val header = MessageHeaderDecoder()
        val dec = TableDecoder()
        val rows = ArrayList<TableRow>(count)
        for (i in 0 until count) {
            dec.wrapAndApplyHeader(buf, offset, header)
            val row = TableRow()
            row.fFloat0 = dec.f_float_0()
            row.fFloat1 = dec.f_float_1()
            row.fFloat2 = dec.f_float_2()
            row.fFloat3 = dec.f_float_3()
            row.fFloat4 = dec.f_float_4()
            row.fFloat5 = dec.f_float_5()
            row.fFloat6 = dec.f_float_6()
            row.fFloat7 = dec.f_float_7()
            row.fFloat8 = dec.f_float_8()
            row.fFloat9 = dec.f_float_9()
            row.fFloat10 = dec.f_float_10()
            row.fFloat11 = dec.f_float_11()
            row.fFloat12 = dec.f_float_12()
            row.fFloat13 = dec.f_float_13()
            row.fFloat14 = dec.f_float_14()
            row.fFloat15 = dec.f_float_15()
            row.fInt0 = dec.f_int_0()
            row.fInt1 = dec.f_int_1()
            row.fInt2 = dec.f_int_2()
            row.fInt3 = dec.f_int_3()
            row.fStr0 = dec.f_str_0()
            row.fStr1 = dec.f_str_1()
            offset = dec.limit()
            rows.add(row)
        }
        if (typeId == "table_project") return V2Rows.float0(rows)
        return V2Rows.oneOrList(rows, batch)
    }
}
