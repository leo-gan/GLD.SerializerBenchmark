package benchmark.serializers

import benchmark.model.Fixture
import io.protostuff.LinkedBuffer
import io.protostuff.ProtostuffIOUtil
import io.protostuff.Schema
import io.protostuff.runtime.RuntimeSchema
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Protostuff runtime — protobuf-style POJO binary without .proto.
 *
 * Hot path: cache [RuntimeSchema]; reuse [LinkedBuffer]; list APIs for batches.
 */
class ProtostuffSer : BenchSerializer {
    private val buffer = LinkedBuffer.allocate(LinkedBuffer.DEFAULT_BUFFER_SIZE)
    private val baos = ByteArrayOutputStream(4096)
    private lateinit var schema: Schema<Any>
    private var batch = false

    override fun name() = "protostuff"

    override fun version() = Versions.of(ProtostuffIOUtil::class.java)

    override fun streamMode() = "native"

    override fun nativeKind() = "schema"

    @Suppress("UNCHECKED_CAST")
    override fun prepare(fx: Fixture) {
        batch = TypeUtil.isList(fx.value)
        schema = RuntimeSchema.getSchema(TypeUtil.elementClass(fx.value)) as Schema<Any>
        buffer.clear()
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        buffer.clear()
        if (batch) {
            baos.reset()
            ProtostuffIOUtil.writeListTo(baos, fx.value as List<Any>, schema, buffer)
            return baos.toByteArray()
        }
        return ProtostuffIOUtil.toByteArray(fx.value, schema, buffer)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        if (batch) {
            return ProtostuffIOUtil.parseListFrom(ByteArrayInputStream(data), schema)
        }
        val msg = schema.newMessage()
        ProtostuffIOUtil.mergeFrom(data, msg, schema)
        return msg
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        buffer.clear()
        return if (batch) {
            ProtostuffIOUtil.writeListTo(out, fx.value as List<Any>, schema, buffer)
        } else {
            ProtostuffIOUtil.writeTo(out, fx.value, schema, buffer)
        }
    }

    override fun deserializeStream(input: InputStream): Any {
        if (batch) {
            return ProtostuffIOUtil.parseListFrom(input, schema)
        }
        val msg = schema.newMessage()
        ProtostuffIOUtil.mergeFrom(input, msg, schema)
        return msg
    }
}
