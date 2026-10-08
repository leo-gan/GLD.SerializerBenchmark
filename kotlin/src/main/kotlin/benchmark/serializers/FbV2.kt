package benchmark.serializers

import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.TableRow
import com.google.flatbuffers.FlatBufferBuilder
import com.google.flatbuffers.Table
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Hand-built FlatBuffers tables for the columnar types.
 * Slot order matches the Java and Python builders. There is no shared .fbs for these types.
 * FlatBufferBuilder only accepts slots in descending order.
 */
object FbV2 {
    fun packTable(b: FlatBufferBuilder, row: TableRow): Int {
        val s1 = b.createString(row.fStr1)
        val s0 = b.createString(row.fStr0)
        b.startTable(22)
        b.addOffset(21, s1, 0)
        b.addOffset(20, s0, 0)
        b.addLong(19, row.fInt3, 0)
        b.addLong(18, row.fInt2, 0)
        b.addLong(17, row.fInt1, 0)
        b.addLong(16, row.fInt0, 0)
        b.addDouble(15, row.fFloat15, 0.0)
        b.addDouble(14, row.fFloat14, 0.0)
        b.addDouble(13, row.fFloat13, 0.0)
        b.addDouble(12, row.fFloat12, 0.0)
        b.addDouble(11, row.fFloat11, 0.0)
        b.addDouble(10, row.fFloat10, 0.0)
        b.addDouble(9, row.fFloat9, 0.0)
        b.addDouble(8, row.fFloat8, 0.0)
        b.addDouble(7, row.fFloat7, 0.0)
        b.addDouble(6, row.fFloat6, 0.0)
        b.addDouble(5, row.fFloat5, 0.0)
        b.addDouble(4, row.fFloat4, 0.0)
        b.addDouble(3, row.fFloat3, 0.0)
        b.addDouble(2, row.fFloat2, 0.0)
        b.addDouble(1, row.fFloat1, 0.0)
        b.addDouble(0, row.fFloat0, 0.0)
        return b.endTable()
    }

    fun packNested(b: FlatBufferBuilder, row: NestedRow): Int {
        val id = b.createString(row.id)
        val region = b.createString(row.meta.region)
        b.startTable(2)
        b.addInt(1, row.meta.version, 0)
        b.addOffset(0, region, 0)
        val metaOff = b.endTable()
        val itemOffs = IntArray(row.items.size)
        for (i in row.items.indices) {
            val it = row.items[i]
            val sku = b.createString(it.sku)
            b.startTable(3)
            b.addLong(2, it.priceMinor, 0)
            b.addInt(1, it.qty, 0)
            b.addOffset(0, sku, 0)
            itemOffs[i] = b.endTable()
        }
        val vec = b.createVectorOfTables(itemOffs)
        b.startTable(4)
        b.addOffset(3, vec, 0)
        b.addOffset(2, metaOff, 0)
        b.addInt(1, row.status, 0)
        b.addOffset(0, id, 0)
        return b.endTable()
    }

    fun packSignal(b: FlatBufferBuilder, row: Signal): Int {
        val venue = b.createString(row.venue)
        val symbol = b.createString(row.symbol)
        val legOffs = IntArray(row.legs.size)
        for (i in row.legs.indices) {
            val leg = row.legs[i]
            b.startTable(3)
            b.addInt(2, leg.legPad, 0)
            b.addInt(1, leg.legQty, 0)
            b.addLong(0, leg.legId, 0)
            legOffs[i] = b.endTable()
        }
        val vec = b.createVectorOfTables(legOffs)
        b.startTable(8)
        b.addOffset(7, vec, 0)
        b.addOffset(6, venue, 0)
        b.addOffset(5, symbol, 0)
        b.addInt(4, row.flags, 0)
        b.addInt(3, row.qty, 0)
        b.addLong(2, row.priceMantissa, 0)
        b.addLong(1, row.ts, 0)
        b.addLong(0, row.seq, 0)
        return b.endTable()
    }

    /** One-field wrapper. Field 0 is a vector of the row tables. */
    fun packBatch(b: FlatBufferBuilder, tables: IntArray): Int {
        val vec = b.createVectorOfTables(tables)
        b.startTable(1)
        b.addOffset(0, vec, 0)
        return b.endTable()
    }

    fun readTable(bb: ByteBuffer): TableRow = tableFrom(FbTable.root(bb))

    fun readTableBatch(bb: ByteBuffer): List<TableRow> {
        val root = FbTable.root(bb)
        val n = root.vectorLen(0)
        return List(n) { tableFrom(root.vectorTable(0, it)) }
    }

    fun readNested(bb: ByteBuffer): NestedRow = nestedFrom(FbTable.root(bb))

    fun readNestedBatch(bb: ByteBuffer): List<NestedRow> {
        val root = FbTable.root(bb)
        val n = root.vectorLen(0)
        return List(n) { nestedFrom(root.vectorTable(0, it)) }
    }

    fun readSignal(bb: ByteBuffer): Signal = signalFrom(FbTable.root(bb))

    fun readSignalBatch(bb: ByteBuffer): List<Signal> {
        val root = FbTable.root(bb)
        val n = root.vectorLen(0)
        return List(n) { signalFrom(root.vectorTable(0, it)) }
    }

    private fun tableFrom(t: FbTable): TableRow {
        val row = TableRow()
        row.fFloat0 = t.f64(0)
        row.fFloat1 = t.f64(1)
        row.fFloat2 = t.f64(2)
        row.fFloat3 = t.f64(3)
        row.fFloat4 = t.f64(4)
        row.fFloat5 = t.f64(5)
        row.fFloat6 = t.f64(6)
        row.fFloat7 = t.f64(7)
        row.fFloat8 = t.f64(8)
        row.fFloat9 = t.f64(9)
        row.fFloat10 = t.f64(10)
        row.fFloat11 = t.f64(11)
        row.fFloat12 = t.f64(12)
        row.fFloat13 = t.f64(13)
        row.fFloat14 = t.f64(14)
        row.fFloat15 = t.f64(15)
        row.fInt0 = t.i64(16)
        row.fInt1 = t.i64(17)
        row.fInt2 = t.i64(18)
        row.fInt3 = t.i64(19)
        row.fStr0 = t.str(20)
        row.fStr1 = t.str(21)
        return row
    }

    private fun nestedFrom(t: FbTable): NestedRow {
        val meta = t.table(2)
        val m =
            if (meta == null) {
                NestedRow.NestedMeta("", 0)
            } else {
                NestedRow.NestedMeta(meta.str(0), meta.i32(1))
            }
        val n = t.vectorLen(3)
        val items = ArrayList<NestedRow.NestedItem>(n)
        for (i in 0 until n) {
            val it = t.vectorTable(3, i)
            items.add(NestedRow.NestedItem(it.str(0), it.i32(1), it.i64(2)))
        }
        return NestedRow(t.str(0), t.i32(1), m, items)
    }

    private fun signalFrom(t: FbTable): Signal {
        val n = t.vectorLen(7)
        val legs = ArrayList<Signal.SignalLeg>(n)
        for (i in 0 until n) {
            val leg = t.vectorTable(7, i)
            legs.add(Signal.SignalLeg(leg.i64(0), leg.i32(1), leg.i32(2)))
        }
        return Signal(t.i64(0), t.i64(1), t.i64(2), t.i32(3), t.i32(4), t.str(5), t.str(6), legs)
    }

    class FbTable : Table() {
        fun field(slot: Int): Int = __offset(4 + slot * 2)

        fun f64(slot: Int): Double {
            val o = field(slot)
            return if (o == 0) 0.0 else bb.getDouble(o + bb_pos)
        }

        fun i64(slot: Int): Long {
            val o = field(slot)
            return if (o == 0) 0L else bb.getLong(o + bb_pos)
        }

        fun i32(slot: Int): Int {
            val o = field(slot)
            return if (o == 0) 0 else bb.getInt(o + bb_pos)
        }

        fun str(slot: Int): String {
            val o = field(slot)
            return if (o == 0) "" else __string(o + bb_pos)
        }

        fun table(slot: Int): FbTable? {
            val o = field(slot)
            if (o == 0) return null
            return at(bb, __indirect(o + bb_pos))
        }

        fun vectorLen(slot: Int): Int {
            val o = field(slot)
            return if (o == 0) 0 else __vector_len(o)
        }

        fun vectorTable(slot: Int, index: Int): FbTable {
            val o = field(slot)
            return at(bb, __indirect(__vector(o) + index * 4))
        }

        companion object {
            fun root(bb: ByteBuffer): FbTable {
                bb.order(ByteOrder.LITTLE_ENDIAN)
                val pos = bb.position()
                val t = FbTable()
                t.__reset(bb.getInt(pos) + pos, bb)
                return t
            }

            fun at(bb: ByteBuffer, pos: Int): FbTable {
                val t = FbTable()
                t.__reset(pos, bb)
                return t
            }
        }
    }
}
