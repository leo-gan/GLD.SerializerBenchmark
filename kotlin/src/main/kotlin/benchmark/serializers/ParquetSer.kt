package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.TableRow
import benchmark.model.v2.V2Rows
import org.apache.avro.Schema
import org.apache.avro.generic.GenericData
import org.apache.avro.generic.GenericRecord
import org.apache.avro.generic.IndexedRecord
import org.apache.avro.specific.SpecificData
import org.apache.hadoop.conf.Configuration
import org.apache.parquet.avro.AvroParquetReader
import org.apache.parquet.avro.AvroParquetWriter
import org.apache.parquet.avro.AvroReadSupport
import org.apache.parquet.hadoop.ParquetFileReader
import org.apache.parquet.hadoop.metadata.CompressionCodecName
import org.apache.parquet.io.InputFile

/**
 * Parquet via parquet-avro.
 *
 * parquet-java 1.18.1 [org.apache.parquet.hadoop.ParquetWriter.DEFAULT_COMPRESSION_CODEC_NAME]
 * is UNCOMPRESSED. parquet sets [CompressionCodecName.SNAPPY]. parquet-uncompressed sets
 * [CompressionCodecName.UNCOMPRESSED].
 *
 * [AvroParquetReader.Builder.withDataModel] is called before withConf. withConf returns the
 * parent builder, which has no withDataModel.
 */
abstract class AbstractParquetSer(
    private val rowName: String,
    private val forceUncompressed: Boolean,
) : BenchSerializer {
    private var typeId: String = ""
    private var batch = false
    private var project = false
    private lateinit var schema: Schema
    private lateinit var writeConf: Configuration
    private lateinit var readConf: Configuration

    override fun name() = rowName

    override fun version() = Versions.of(AvroParquetWriter::class.java)

    override fun nativeKind() = "schema"

    override fun supports(testDataName: String) = testDataName in TypeUtil.COLUMNAR_IDS

    override fun prepare(fx: Fixture) {
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        project = typeId == "table_project"
        schema =
            when (typeId) {
                "table", "table_project" -> benchmark.v2.avro.Table.getClassSchema()
                "nested_table" -> benchmark.v2.avro.NestedRow.getClassSchema()
                "signal" -> benchmark.v2.avro.Signal.getClassSchema()
                else -> throw IllegalArgumentException(typeId)
            }
        writeConf = Configuration(false)
        readConf = Configuration(false)
        if (project) {
            val projected = projectFloat0(schema)
            AvroReadSupport.setRequestedProjection(readConf, projected)
            AvroReadSupport.setAvroReadSchema(readConf, projected)
        }
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val out = MemOutputFile()
        val builder =
            AvroParquetWriter.builder<GenericRecord>(out)
                .withSchema(schema)
                .withDataModel(SpecificData.get())
                .withConf(writeConf)
        builder.withCompressionCodec(
            if (forceUncompressed) CompressionCodecName.UNCOMPRESSED else CompressionCodecName.SNAPPY,
        )
        builder.build().use { writer ->
            for (rec in records(fx.value)) writer.write(rec)
        }
        return out.toByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val input: InputFile = MemInputFile(data)
        AvroParquetReader.builder<GenericRecord>(input)
            .withDataModel(if (project) GenericData.get() else SpecificData.get())
            .withConf(readConf)
            .build()
            .use { reader ->
                if (project) {
                    val col = ArrayList<Double>()
                    var rec = reader.read()
                    while (rec != null) {
                        col.add((get(rec, "f_float_0") as Number).toDouble())
                        rec = reader.read()
                    }
                    return col
                }
                val rows = ArrayList<Any>()
                var rec = reader.read()
                while (rec != null) {
                    rows.add(fromRecord(rec))
                    rec = reader.read()
                }
                return V2Rows.oneOrList(rows, batch)
            }
    }

    private fun records(value: Any): List<GenericRecord> =
        when (typeId) {
            "table", "table_project" -> V2Rows.tables(value).map { tableRecord(it) }
            "nested_table" -> V2Rows.nested(value).map { nestedRecord(it) }
            "signal" -> V2Rows.signals(value).map { signalRecord(it) }
            else -> throw IllegalArgumentException(typeId)
        }

    private fun fromRecord(rec: GenericRecord): Any =
        when (typeId) {
            "table", "table_project" -> fromTable(rec)
            "nested_table" -> fromNested(rec)
            "signal" -> fromSignal(rec)
            else -> throw IllegalArgumentException(typeId)
        }

    companion object {
        fun footerCodec(data: ByteArray): CompressionCodecName {
            ParquetFileReader.open(MemInputFile(data)).use { reader ->
                return reader.footer.blocks[0].columns[0].codec
            }
        }

        private fun tableRecord(row: TableRow): benchmark.v2.avro.Table {
            val rec = benchmark.v2.avro.Table()
            put(rec, "f_float_0", row.fFloat0)
            put(rec, "f_float_1", row.fFloat1)
            put(rec, "f_float_2", row.fFloat2)
            put(rec, "f_float_3", row.fFloat3)
            put(rec, "f_float_4", row.fFloat4)
            put(rec, "f_float_5", row.fFloat5)
            put(rec, "f_float_6", row.fFloat6)
            put(rec, "f_float_7", row.fFloat7)
            put(rec, "f_float_8", row.fFloat8)
            put(rec, "f_float_9", row.fFloat9)
            put(rec, "f_float_10", row.fFloat10)
            put(rec, "f_float_11", row.fFloat11)
            put(rec, "f_float_12", row.fFloat12)
            put(rec, "f_float_13", row.fFloat13)
            put(rec, "f_float_14", row.fFloat14)
            put(rec, "f_float_15", row.fFloat15)
            put(rec, "f_int_0", row.fInt0)
            put(rec, "f_int_1", row.fInt1)
            put(rec, "f_int_2", row.fInt2)
            put(rec, "f_int_3", row.fInt3)
            put(rec, "f_str_0", row.fStr0)
            put(rec, "f_str_1", row.fStr1)
            return rec
        }

        private fun nestedRecord(row: NestedRow): benchmark.v2.avro.NestedRow {
            val meta = benchmark.v2.avro.NestedMeta()
            put(meta, "region", row.meta.region)
            put(meta, "version", row.meta.version)
            val items = ArrayList<benchmark.v2.avro.NestedItem>()
            for (it in row.items) {
                val rec = benchmark.v2.avro.NestedItem()
                put(rec, "sku", it.sku)
                put(rec, "qty", it.qty)
                put(rec, "price_minor", it.priceMinor)
                items.add(rec)
            }
            val rec = benchmark.v2.avro.NestedRow()
            put(rec, "id", row.id)
            put(rec, "status", row.status)
            put(rec, "meta", meta)
            put(rec, "items", items)
            return rec
        }

        private fun signalRecord(row: Signal): benchmark.v2.avro.Signal {
            val legs = ArrayList<benchmark.v2.avro.SignalLeg>()
            for (leg in row.legs) {
                val rec = benchmark.v2.avro.SignalLeg()
                put(rec, "leg_id", leg.legId)
                put(rec, "leg_qty", leg.legQty)
                put(rec, "leg_pad", leg.legPad)
                legs.add(rec)
            }
            val rec = benchmark.v2.avro.Signal()
            put(rec, "seq", row.seq)
            put(rec, "ts", row.ts)
            put(rec, "price_mantissa", row.priceMantissa)
            put(rec, "qty", row.qty)
            put(rec, "flags", row.flags)
            put(rec, "symbol", row.symbol)
            put(rec, "venue", row.venue)
            put(rec, "legs", legs)
            return rec
        }

        private fun fromTable(rec: GenericRecord): TableRow {
            val row = TableRow()
            row.fFloat0 = num(get(rec, "f_float_0")).toDouble()
            row.fFloat1 = num(get(rec, "f_float_1")).toDouble()
            row.fFloat2 = num(get(rec, "f_float_2")).toDouble()
            row.fFloat3 = num(get(rec, "f_float_3")).toDouble()
            row.fFloat4 = num(get(rec, "f_float_4")).toDouble()
            row.fFloat5 = num(get(rec, "f_float_5")).toDouble()
            row.fFloat6 = num(get(rec, "f_float_6")).toDouble()
            row.fFloat7 = num(get(rec, "f_float_7")).toDouble()
            row.fFloat8 = num(get(rec, "f_float_8")).toDouble()
            row.fFloat9 = num(get(rec, "f_float_9")).toDouble()
            row.fFloat10 = num(get(rec, "f_float_10")).toDouble()
            row.fFloat11 = num(get(rec, "f_float_11")).toDouble()
            row.fFloat12 = num(get(rec, "f_float_12")).toDouble()
            row.fFloat13 = num(get(rec, "f_float_13")).toDouble()
            row.fFloat14 = num(get(rec, "f_float_14")).toDouble()
            row.fFloat15 = num(get(rec, "f_float_15")).toDouble()
            row.fInt0 = num(get(rec, "f_int_0")).toLong()
            row.fInt1 = num(get(rec, "f_int_1")).toLong()
            row.fInt2 = num(get(rec, "f_int_2")).toLong()
            row.fInt3 = num(get(rec, "f_int_3")).toLong()
            row.fStr0 = str(get(rec, "f_str_0"))
            row.fStr1 = str(get(rec, "f_str_1"))
            return row
        }

        private fun fromNested(rec: GenericRecord): NestedRow {
            val meta = get(rec, "meta") as GenericRecord
            val row = NestedRow()
            row.id = str(get(rec, "id"))
            row.status = num(get(rec, "status")).toInt()
            row.meta = NestedRow.NestedMeta(str(get(meta, "region")), num(get(meta, "version")).toInt())
            val items = get(rec, "items")
            if (items is List<*>) {
                for (o in items) {
                    val it = o as GenericRecord
                    row.items.add(
                        NestedRow.NestedItem(
                            str(get(it, "sku")),
                            num(get(it, "qty")).toInt(),
                            num(get(it, "price_minor")).toLong(),
                        ),
                    )
                }
            }
            return row
        }

        private fun fromSignal(rec: GenericRecord): Signal {
            val row = Signal()
            row.seq = num(get(rec, "seq")).toLong()
            row.ts = num(get(rec, "ts")).toLong()
            row.priceMantissa = num(get(rec, "price_mantissa")).toLong()
            row.qty = num(get(rec, "qty")).toInt()
            row.flags = num(get(rec, "flags")).toInt()
            row.symbol = str(get(rec, "symbol"))
            row.venue = str(get(rec, "venue"))
            val legs = get(rec, "legs")
            if (legs is List<*>) {
                for (o in legs) {
                    val leg = o as GenericRecord
                    row.legs.add(
                        Signal.SignalLeg(
                            num(get(leg, "leg_id")).toLong(),
                            num(get(leg, "leg_qty")).toInt(),
                            num(get(leg, "leg_pad")).toInt(),
                        ),
                    )
                }
            }
            return row
        }

        private fun projectFloat0(table: Schema): Schema {
            val src = table.getField("f_float_0")
            val copy = Schema.Field(src.name(), src.schema(), src.doc(), src.defaultVal())
            return Schema.createRecord(table.name, table.doc, table.namespace, false, listOf(copy))
        }

        private fun put(rec: IndexedRecord, name: String, value: Any?) {
            rec.put(rec.schema.getField(name).pos(), value)
        }

        private fun get(rec: IndexedRecord, name: String): Any? =
            rec.get(rec.schema.getField(name).pos())

        private fun num(o: Any?): Number {
            if (o is Number) return o
            error("expected number, got $o")
        }

        private fun str(o: Any?): String = o?.toString() ?: ""
    }
}

/** Parquet row. Sets [CompressionCodecName.SNAPPY] because 1.18.1 defaults to UNCOMPRESSED. */
class ParquetSer : AbstractParquetSer("parquet", false)

/** Parquet row that sets [CompressionCodecName.UNCOMPRESSED]. */
class ParquetUncompressedSer : AbstractParquetSer("parquet-uncompressed", true)
