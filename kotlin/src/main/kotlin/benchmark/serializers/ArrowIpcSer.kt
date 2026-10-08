package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.TableRow
import benchmark.model.v2.V2Rows
import org.apache.arrow.memory.ArrowBuf
import org.apache.arrow.memory.BufferAllocator
import org.apache.arrow.memory.RootAllocator
import org.apache.arrow.vector.BigIntVector
import org.apache.arrow.vector.FieldVector
import org.apache.arrow.vector.Float8Vector
import org.apache.arrow.vector.IntVector
import org.apache.arrow.vector.TypeLayout
import org.apache.arrow.vector.VarCharVector
import org.apache.arrow.vector.VectorLoader
import org.apache.arrow.vector.VectorSchemaRoot
import org.apache.arrow.vector.complex.ListVector
import org.apache.arrow.vector.complex.StructVector
import org.apache.arrow.vector.dictionary.DictionaryProvider
import org.apache.arrow.vector.ipc.ArrowStreamReader
import org.apache.arrow.vector.ipc.ArrowStreamWriter
import org.apache.arrow.vector.ipc.ReadChannel
import org.apache.arrow.vector.ipc.message.ArrowRecordBatch
import org.apache.arrow.vector.ipc.message.MessageChannelReader
import org.apache.arrow.vector.ipc.message.MessageSerializer
import org.apache.arrow.vector.types.FloatingPointPrecision
import org.apache.arrow.vector.types.pojo.ArrowType
import org.apache.arrow.vector.types.pojo.Field
import org.apache.arrow.vector.types.pojo.FieldType
import org.apache.arrow.vector.types.pojo.Schema
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.channels.Channels
import java.nio.charset.StandardCharsets

/**
 * Arrow IPC stream ([ArrowStreamWriter] / [ArrowStreamReader]), not the file format.
 * table_project loads only the f_float_0 node and its buffers.
 */
class ArrowIpcSer : BenchSerializer {
    private var typeId: String = ""
    private var batch = false
    private var allocator: BufferAllocator? = null

    override fun name() = "arrow-ipc"

    override fun version() = Versions.of(VectorSchemaRoot::class.java)

    override fun nativeKind() = "schema"

    override fun supports(testDataName: String) = testDataName in TypeUtil.COLUMNAR_IDS

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        allocator()
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val schema =
            when (typeId) {
                "table", "table_project" -> TABLE
                "nested_table" -> NESTED
                "signal" -> SIGNAL
                else -> throw IllegalArgumentException(typeId)
            }
        val bos = ByteArrayOutputStream()
        VectorSchemaRoot.create(schema, allocator()).use { root ->
            when (typeId) {
                "table", "table_project" -> fillTable(root, V2Rows.tables(fx.value))
                "nested_table" -> fillNested(root, V2Rows.nested(fx.value))
                "signal" -> fillSignal(root, V2Rows.signals(fx.value))
                else -> throw IllegalArgumentException(typeId)
            }
            ArrowStreamWriter(root, DictionaryProvider.MapDictionaryProvider(), bos).use { writer ->
                writer.start()
                writer.writeBatch()
                writer.end()
            }
        }
        return bos.toByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any {
        if (typeId == "table_project") return readFloat0(data)
        ArrowStreamReader(ByteArrayInputStream(data), allocator()).use { reader ->
            val root = reader.vectorSchemaRoot
            val rows = ArrayList<Any>()
            while (reader.loadNextBatch()) {
                val n = root.rowCount
                for (i in 0 until n) rows.add(readRow(root, i))
            }
            return V2Rows.oneOrList(rows, batch)
        }
    }

    private fun readFloat0(data: ByteArray): List<Double> {
        val out = ArrayList<Double>()
        MessageChannelReader(
            ReadChannel(Channels.newChannel(ByteArrayInputStream(data))),
            allocator(),
        ).use { reader ->
            val schemaResult = reader.readNext() ?: error("empty arrow stream")
            MessageSerializer.deserializeSchema(schemaResult.message)
            schemaResult.bodyBuffer?.close()
            var result = reader.readNext()
            while (result != null) {
                val body = result.bodyBuffer
                MessageSerializer.deserializeRecordBatch(result.message, body).use { full ->
                    val bufferCount = TypeLayout.getTypeBufferCount(FLOAT0.fields[0].type)
                    val bufs = ArrayList<ArrowBuf>(bufferCount)
                    for (i in 0 until bufferCount) bufs.add(full.buffers[i])
                    val nodes = listOf(full.nodes[0])
                    ArrowRecordBatch(full.length, nodes, bufs).use { slice ->
                        VectorSchemaRoot.create(FLOAT0, allocator()).use { one ->
                            VectorLoader(one).load(slice)
                            val values = one.getVector(0) as Float8Vector
                            for (i in 0 until one.rowCount) out.add(values.get(i))
                        }
                    }
                }
                result = reader.readNext()
            }
        }
        return out
    }

    private fun readRow(root: VectorSchemaRoot, i: Int): Any =
        when (typeId) {
            "table", "table_project" -> readTable(root, i)
            "nested_table" -> readNested(root, i)
            "signal" -> readSignal(root, i)
            else -> throw IllegalArgumentException(typeId)
        }

    private fun fillTable(root: VectorSchemaRoot, rows: List<TableRow>) {
        val n = rows.size
        alloc(root, n)
        val floats = Array(16) { root.getVector("f_float_$it") as Float8Vector }
        val ints = Array(4) { root.getVector("f_int_$it") as BigIntVector }
        val s0 = root.getVector("f_str_0") as VarCharVector
        val s1 = root.getVector("f_str_1") as VarCharVector
        for (r in 0 until n) {
            val row = rows[r]
            floats[0].setSafe(r, row.fFloat0)
            floats[1].setSafe(r, row.fFloat1)
            floats[2].setSafe(r, row.fFloat2)
            floats[3].setSafe(r, row.fFloat3)
            floats[4].setSafe(r, row.fFloat4)
            floats[5].setSafe(r, row.fFloat5)
            floats[6].setSafe(r, row.fFloat6)
            floats[7].setSafe(r, row.fFloat7)
            floats[8].setSafe(r, row.fFloat8)
            floats[9].setSafe(r, row.fFloat9)
            floats[10].setSafe(r, row.fFloat10)
            floats[11].setSafe(r, row.fFloat11)
            floats[12].setSafe(r, row.fFloat12)
            floats[13].setSafe(r, row.fFloat13)
            floats[14].setSafe(r, row.fFloat14)
            floats[15].setSafe(r, row.fFloat15)
            ints[0].setSafe(r, row.fInt0)
            ints[1].setSafe(r, row.fInt1)
            ints[2].setSafe(r, row.fInt2)
            ints[3].setSafe(r, row.fInt3)
            s0.setSafe(r, bytes(row.fStr0))
            s1.setSafe(r, bytes(row.fStr1))
        }
        root.rowCount = n
    }

    private fun fillNested(root: VectorSchemaRoot, rows: List<NestedRow>) {
        val n = rows.size
        var children = 0
        for (row in rows) children += row.items.size
        alloc(root, n)
        val items = root.getVector("items") as ListVector
        allocList(items, n, children)
        val ids = root.getVector("id") as VarCharVector
        val status = root.getVector("status") as IntVector
        val meta = root.getVector("meta") as StructVector
        val region = meta.getChild("region", VarCharVector::class.java)
        val version = meta.getChild("version", IntVector::class.java)
        val child = items.dataVector as StructVector
        val sku = child.getChild("sku", VarCharVector::class.java)
        val qty = child.getChild("qty", IntVector::class.java)
        val price = child.getChild("price_minor", BigIntVector::class.java)
        for (r in 0 until n) {
            val row = rows[r]
            ids.setSafe(r, bytes(row.id))
            status.setSafe(r, row.status)
            meta.setIndexDefined(r)
            val m = row.meta
            region.setSafe(r, bytes(m.region))
            version.setSafe(r, m.version)
            val count = row.items.size
            val start = items.startNewValue(r)
            for (j in 0 until count) {
                val it = row.items[j]
                val idx = start + j
                child.setIndexDefined(idx)
                sku.setSafe(idx, bytes(it.sku))
                qty.setSafe(idx, it.qty)
                price.setSafe(idx, it.priceMinor)
            }
            items.endValue(r, count)
        }
        root.rowCount = n
    }

    private fun fillSignal(root: VectorSchemaRoot, rows: List<Signal>) {
        val n = rows.size
        var children = 0
        for (row in rows) children += row.legs.size
        alloc(root, n)
        val legs = root.getVector("legs") as ListVector
        allocList(legs, n, children)
        val seq = root.getVector("seq") as BigIntVector
        val ts = root.getVector("ts") as BigIntVector
        val price = root.getVector("price_mantissa") as BigIntVector
        val qty = root.getVector("qty") as IntVector
        val flags = root.getVector("flags") as IntVector
        val symbol = root.getVector("symbol") as VarCharVector
        val venue = root.getVector("venue") as VarCharVector
        val child = legs.dataVector as StructVector
        val legId = child.getChild("leg_id", BigIntVector::class.java)
        val legQty = child.getChild("leg_qty", IntVector::class.java)
        val legPad = child.getChild("leg_pad", IntVector::class.java)
        for (r in 0 until n) {
            val row = rows[r]
            seq.setSafe(r, row.seq)
            ts.setSafe(r, row.ts)
            price.setSafe(r, row.priceMantissa)
            qty.setSafe(r, row.qty)
            flags.setSafe(r, row.flags)
            symbol.setSafe(r, bytes(row.symbol))
            venue.setSafe(r, bytes(row.venue))
            val count = row.legs.size
            val start = legs.startNewValue(r)
            for (j in 0 until count) {
                val leg = row.legs[j]
                val idx = start + j
                child.setIndexDefined(idx)
                legId.setSafe(idx, leg.legId)
                legQty.setSafe(idx, leg.legQty)
                legPad.setSafe(idx, 0)
            }
            legs.endValue(r, count)
        }
        root.rowCount = n
    }

    private fun allocator(): BufferAllocator {
        if (allocator == null) allocator = RootAllocator(Long.MAX_VALUE)
        return allocator!!
    }

    companion object {
        private val F64 = ArrowType.FloatingPoint(FloatingPointPrecision.DOUBLE)
        private val I64 = ArrowType.Int(64, true)
        private val I32 = ArrowType.Int(32, true)
        private val UTF8 = ArrowType.Utf8()
        private val TABLE = Schema(tableFields())
        private val NESTED = Schema(nestedFields())
        private val SIGNAL = Schema(signalFields())
        private val FLOAT0 = Schema(listOf(TABLE.fields[0]))

        private fun readTable(root: VectorSchemaRoot, i: Int): TableRow {
            val row = TableRow()
            row.fFloat0 = (root.getVector("f_float_0") as Float8Vector).get(i)
            row.fFloat1 = (root.getVector("f_float_1") as Float8Vector).get(i)
            row.fFloat2 = (root.getVector("f_float_2") as Float8Vector).get(i)
            row.fFloat3 = (root.getVector("f_float_3") as Float8Vector).get(i)
            row.fFloat4 = (root.getVector("f_float_4") as Float8Vector).get(i)
            row.fFloat5 = (root.getVector("f_float_5") as Float8Vector).get(i)
            row.fFloat6 = (root.getVector("f_float_6") as Float8Vector).get(i)
            row.fFloat7 = (root.getVector("f_float_7") as Float8Vector).get(i)
            row.fFloat8 = (root.getVector("f_float_8") as Float8Vector).get(i)
            row.fFloat9 = (root.getVector("f_float_9") as Float8Vector).get(i)
            row.fFloat10 = (root.getVector("f_float_10") as Float8Vector).get(i)
            row.fFloat11 = (root.getVector("f_float_11") as Float8Vector).get(i)
            row.fFloat12 = (root.getVector("f_float_12") as Float8Vector).get(i)
            row.fFloat13 = (root.getVector("f_float_13") as Float8Vector).get(i)
            row.fFloat14 = (root.getVector("f_float_14") as Float8Vector).get(i)
            row.fFloat15 = (root.getVector("f_float_15") as Float8Vector).get(i)
            row.fInt0 = (root.getVector("f_int_0") as BigIntVector).get(i)
            row.fInt1 = (root.getVector("f_int_1") as BigIntVector).get(i)
            row.fInt2 = (root.getVector("f_int_2") as BigIntVector).get(i)
            row.fInt3 = (root.getVector("f_int_3") as BigIntVector).get(i)
            row.fStr0 = utf8(root.getVector("f_str_0") as VarCharVector, i)
            row.fStr1 = utf8(root.getVector("f_str_1") as VarCharVector, i)
            return row
        }

        private fun readNested(root: VectorSchemaRoot, i: Int): NestedRow {
            val meta = root.getVector("meta") as StructVector
            val items = root.getVector("items") as ListVector
            val child = items.dataVector as StructVector
            val row = NestedRow()
            row.id = utf8(root.getVector("id") as VarCharVector, i)
            row.status = (root.getVector("status") as IntVector).get(i)
            row.meta =
                NestedRow.NestedMeta(
                    utf8(meta.getChild("region", VarCharVector::class.java), i),
                    meta.getChild("version", IntVector::class.java).get(i),
                )
            val start = items.getElementStartIndex(i)
            val end = items.getElementEndIndex(i)
            for (idx in start until end) {
                row.items.add(
                    NestedRow.NestedItem(
                        utf8(child.getChild("sku", VarCharVector::class.java), idx),
                        child.getChild("qty", IntVector::class.java).get(idx),
                        child.getChild("price_minor", BigIntVector::class.java).get(idx),
                    ),
                )
            }
            return row
        }

        private fun readSignal(root: VectorSchemaRoot, i: Int): Signal {
            val legs = root.getVector("legs") as ListVector
            val child = legs.dataVector as StructVector
            val row = Signal()
            row.seq = (root.getVector("seq") as BigIntVector).get(i)
            row.ts = (root.getVector("ts") as BigIntVector).get(i)
            row.priceMantissa = (root.getVector("price_mantissa") as BigIntVector).get(i)
            row.qty = (root.getVector("qty") as IntVector).get(i)
            row.flags = (root.getVector("flags") as IntVector).get(i)
            row.symbol = utf8(root.getVector("symbol") as VarCharVector, i)
            row.venue = utf8(root.getVector("venue") as VarCharVector, i)
            val start = legs.getElementStartIndex(i)
            val end = legs.getElementEndIndex(i)
            for (idx in start until end) {
                row.legs.add(
                    Signal.SignalLeg(
                        child.getChild("leg_id", BigIntVector::class.java).get(idx),
                        child.getChild("leg_qty", IntVector::class.java).get(idx),
                        child.getChild("leg_pad", IntVector::class.java).get(idx),
                    ),
                )
            }
            return row
        }

        private fun alloc(root: VectorSchemaRoot, rows: Int) {
            for (v in root.fieldVectors) {
                v.setInitialCapacity(maxOf(rows, 1))
                v.allocateNew()
            }
        }

        private fun allocList(list: ListVector, rows: Int, children: Int) {
            list.setInitialCapacity(maxOf(rows, 1))
            list.allocateNew()
            val data = list.dataVector
            data.setInitialCapacity(maxOf(children, 1))
            data.allocateNew()
        }

        private fun bytes(s: String?): ByteArray = (s ?: "").toByteArray(StandardCharsets.UTF_8)

        private fun utf8(v: VarCharVector, i: Int): String {
            if (v.isNull(i)) return ""
            val b = v.get(i) ?: return ""
            return String(b, StandardCharsets.UTF_8)
        }

        private fun field(name: String, type: ArrowType): Field =
            Field(name, FieldType.nullable(type), null as List<Field>?)

        private fun struct(name: String, children: List<Field>): Field =
            Field(name, FieldType.nullable(ArrowType.Struct()), children)

        private fun list(name: String, child: Field): Field =
            Field(name, FieldType.nullable(ArrowType.List()), listOf(child))

        private fun tableFields(): List<Field> {
            val fields = ArrayList<Field>()
            for (i in 0 until 16) fields.add(field("f_float_$i", F64))
            for (i in 0 until 4) fields.add(field("f_int_$i", I64))
            fields.add(field("f_str_0", UTF8))
            fields.add(field("f_str_1", UTF8))
            return fields
        }

        private fun nestedFields(): List<Field> =
            listOf(
                field("id", UTF8),
                field("status", I32),
                struct("meta", listOf(field("region", UTF8), field("version", I32))),
                list(
                    "items",
                    struct(
                        "item",
                        listOf(field("sku", UTF8), field("qty", I32), field("price_minor", I64)),
                    ),
                ),
            )

        private fun signalFields(): List<Field> =
            listOf(
                field("seq", I64),
                field("ts", I64),
                field("price_mantissa", I64),
                field("qty", I32),
                field("flags", I32),
                field("symbol", UTF8),
                field("venue", UTF8),
                list(
                    "legs",
                    struct(
                        "item",
                        listOf(field("leg_id", I64), field("leg_qty", I32), field("leg_pad", I32)),
                    ),
                ),
            )
    }
}
