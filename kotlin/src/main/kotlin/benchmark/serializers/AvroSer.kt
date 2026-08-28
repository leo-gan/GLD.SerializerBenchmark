package benchmark.serializers

import benchmark.model.Fixture
import org.apache.avro.Schema
import org.apache.avro.io.BinaryDecoder
import org.apache.avro.io.BinaryEncoder
import org.apache.avro.io.DecoderFactory
import org.apache.avro.io.EncoderFactory
import org.apache.avro.reflect.ReflectData
import org.apache.avro.reflect.ReflectDatumReader
import org.apache.avro.reflect.ReflectDatumWriter
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Apache Avro (reflect binding) — schema-based binary used widely in data pipelines.
 *
 * Hot path: derive schema once via [ReflectData]; reuse writer/reader and encoder/decoder.
 */
class AvroSer : BenchSerializer {
    private lateinit var schema: Schema
    private lateinit var writer: ReflectDatumWriter<Any>
    private lateinit var reader: ReflectDatumReader<Any>
    private val baos = ByteArrayOutputStream(4096)
    private var encoder: BinaryEncoder? = null
    private var decoder: BinaryDecoder? = null

    override fun name() = "avro"

    override fun version() = Versions.of(Schema::class.java)

    override fun streamMode() = "native"

    override fun nativeKind() = "schema"

    override fun prepare(fx: Fixture) {
        schema =
            if (TypeUtil.isList(fx.value)) {
                Schema.createArray(ReflectData.get().getSchema(TypeUtil.elementClass(fx.value)))
            } else {
                ReflectData.get().getSchema(fx.value.javaClass)
            }
        writer = ReflectDatumWriter(schema, ReflectData.get())
        reader = ReflectDatumReader(schema, schema, ReflectData.get())
        baos.reset()
        encoder = null
        decoder = null
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        baos.reset()
        encoder = EncoderFactory.get().binaryEncoder(baos, encoder)
        writer.write(fx.value, encoder)
        encoder!!.flush()
        return baos.toByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any {
        decoder = DecoderFactory.get().binaryDecoder(data, decoder)
        return reader.read(null, decoder)
    }

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val cos = CountingOutputStream(out)
        encoder = EncoderFactory.get().binaryEncoder(cos, encoder)
        writer.write(fx.value, encoder)
        encoder!!.flush()
        return cos.count
    }

    override fun deserializeStream(input: InputStream): Any {
        decoder = DecoderFactory.get().binaryDecoder(input, decoder)
        return reader.read(null, decoder)
    }
}
