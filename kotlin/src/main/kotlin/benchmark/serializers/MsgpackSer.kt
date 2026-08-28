package benchmark.serializers

import benchmark.model.Fixture
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.ObjectReader
import com.fasterxml.jackson.databind.ObjectWriter
import com.fasterxml.jackson.module.kotlin.registerKotlinModule
import org.msgpack.jackson.dataformat.MessagePackFactory
import org.msgpack.jackson.dataformat.MessagePackMapper
import java.io.InputStream
import java.io.OutputStream

/**
 * MessagePack via official msgpack-java Jackson binding + Kotlin module.
 *
 * Hot path: reuse [MessagePackMapper]; typed writer/reader; writeValueAsBytes/readValue.
 */
class MsgpackSer : BenchSerializer {
    private val mapper: ObjectMapper = MessagePackMapper(MessagePackFactory()).registerKotlinModule()
    private lateinit var writer: ObjectWriter
    private lateinit var reader: ObjectReader

    override fun name() = "msgpack"

    override fun version() = Versions.of(MessagePackMapper::class.java)

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
