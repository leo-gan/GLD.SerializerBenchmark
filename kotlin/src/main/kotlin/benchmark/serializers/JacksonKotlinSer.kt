package benchmark.serializers

import benchmark.model.Fixture
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.ObjectReader
import com.fasterxml.jackson.databind.ObjectWriter
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import java.io.InputStream
import java.io.OutputStream

/**
 * Jackson Kotlin module — dominant JVM JSON with first-class Kotlin data-class support.
 *
 * Hot path: reuse [ObjectMapper]; cache typed [ObjectWriter]/[ObjectReader].
 */
class JacksonKotlinSer : BenchSerializer {
    private val mapper: ObjectMapper =
        jacksonObjectMapper().apply {
            configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
            configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false)
        }
    private lateinit var writer: ObjectWriter
    private lateinit var reader: ObjectReader

    override fun name() = "jackson"

    override fun version() = Versions.of(ObjectMapper::class.java)

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
