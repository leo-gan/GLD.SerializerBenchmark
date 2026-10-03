package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.TableRow
import benchmark.model.v2.V2Rows
import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.Path
import org.apache.orc.CompressionKind
import org.apache.orc.OrcFile
import org.apache.orc.TypeDescription
import org.apache.orc.Writer
import org.apache.orc.storage.ql.exec.vector.BytesColumnVector
import org.apache.orc.storage.ql.exec.vector.ColumnVector
import org.apache.orc.storage.ql.exec.vector.DoubleColumnVector
import org.apache.orc.storage.ql.exec.vector.ListColumnVector
import org.apache.orc.storage.ql.exec.vector.LongColumnVector
import org.apache.orc.storage.ql.exec.vector.StructColumnVector
import org.apache.orc.storage.ql.exec.vector.VectorizedRowBatch

/**
 * ORC via orc-core nohive.
 *
 * ORC 2.3.1 OrcConf.COMPRESS defaults to ZSTD. orc does not call compress().
 * orc-uncompressed sets [CompressionKind.NONE]. Both rows set blockPadding(false) so the writer
 * does not pad out to the default 256MB HDFS block. Do not force Zlib under the name orc.
 */
abstract class AbstractOrcSer(
    private val rowName: String,
    private val uncompressed: Boolean,
) : BenchSerializer {
    private var typeId: String = ""
    private var batch = false
    private var project = false
    private lateinit var schema: TypeDescription
    private var conf: Configuration? = null
    private var fs: MemoryOrcFileSystem? = null
    private var seq = 0

    override fun name() = rowName

    override fun version() = Versions.of(OrcFile::class.java)

    override fun nativeKind() = "schema"

    override fun supports(testDataName: String) = testDataName in TypeUtil.COLUMNAR_IDS

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        project = typeId == "table_project"
        schema =
            when (typeId) {
                "table", "table_project" -> tableSchema()
                "nested_table" -> nestedSchema()
                "signal" -> signalSchema()
                else -> throw IllegalArgumentException(typeId)
            }
        if (conf == null) {
            val created = Configuration(false)
            conf = created
            fs = MemoryOrcFileSystem(created)
        }
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val fileSystem = fs ?: error("prepare")
        val path = Path("mem:///w-${++seq}.orc")
        val opts =
            OrcFile.writerOptions(conf)
                .setSchema(schema)
                .fileSystem(fileSystem)
                .blockPadding(false)
                .overwrite(true)
        if (uncompressed) {
            opts.compress(CompressionKind.NONE)
        }
        OrcFile.createWriter(path, opts).use { writer ->
            val rows = schema.createRowBatch()
            when (typeId) {
                "table", "table_project" -> writeTable(writer, rows, V2Rows.tables(fx.value))
                "nested_table" -> writeNested(writer, rows, V2Rows.nested(fx.value))
                "signal" -> writeSignal(writer, rows, V2Rows.signals(fx.value))
                else -> throw IllegalArgumentException(typeId)
            }
        }
        return fileSystem.take(path)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val fileSystem = fs ?: error("prepare")
        val path = fileSystem.putBytes(data)
        try {
            OrcFile.createReader(path, OrcFile.readerOptions(conf).filesystem(fileSystem)).use { reader ->
                val fileSchema = reader.schema
                val options = reader.options()
                if (project) {
                    val include = BooleanArray(fileSchema.maximumId + 1)
                    include[0] = true
                    include[fileSchema.children[0].id] = true
                    options.include(include)
                }
                reader.rows(options).use { rows ->
                    val batchRows = fileSchema.createRowBatch()
                    if (project) {
                        val col = ArrayList<Double>()
                        while (rows.nextBatch(batchRows)) {
                            val v = batchRows.cols[0] as DoubleColumnVector
                            for (r in 0 until batchRows.size) col.add(dbl(v, r))
                        }
                        return col
                    }
                    val out = ArrayList<Any>()
                    while (rows.nextBatch(batchRows)) {
                        for (r in 0 until batchRows.size) out.add(readRow(batchRows, r))
                    }
                    return V2Rows.oneOrList(out, batch)
                }
            }
        } finally {
            fileSystem.delete(path, false)
        }
    }

    private fun readRow(batchRows: VectorizedRowBatch, r: Int): Any =
        when (typeId) {
            "table", "table_project" -> readTable(batchRows, r)
            "nested_table" -> readNested(batchRows, r)
            "signal" -> readSignal(batchRows, r)
            else -> throw IllegalArgumentException(typeId)
        }

    companion object {
        private fun writeTable(writer: Writer, batch: VectorizedRowBatch, rows: List<TableRow>) {
            val floats = Array(16) { batch.cols[it] as DoubleColumnVector }
            val ints = Array(4) { batch.cols[16 + it] as LongColumnVector }
            val s0 = batch.cols[20] as BytesColumnVector
            val s1 = batch.cols[21] as BytesColumnVector
            for (row in rows) {
                val r = batch.size
                batch.size = r + 1
                putDoubles(floats, r, row)
                ints[0].vector[r] = row.fInt0
                ints[1].vector[r] = row.fInt1
                ints[2].vector[r] = row.fInt2
                ints[3].vector[r] = row.fInt3
                s0.setVal(r, bytes(row.fStr0))
                s1.setVal(r, bytes(row.fStr1))
                if (batch.size == batch.maxSize) {
                    writer.addRowBatch(batch)
                    batch.reset()
                }
            }
            if (batch.size != 0) writer.addRowBatch(batch)
        }

        private fun writeNested(writer: Writer, batch: VectorizedRowBatch, rows: List<NestedRow>) {
            val ids = batch.cols[0] as BytesColumnVector
            val status = batch.cols[1] as LongColumnVector
            val meta = batch.cols[2] as StructColumnVector
            val region = meta.fields[0] as BytesColumnVector
            val version = meta.fields[1] as LongColumnVector
            val items = batch.cols[3] as ListColumnVector
            val child = items.child as StructColumnVector
            val sku = child.fields[0] as BytesColumnVector
            val qty = child.fields[1] as LongColumnVector
            val price = child.fields[2] as LongColumnVector
            for (row in rows) {
                val r = batch.size
                batch.size = r + 1
                ids.setVal(r, bytes(row.id))
                status.vector[r] = row.status.toLong()
                region.setVal(r, bytes(row.meta.region))
                version.vector[r] = row.meta.version.toLong()
                val n = row.items.size
                grow(child, items.childCount + n)
                val start = items.childCount
                for (j in 0 until n) {
                    val it = row.items[j]
                    val idx = start + j
                    sku.setVal(idx, bytes(it.sku))
                    qty.vector[idx] = it.qty.toLong()
                    price.vector[idx] = it.priceMinor
                }
                items.offsets[r] = start.toLong()
                items.lengths[r] = n.toLong()
                items.childCount = start + n
                if (batch.size == batch.maxSize) {
                    writer.addRowBatch(batch)
                    batch.reset()
                }
            }
            if (batch.size != 0) writer.addRowBatch(batch)
        }

        private fun writeSignal(writer: Writer, batch: VectorizedRowBatch, rows: List<Signal>) {
            val seq = batch.cols[0] as LongColumnVector
            val ts = batch.cols[1] as LongColumnVector
            val price = batch.cols[2] as LongColumnVector
            val qty = batch.cols[3] as LongColumnVector
            val flags = batch.cols[4] as LongColumnVector
            val symbol = batch.cols[5] as BytesColumnVector
            val venue = batch.cols[6] as BytesColumnVector
            val legs = batch.cols[7] as ListColumnVector
            val child = legs.child as StructColumnVector
            val legId = child.fields[0] as LongColumnVector
            val legQty = child.fields[1] as LongColumnVector
            val legPad = child.fields[2] as LongColumnVector
            for (row in rows) {
                val r = batch.size
                batch.size = r + 1
                seq.vector[r] = row.seq
                ts.vector[r] = row.ts
                price.vector[r] = row.priceMantissa
                qty.vector[r] = row.qty.toLong()
                flags.vector[r] = row.flags.toLong()
                symbol.setVal(r, bytes(row.symbol))
                venue.setVal(r, bytes(row.venue))
                val n = row.legs.size
                grow(child, legs.childCount + n)
                val start = legs.childCount
                for (j in 0 until n) {
                    val leg = row.legs[j]
                    val idx = start + j
                    legId.vector[idx] = leg.legId
                    legQty.vector[idx] = leg.legQty.toLong()
                    legPad.vector[idx] = 0
                }
                legs.offsets[r] = start.toLong()
                legs.lengths[r] = n.toLong()
                legs.childCount = start + n
                if (batch.size == batch.maxSize) {
                    writer.addRowBatch(batch)
                    batch.reset()
                }
            }
            if (batch.size != 0) writer.addRowBatch(batch)
        }

        private fun readTable(batch: VectorizedRowBatch, r: Int): TableRow {
            val row = TableRow()
            row.fFloat0 = dbl(batch.cols[0] as DoubleColumnVector, r)
            row.fFloat1 = dbl(batch.cols[1] as DoubleColumnVector, r)
            row.fFloat2 = dbl(batch.cols[2] as DoubleColumnVector, r)
            row.fFloat3 = dbl(batch.cols[3] as DoubleColumnVector, r)
            row.fFloat4 = dbl(batch.cols[4] as DoubleColumnVector, r)
            row.fFloat5 = dbl(batch.cols[5] as DoubleColumnVector, r)
            row.fFloat6 = dbl(batch.cols[6] as DoubleColumnVector, r)
            row.fFloat7 = dbl(batch.cols[7] as DoubleColumnVector, r)
            row.fFloat8 = dbl(batch.cols[8] as DoubleColumnVector, r)
            row.fFloat9 = dbl(batch.cols[9] as DoubleColumnVector, r)
            row.fFloat10 = dbl(batch.cols[10] as DoubleColumnVector, r)
            row.fFloat11 = dbl(batch.cols[11] as DoubleColumnVector, r)
            row.fFloat12 = dbl(batch.cols[12] as DoubleColumnVector, r)
            row.fFloat13 = dbl(batch.cols[13] as DoubleColumnVector, r)
            row.fFloat14 = dbl(batch.cols[14] as DoubleColumnVector, r)
            row.fFloat15 = dbl(batch.cols[15] as DoubleColumnVector, r)
            row.fInt0 = lng(batch.cols[16] as LongColumnVector, r)
            row.fInt1 = lng(batch.cols[17] as LongColumnVector, r)
            row.fInt2 = lng(batch.cols[18] as LongColumnVector, r)
            row.fInt3 = lng(batch.cols[19] as LongColumnVector, r)
            row.fStr0 = str(batch.cols[20] as BytesColumnVector, r)
            row.fStr1 = str(batch.cols[21] as BytesColumnVector, r)
            return row
        }

        private fun readNested(batch: VectorizedRowBatch, r: Int): NestedRow {
            val meta = batch.cols[2] as StructColumnVector
            val items = batch.cols[3] as ListColumnVector
            val child = items.child as StructColumnVector
            val row = NestedRow()
            row.id = str(batch.cols[0] as BytesColumnVector, r)
            row.status = lng(batch.cols[1] as LongColumnVector, r).toInt()
            row.meta =
                NestedRow.NestedMeta(
                    str(meta.fields[0] as BytesColumnVector, r),
                    lng(meta.fields[1] as LongColumnVector, r).toInt(),
                )
            val n = items.lengths[r].toInt()
            val start = items.offsets[r].toInt()
            for (j in 0 until n) {
                val idx = start + j
                row.items.add(
                    NestedRow.NestedItem(
                        str(child.fields[0] as BytesColumnVector, idx),
                        lng(child.fields[1] as LongColumnVector, idx).toInt(),
                        lng(child.fields[2] as LongColumnVector, idx),
                    ),
                )
            }
            return row
        }

        private fun readSignal(batch: VectorizedRowBatch, r: Int): Signal {
            val legs = batch.cols[7] as ListColumnVector
            val child = legs.child as StructColumnVector
            val row = Signal()
            row.seq = lng(batch.cols[0] as LongColumnVector, r)
            row.ts = lng(batch.cols[1] as LongColumnVector, r)
            row.priceMantissa = lng(batch.cols[2] as LongColumnVector, r)
            row.qty = lng(batch.cols[3] as LongColumnVector, r).toInt()
            row.flags = lng(batch.cols[4] as LongColumnVector, r).toInt()
            row.symbol = str(batch.cols[5] as BytesColumnVector, r)
            row.venue = str(batch.cols[6] as BytesColumnVector, r)
            val n = legs.lengths[r].toInt()
            val start = legs.offsets[r].toInt()
            for (j in 0 until n) {
                val idx = start + j
                row.legs.add(
                    Signal.SignalLeg(
                        lng(child.fields[0] as LongColumnVector, idx),
                        lng(child.fields[1] as LongColumnVector, idx).toInt(),
                        lng(child.fields[2] as LongColumnVector, idx).toInt(),
                    ),
                )
            }
            return row
        }

        private fun putDoubles(cols: Array<DoubleColumnVector>, r: Int, row: TableRow) {
            cols[0].vector[r] = row.fFloat0
            cols[1].vector[r] = row.fFloat1
            cols[2].vector[r] = row.fFloat2
            cols[3].vector[r] = row.fFloat3
            cols[4].vector[r] = row.fFloat4
            cols[5].vector[r] = row.fFloat5
            cols[6].vector[r] = row.fFloat6
            cols[7].vector[r] = row.fFloat7
            cols[8].vector[r] = row.fFloat8
            cols[9].vector[r] = row.fFloat9
            cols[10].vector[r] = row.fFloat10
            cols[11].vector[r] = row.fFloat11
            cols[12].vector[r] = row.fFloat12
            cols[13].vector[r] = row.fFloat13
            cols[14].vector[r] = row.fFloat14
            cols[15].vector[r] = row.fFloat15
        }

        private fun grow(child: ColumnVector, size: Int) {
            if (size > 0) child.ensureSize(size, true)
        }

        private fun dbl(v: DoubleColumnVector, rowIn: Int): Double {
            val row = if (v.isRepeating) 0 else rowIn
            return v.vector[row]
        }

        private fun lng(v: LongColumnVector, rowIn: Int): Long {
            val row = if (v.isRepeating) 0 else rowIn
            return v.vector[row]
        }

        private fun str(v: BytesColumnVector, rowIn: Int): String {
            val row = if (v.isRepeating) 0 else rowIn
            if (!v.noNulls && v.isNull[row]) return ""
            return v.toString(row) ?: ""
        }

        private fun bytes(s: String?): ByteArray = (s ?: "").toByteArray(Charsets.UTF_8)

        private fun tableSchema(): TypeDescription {
            val schema = TypeDescription.createStruct()
            for (i in 0 until 16) schema.addField("f_float_$i", TypeDescription.createDouble())
            for (i in 0 until 4) schema.addField("f_int_$i", TypeDescription.createLong())
            schema.addField("f_str_0", TypeDescription.createString())
            schema.addField("f_str_1", TypeDescription.createString())
            return schema
        }

        private fun nestedSchema(): TypeDescription {
            val meta =
                TypeDescription.createStruct()
                    .addField("region", TypeDescription.createString())
                    .addField("version", TypeDescription.createInt())
            val item =
                TypeDescription.createStruct()
                    .addField("sku", TypeDescription.createString())
                    .addField("qty", TypeDescription.createInt())
                    .addField("price_minor", TypeDescription.createLong())
            return TypeDescription.createStruct()
                .addField("id", TypeDescription.createString())
                .addField("status", TypeDescription.createInt())
                .addField("meta", meta)
                .addField("items", TypeDescription.createList(item))
        }

        private fun signalSchema(): TypeDescription {
            val leg =
                TypeDescription.createStruct()
                    .addField("leg_id", TypeDescription.createLong())
                    .addField("leg_qty", TypeDescription.createInt())
                    .addField("leg_pad", TypeDescription.createInt())
            return TypeDescription.createStruct()
                .addField("seq", TypeDescription.createLong())
                .addField("ts", TypeDescription.createLong())
                .addField("price_mantissa", TypeDescription.createLong())
                .addField("qty", TypeDescription.createInt())
                .addField("flags", TypeDescription.createInt())
                .addField("symbol", TypeDescription.createString())
                .addField("venue", TypeDescription.createString())
                .addField("legs", TypeDescription.createList(leg))
        }
    }
}

/** ORC row. Does not call WriterOptions.compress. Default codec is ZSTD. */
class OrcSer : AbstractOrcSer("orc", false)

/** ORC row that sets [CompressionKind.NONE]. */
class OrcUncompressedSer : AbstractOrcSer("orc-uncompressed", true)
