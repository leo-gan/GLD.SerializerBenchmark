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
import org.apache.fory.config.Language

/**
 * Apache Fory — JIT/codegen high-performance binary serialization.
 *
 * Hot path: reuse one [Fory] with Language.JAVA + codegen; register types before first use.
 */
class ForySer : BenchSerializer {
    private val fory: Fory =
        Fory.builder()
            .withLanguage(Language.JAVA)
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

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        // Warm codegen for this root type (untimed).
        fory.deserialize(fory.serialize(fx.value))
    }

    override fun serializeBytes(fx: Fixture): ByteArray = fory.serialize(fx.value)

    override fun deserializeBytes(data: ByteArray): Any = fory.deserialize(data)
}
