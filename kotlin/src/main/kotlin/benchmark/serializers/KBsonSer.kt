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

    override fun prepare(fx: Fixture) {
        serializer = TypeUtil.kotlinxSerializer(fx.value)
    }

    override fun serializeBytes(fx: Fixture): ByteArray = kbson.dump(serializer, fx.value)

    override fun deserializeBytes(data: ByteArray): Any = kbson.load(serializer, data)
}
