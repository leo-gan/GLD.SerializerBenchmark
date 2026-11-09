package benchmark

import benchmark.model.Fixture
import benchmark.model.v2.Generators
import benchmark.serializers.Avro4kSer
import benchmark.serializers.CapnProtoSer
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

/** Adapted writes use BenchSerializer's default: the byte buffer copied onto the stream. */
class AdaptedStreamTest {
    @Test
    fun avro4kStreamMatchesBytes() {
        val ser = Avro4kSer()
        val fx = Fixture("message", Generators.makeOne("message", emptyMap(), 42L, 0))
        ser.prepare(fx)
        val bytes = ser.serializeBytes(fx)
        val out = ByteArrayOutputStream()
        assertEquals(bytes.size, ser.serializeStream(fx, out))
        assertTrue(bytes.contentEquals(out.toByteArray()))
        val back = ser.deserializeStream(ByteArrayInputStream(bytes))
        assertEquals(ser.deserializeBytes(bytes), back)
    }

    @Test
    fun capnProtoWriteMatchesBytesAndReadStaysNative() {
        val ser = CapnProtoSer()
        val fx = Fixture("message", Generators.makeOne("message", emptyMap(), 42L, 0))
        ser.prepare(fx)
        val bytes = ser.serializeBytes(fx)
        val out = ByteArrayOutputStream()
        assertEquals(bytes.size, ser.serializeStream(fx, out))
        assertTrue(bytes.contentEquals(out.toByteArray()))
        val back = ser.deserializeStream(ByteArrayInputStream(bytes))
        assertEquals(ser.toDomain(ser.deserializeBytes(bytes)), ser.toDomain(back))
    }
}
