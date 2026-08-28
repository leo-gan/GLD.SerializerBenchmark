package benchmark.serializers

import benchmark.model.Fixture
import com.squareup.moshi.JsonAdapter
import com.squareup.moshi.Moshi
import com.squareup.moshi.Types
import okio.Buffer
import okio.buffer
import okio.source
import java.io.InputStream
import java.io.OutputStream
import java.lang.reflect.Type

/**
 * Moshi Kotlin codegen — generated [JsonAdapter] via KSP `@JsonClass(generateAdapter = true)`.
 *
 * Hot path: reuse [Moshi]; cache typed adapter; Okio [Buffer] `toJson`/`fromJson`.
 */
class MoshiCodegenSer : BenchSerializer {
    private val moshi: Moshi = Moshi.Builder().build()
    private lateinit var adapter: JsonAdapter<Any>

    override fun name() = "moshi-codegen"

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
        adapter.fromJson(Buffer().write(data)) ?: throw IllegalStateException("moshi-codegen null")

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val buf = Buffer()
        adapter.toJson(buf, fx.value)
        val bytes = buf.readByteArray()
        out.write(bytes)
        return bytes.size
    }

    override fun deserializeStream(input: InputStream): Any =
        adapter.fromJson(input.source().buffer()) ?: throw IllegalStateException("moshi-codegen null")
}
