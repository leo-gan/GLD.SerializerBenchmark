package benchmark.serializers

import benchmark.model.Fixture
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.properties.Properties
import kotlinx.serialization.properties.decodeFromStringMap
import kotlinx.serialization.properties.encodeToStringMap
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.Properties as JavaProperties

/**
 * kotlinx.serialization Properties — official flat key-value format family member.
 *
 * Hot path: reuse [Properties]; cache [KSerializer]; encodeToStringMap / decodeFromStringMap,
 * then official [java.util.Properties] store/load for the on-disk properties document.
 */
@OptIn(ExperimentalSerializationApi::class)
class KotlinxPropertiesSer : BenchSerializer {
    private val format = Properties
    private lateinit var serializer: KSerializer<Any>
    private var batch = false
    private var typeId: String = ""
    private val baos = ByteArrayOutputStream(512)

    override fun name() = "kotlinx-properties"

    override fun version() = Versions.of("kotlinx.serialization.properties.Properties")

    override fun streamMode() = "adapted"

    override fun nativeKind() = "message"

    override fun prepare(fx: Fixture) {
        batch = TypeUtil.isList(fx.value)
        typeId = fx.name
        serializer = if (batch) Wraps.serializer(typeId) else TypeUtil.kotlinxSerializer(fx.value)
        baos.reset()
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        val value = if (batch) Wraps.wrap(typeId, fx.value as List<*>) else fx.value
        val map = format.encodeToStringMap(serializer, value)
        val props = JavaProperties()
        props.putAll(map)
        baos.reset()
        props.store(baos, null)
        return baos.toByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any {
        val props = JavaProperties()
        props.load(ByteArrayInputStream(data))
        val map = LinkedHashMap<String, String>(props.size)
        for (name in props.stringPropertyNames()) {
            map[name] = props.getProperty(name)
        }
        val decoded = format.decodeFromStringMap(serializer, map)
        return if (batch) Wraps.unwrap(typeId, decoded) else decoded
    }
}
