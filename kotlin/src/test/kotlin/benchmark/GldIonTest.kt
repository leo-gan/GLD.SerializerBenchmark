package benchmark

import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.Event
import benchmark.model.v2.Generators
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import benchmark.serializers.GldIonSer
import benchmark.serializers.Registry
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class GldIonTest {
    @Test
    fun roundTripsOneMessage() {
        val ser = Registry.select("gld-ion,").single()
        assertTrue(ser is GldIonSer)
        assertEquals("gld-ion", ser.name())
        assertEquals("0.2.0", ser.version())
        assertEquals(listOf("kotlinx-ion", "gld-ion"), Registry.select("ion").map { it.name() })
        assertFalse(ser.supports("graph"))
        assertTrue(ser.supports("message"))

        roundTrip(ser, "message", 1)

        val edge =
            Message(
                fBool = true,
                fInt32 = Int.MIN_VALUE,
                fInt64 = Long.MIN_VALUE,
                fFloat64 = -1.25,
                fString = "héllo😀",
                fBool2 = false,
                fInt32_2 = Int.MAX_VALUE,
                fString2 = "",
            )
        val fx = Fixture("message", edge)
        ser.prepare(fx)
        val buf = ser.serializeBytes(fx)
        assertTrue(buf.size >= 4)
        assertEquals(0xE0.toByte(), buf[0])
        assertEquals(0x01.toByte(), buf[1])
        assertEquals(0x00.toByte(), buf[2])
        assertEquals(0xEA.toByte(), buf[3])
        assertTrue(buf.contentEquals(ser.serializeBytes(fx)))
        assertTrue(Fidelity.check(edge, ser.toDomain(ser.deserializeBytes(buf))))
    }

    @Test
    fun roundTripsSuiteTypesAndSkipsGraph() {
        val ser = GldIonSer()
        assertFalse(ser.supports("graph"))
        assertFalse(ser.supports("table"))
        for (type in arrayOf("message", "document", "telemetry", "strings", "event")) {
            assertTrue(ser.supports(type))
            roundTrip(ser, type, 1)
            roundTrip(ser, type, 2)
        }
    }

    private fun roundTrip(ser: benchmark.serializers.BenchSerializer, type: String, n: Int) {
        val insts = Generators.instances(type, emptyMap(), 42L, n)
        val expected: Any =
            if (n == 1) {
                insts[0]
            } else {
                when (type) {
                    "message" -> insts.map { it as Message }.toMutableList()
                    "document" -> insts.map { it as Document }.toMutableList()
                    "telemetry" -> insts.map { it as Telemetry }.toMutableList()
                    "strings" -> insts.map { it as Strings }.toMutableList()
                    "event" -> insts.map { it as Event }.toMutableList()
                    else -> error(type)
                }
            }
        val fx = Fixture(type, expected)
        ser.prepare(fx)
        val buf = ser.serializeBytes(fx)
        val out = ser.toDomain(ser.deserializeBytes(buf))
        assertTrue(Fidelity.check(expected, out)) { "fidelity failed for $type n=$n" }
    }
}
