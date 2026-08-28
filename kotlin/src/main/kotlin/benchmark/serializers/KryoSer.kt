package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.DocumentItem
import benchmark.model.v2.DocumentMeta
import benchmark.model.v2.Event
import benchmark.model.v2.EventAttr
import benchmark.model.v2.Message
import benchmark.model.v2.Strings
import benchmark.model.v2.Telemetry
import com.esotericsoftware.kryo.Kryo
import com.esotericsoftware.kryo.io.Input
import com.esotericsoftware.kryo.io.Output
import com.esotericsoftware.kryo.util.DefaultInstantiatorStrategy
import org.objenesis.strategy.StdInstantiatorStrategy
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Kryo — dominant high-performance JVM binary serializer.
 *
 * Hot path: reuse one [Kryo] + [Output]/[Input]; register suite types; writeClassAndObject.
 */
class KryoSer : BenchSerializer {
    private val kryo: Kryo =
        Kryo().apply {
            isRegistrationRequired = false
            references = true
            instantiatorStrategy = DefaultInstantiatorStrategy(StdInstantiatorStrategy())
            register(Message::class.java)
            register(Document::class.java)
            register(DocumentMeta::class.java)
            register(DocumentItem::class.java)
            register(Telemetry::class.java)
            register(Strings::class.java)
            register(Event::class.java)
            register(EventAttr::class.java)
            register(ArrayList::class.java)
            register(MutableList::class.java)
        }
    private val baos = ByteArrayOutputStream(4096)
    private val output = Output(baos, 4096)
    private val input = Input(4096)

    override fun name() = "kryo"

    override fun version() = Versions.of(Kryo::class.java)

    override fun streamMode() = "native"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        kryo.register(TypeUtil.elementClass(fx.value))
        kryo.register(fx.value.javaClass)
        baos.reset()
        output.reset()
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        baos.reset()
        output.setOutputStream(baos)
        output.reset()
        kryo.writeClassAndObject(output, fx.value)
        output.flush()
        return baos.toByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any {
        input.buffer = data
        return kryo.readClassAndObject(input)
    }

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        output.setOutputStream(out)
        output.reset()
        kryo.writeClassAndObject(output, fx.value)
        output.flush()
        return output.total().toInt()
    }

    override fun deserializeStream(input: InputStream): Any {
        this.input.setInputStream(input)
        return kryo.readClassAndObject(this.input)
    }
}
