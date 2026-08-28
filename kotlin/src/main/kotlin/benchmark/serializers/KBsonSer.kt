package benchmark.serializers

import benchmark.model.Fixture
import com.github.jershell.kbson.KBson
import kotlinx.serialization.KSerializer

/**
 * KBson — BSON support for kotlinx.serialization (MongoDB document binary).
 *
 * Hot path: reuse [KBson]; cache [KSerializer]; dump / load ByteArray.
 */
class KBsonSer : BenchSerializer {
    private val kbson = KBson()
    private lateinit var serializer: KSerializer<Any>

    override fun name() = "kbson"

    override fun version() = Versions.of("com.github.jershell.kbson.KBson")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    private var batch = false
    private var typeId: String = ""

    override fun prepare(fx: Fixture) {
        batch = TypeUtil.isList(fx.value)
        typeId = fx.name
        // BSON documents cannot have an array at the root (MongoDB wire rule).
        serializer = if (batch) Wraps.serializer(typeId) else TypeUtil.kotlinxSerializer(fx.value)
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        val value = if (batch) Wraps.wrap(typeId, fx.value as List<*>) else fx.value
        return kbson.dump(serializer, value)
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val decoded = kbson.load(serializer, data)
        return if (batch) Wraps.unwrap(typeId, decoded) else decoded
    }
}
