package benchmark

import benchmark.model.Fixture
import benchmark.model.v2.Generators
import benchmark.serializers.KBsonSer
import benchmark.serializers.TomlktSer
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertTrue

class BatchWrapRoundtripTest {
    @Test
    fun tomlktDocumentBatchRoundtrip() {
        roundtrip(TomlktSer(), "document", 100)
    }

    @Test
    fun kbsonAllTypesBatchRoundtrip() {
        val kbson = KBsonSer()
        for (type in arrayOf("message", "document", "telemetry", "strings", "event")) {
            roundtrip(kbson, type, 8)
        }
    }

    private fun roundtrip(ser: benchmark.serializers.BenchSerializer, type: String, n: Int) {
        val insts = Generators.instances(type, emptyMap(), 42L, n)
        val fx = Fixture(type, insts)
        ser.prepare(fx)
        val buf = ser.serializeBytes(fx)
        val out = ser.toDomain(ser.deserializeBytes(buf))
        assertTrue(Fidelity.check(insts, out)) { "fidelity failed for ${ser.name()} on $type n=$n" }
    }
}
