package benchmark.serializers

import benchmark.model.Fixture
import com.squareup.moshi.JsonAdapter
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory
import okio.Buffer
import okio.buffer
import okio.source
import java.io.InputStream
import java.io.OutputStream
import java.lang.reflect.Type

/**
 * Moshi reflection — [KotlinJsonAdapterFactory] added first so it wins over `@JsonClass` adapters.
 *
 * Measures reflection overhead versus [MoshiCodegenSer].
 */
class MoshiReflectSer : BenchSerializer {
    private val moshi: Moshi = Moshi.Builder().add(KotlinJsonAdapterFactory()).build()
    private lateinit var adapter: JsonAdapter<Any>

    override fun name() = "moshi-reflect"

    override fun version() = Versions.of(Moshi::class.java)

    override fun streamMode() = "native"

    override fun prepare(fx: Fixture) {
        val type: Type =
            if (TypeUtil.isList(fx.value)) {
                Types.newParameterizedType(List::class.java, TypeUtil.elementClass(fx.value))
            } else {
                fx.value.javaClass
            }
        @Suppress("UNCHECKED_CAST")
        adapter = moshi.adapter<Any>(type) as JsonAdapter<Any>
    }

    override fun serializeBytes(fx: Fixture): ByteArray {
        val buf = Buffer()
        adapter.toJson(buf, fx.value)
        return buf.readByteArray()
    }

    override fun deserializeBytes(data: ByteArray): Any =
        adapter.fromJson(Buffer().write(data)) ?: throw IllegalStateException("moshi-reflect null")

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val buf = Buffer()
        adapter.toJson(buf, fx.value)
        val bytes = buf.readByteArray()
        out.write(bytes)
        return bytes.size
    }

    override fun deserializeStream(input: InputStream): Any =
        adapter.fromJson(input.source().buffer()) ?: throw IllegalStateException("moshi-reflect null")
}
