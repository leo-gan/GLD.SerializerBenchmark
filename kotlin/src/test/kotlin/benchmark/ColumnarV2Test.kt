package benchmark

import benchmark.model.Fixture
import benchmark.model.v2.Generators
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Rng
import benchmark.model.v2.Signal
import benchmark.model.v2.TableRow
import benchmark.serializers.AbstractParquetSer
import benchmark.serializers.OrcSer
import benchmark.serializers.OrcUncompressedSer
import benchmark.serializers.ParquetSer
import benchmark.serializers.ParquetUncompressedSer
import benchmark.serializers.Registry
import benchmark.serializers.SbeSer
import org.apache.parquet.hadoop.metadata.CompressionCodecName
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class ColumnarV2Test {
    @Test
    fun deterministicAndDistinctSeeds() {
        for (id in TYPES) {
            assertEquals(Generators.makeOne(id, emptyMap(), 42L, 3), Generators.makeOne(id, emptyMap(), 42L, 3))
            assertNotEquals(Generators.makeOne(id, emptyMap(), 42L, 3), Generators.makeOne(id, emptyMap(), 42L, 4))
        }
        assertNotEquals(
            Generators.makeOne("table", emptyMap(), 42L, 0),
            Generators.makeOne("table_project", emptyMap(), 42L, 0),
        )
    }

    @Test
    fun tableStringsRepeatAcrossFortyRows() {
        val rows = Generators.instances("table", emptyMap(), 42L, 40)
        val again = Generators.instances("table", emptyMap(), 42L, 40)
        assertEquals(rows, again)
        val uniq = rows.map { (it as TableRow).fStr0 }.toSet()
        assertTrue(uniq.size < rows.size) { "unique f_str_0 ${uniq.size}" }
    }

    @Test
    fun signalDomainOrderAndLegPad() {
        val s = Generators.makeOne("signal", emptyMap(), 9L, 0) as Signal
        val r = Rng(Rng.mixSeed(9L, "signal", 0))
        assertEquals(r.nextInt(0, 1_000_000_000).toLong(), s.seq)
        assertEquals(1_704_067_200_000L + r.nextInt(0, 86_400_000), s.ts)
        assertEquals(r.nextInt(0, 1_000_000_000).toLong(), s.priceMantissa)
        assertEquals(r.nextInt(0, 10_000), s.qty)
        assertEquals(r.nextInt(0, 65_535), s.flags)
        assertEquals(r.word(3, 12), s.symbol)
        assertEquals(r.word(3, 12), s.venue)
        assertEquals(4, s.legs.size)
        for (leg in s.legs) {
            assertEquals(r.nextInt(0, 1_000_000).toLong(), leg.legId)
            assertEquals(r.nextInt(0, 10_000), leg.legQty)
            assertEquals(0, leg.legPad)
        }
        val shortGroup = Generators.makeOne("signal", mapOf("group_count" to 2), 1L, 0) as Signal
        assertEquals(2, shortGroup.legs.size)
    }

    @Test
    fun nestedDefaults() {
        val row = Generators.makeOne("nested_table", emptyMap(), 5L, 1) as NestedRow
        assertEquals(4, row.items.size)
        assertTrue(row.id.isNotEmpty())
        assertTrue(row.meta.region.isNotEmpty())
        assertTrue(row.status in 0..5)
        assertTrue(row.meta.version in 1..10)
    }

    @Test
    fun filterAllowListPreservesRegistryOrder() {
        val names = Registry.names()
        assertEquals(32, names.size)
        assertEquals(names, Registry.select("").map { it.name() })
        val protobuf = Registry.select("protobuf").map { it.name() }
        assertTrue(protobuf.contains("protobuf"))
        assertTrue(protobuf.contains("protobuf-kotlin"))
        assertTrue(protobuf.contains("kotlinx-protobuf"))
        assertTrue(protobuf.size > 1)
        assertEquals(listOf("protobuf"), Registry.select("protobuf,").map { it.name() })
        assertEquals(listOf("protobuf", "avro"), Registry.select("protobuf,avro").map { it.name() })
        assertEquals(listOf("orc", "orc-uncompressed"), Registry.select("orc").map { it.name() })
        assertEquals(listOf("orc"), Registry.select("orc,").map { it.name() })
        assertEquals(ALLOW_ORDER, Registry.select(ALLOW).map { it.name() })
    }

    @Test
    fun roundTripNewRowsAndPeers() {
        val sers = Registry.select(ALLOW)
        assertEquals(ALLOW_ORDER, sers.map { it.name() })
        for (type in TYPES) {
            for (n in intArrayOf(1, 100)) {
                val fx = fixture(type, n)
                val expected = Fidelity.expectedForFidelity(type, fx.value)
                for (ser in sers) {
                    if (!ser.supports(type)) {
                        assertEquals("sbe", ser.name())
                        assertEquals("nested_table", type)
                        continue
                    }
                    ser.prepare(fx)
                    val buf = ser.serializeBytes(fx)
                    val out = ser.toDomain(ser.deserializeBytes(buf))
                    assertTrue(Fidelity.check(expected, out)) { "${ser.name()} $type N=$n" }
                    if (type == "table_project") {
                        assertTrue(out is List<*>)
                        assertEquals(n, (out as List<*>).size)
                    }
                    val baos = ByteArrayOutputStream()
                    val written = ser.serializeStream(fx, baos)
                    assertTrue(written >= 0)
                    val streamed = ser.toDomain(ser.deserializeStream(ByteArrayInputStream(baos.toByteArray())))
                    assertTrue(Fidelity.check(expected, streamed)) { "stream ${ser.name()} $type N=$n" }
                }
            }
        }
        assertFalse(SbeSer().supports("nested_table"))
        assertFalse(SbeSer().supports("message"))
        assertTrue(SbeSer().supports("signal"))
    }

    @Test
    fun orcPayloadsDifferAndParquetSetsSnappy() {
        val fx = fixture("table", 100)
        val orc = OrcSer()
        val raw = OrcUncompressedSer()
        orc.prepare(fx)
        raw.prepare(fx)
        val zstd = orc.serializeBytes(fx)
        val none = raw.serializeBytes(fx)
        assertFalse(zstd.contentEquals(none)) { "orc and orc-uncompressed payloads match" }

        val parquet = ParquetSer()
        val uncompressed = ParquetUncompressedSer()
        parquet.prepare(fx)
        uncompressed.prepare(fx)
        val def = parquet.serializeBytes(fx)
        val unc = uncompressed.serializeBytes(fx)
        assertEquals(CompressionCodecName.SNAPPY, AbstractParquetSer.footerCodec(def))
        assertEquals(CompressionCodecName.UNCOMPRESSED, AbstractParquetSer.footerCodec(unc))
        assertFalse(def.contentEquals(unc))
    }

    @Test
    fun projectionDeserializeTimes() {
        val n = 10_000
        val reps = 5
        for (name in listOf("arrow-ipc", "parquet", "orc")) {
            val ser = Registry.select("$name,").single()
            val full = medianDeser(ser, "table", n, reps)
            val proj = medianDeser(ser, "table_project", n, reps)
            val ratio = proj / full.toDouble()
            println("PROJECTION $name table_ns=$full table_project_ns=$proj ratio=${"%.3f".format(ratio)}")
            assertTrue(ratio < 0.75) { "$name projection ratio $ratio is not clearly faster" }
        }
    }

    private fun medianDeser(
        ser: benchmark.serializers.BenchSerializer,
        type: String,
        n: Int,
        reps: Int,
    ): Long {
        val fx = fixture(type, n)
        ser.prepare(fx)
        val buf = ser.serializeBytes(fx)
        val expected = Fidelity.expectedForFidelity(type, fx.value)
        repeat(3) {
            val warm = ser.toDomain(ser.deserializeBytes(buf))
            assertTrue(Fidelity.check(expected, warm)) { "${ser.name()} $type warmup" }
        }
        val samples = LongArray(reps)
        for (i in 0 until reps) {
            val t0 = System.nanoTime()
            val out = ser.toDomain(ser.deserializeBytes(buf))
            samples[i] = System.nanoTime() - t0
            assertTrue(Fidelity.check(expected, out)) { "${ser.name()} $type" }
        }
        samples.sort()
        return samples[samples.size / 2]
    }

    private fun fixture(type: String, n: Int): Fixture {
        val inst = Generators.instances(type, emptyMap(), 42L, n)
        if (n == 1) return Fixture(type, inst[0])
        return Fixture(type, ArrayList(inst))
    }

    companion object {
        private val TYPES = arrayOf("table", "table_project", "nested_table", "signal")
        private const val ALLOW =
            "arrow-ipc,parquet,parquet-uncompressed,orc,orc-uncompressed,sbe,kotlinx-json,protobuf,flatbuffers,avro"
        private val ALLOW_ORDER =
            listOf(
                "kotlinx-json",
                "protobuf",
                "avro",
                "flatbuffers",
                "arrow-ipc",
                "parquet",
                "parquet-uncompressed",
                "orc",
                "orc-uncompressed",
                "sbe",
            )
    }
}
