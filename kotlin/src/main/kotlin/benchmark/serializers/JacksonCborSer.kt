package benchmark.serializers

import benchmark.model.Fixture
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.ObjectReader
import com.fasterxml.jackson.databind.ObjectWriter
import com.fasterxml.jackson.dataformat.cbor.CBORFactory
import com.fasterxml.jackson.dataformat.cbor.databind.CBORMapper
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import java.io.InputStream
import java.io.OutputStream

/**
 * Jackson CBOR + Kotlin module — IETF CBOR via FasterXML.
 *
 * Hot path: reuse [CBORMapper]; typed writer/reader; writeValueAsBytes/readValue.
 */
class JacksonCborSer : BenchSerializer {
    private val mapper: ObjectMapper = CBORMapper(CBORFactory()).registerKotlinModule()
    private lateinit var writer: ObjectWriter
    private lateinit var reader: ObjectReader

    override fun name() = "jackson-cbor"

    override fun version() = Versions.of(CBORMapper::class.java)

    override fun streamMode() = "native"

    override fun prepare(fx: Fixture) {
        if (TypeUtil.isList(fx.value)) {
            val ref = TypeUtil.listTypeRef(fx.value)
            writer = mapper.writerFor(ref)
            reader = mapper.readerFor(ref)
        } else {
            writer = mapper.writerFor(fx.value.javaClass)
            reader = mapper.readerFor(fx.value.javaClass)
        }
    }

    override fun serializeBytes(fx: Fixture): ByteArray = writer.writeValueAsBytes(fx.value)

    override fun deserializeBytes(data: ByteArray): Any = reader.readValue(data)

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val cos = CountingOutputStream(out)
        writer.writeValue(cos, fx.value)
        return cos.count
    }

    override fun deserializeStream(input: InputStream): Any = reader.readValue(input)
}
