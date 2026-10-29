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
import org.apache.fory.Fory
import org.apache.fory.io.ForyInputStream
import org.apache.fory.kotlin.ForyKotlin
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Apache Fory — JIT/codegen high-performance binary serialization.
 *
 * Reuses one Fory instance and registers types before first use.
 */
class ForySer : BenchSerializer {
    private val fory: Fory =
        ForyKotlin.builder()
            .withXlang(false)
            .requireClassRegistration(true)
            .withRefTracking(false)
            .withCodegen(true)
            .build()
            .also {
                it.register(Message::class.java)
                it.register(Document::class.java)
                it.register(DocumentMeta::class.java)
                it.register(DocumentItem::class.java)
                it.register(Telemetry::class.java)
                it.register(Strings::class.java)
                it.register(Event::class.java)
                it.register(EventAttr::class.java)
                it.register(ArrayList::class.java)
            }

    override fun name() = "fory"

    override fun version() = Versions.of(Fory::class.java)

    /**
     * Uses the interface's adapted stream methods, which bridge through byte arrays.
     * This serializer implements the byte-array API directly.
     */
    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        // Warm up the byte-array path.
        val bytes = fory.serialize(fx.value)
        fory.deserialize(bytes)

        // Warm up the direct stream path outside the timed benchmark.
        val output = ByteArrayOutputStream()
        fory.serialize(output, fx.value)
        fory.deserialize(ForyInputStream(ByteArrayInputStream(output.toByteArray())))
    }

    override fun serializeBytes(fx: Fixture): ByteArray =
        fory.serialize(fx.value)

    override fun deserializeBytes(data: ByteArray): Any =
        fory.deserialize(data)

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        fory.serialize(out, fx.value)

        // Main.measureStream treats a negative return as "use output size".
        return -1
    }

    override fun deserializeBytes(data: ByteArray): Any = fory.deserialize(data)
}
