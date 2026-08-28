package benchmark.serializers

import benchmark.model.Fixture
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken
import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonWriter
import java.io.InputStream
import java.io.InputStreamReader
import java.io.OutputStream
import java.io.OutputStreamWriter
import java.lang.reflect.Type
import java.nio.charset.StandardCharsets

/**
 * Gson — Google's widely deployed JSON library (JVM baseline).
 *
 * Hot path: reuse [Gson]; explicit [Type] for lists; stream via JsonWriter/JsonReader.
 */
class GsonSer : BenchSerializer {
    private val gson: Gson = GsonBuilder().disableHtmlEscaping().create()
    private lateinit var type: Type

    override fun name() = "gson"

    override fun version() = Versions.of(Gson::class.java)

    override fun streamMode() = "native"

    override fun prepare(fx: Fixture) {
        type =
            if (TypeUtil.isList(fx.value)) {
                TypeToken.getParameterized(List::class.java, TypeUtil.elementClass(fx.value)).type
            } else {
                fx.value.javaClass
            }
    }

    override fun serializeBytes(fx: Fixture): ByteArray =
        gson.toJson(fx.value, type).toByteArray(StandardCharsets.UTF_8)

    override fun deserializeBytes(data: ByteArray): Any =
        gson.fromJson(String(data, StandardCharsets.UTF_8), type)

    override fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val cos = CountingOutputStream(out)
        val osw = OutputStreamWriter(cos, StandardCharsets.UTF_8)
        val jw = gson.newJsonWriter(osw)
        gson.toJson(fx.value, type, jw)
        jw.flush()
        osw.flush()
        return cos.count
    }

    override fun deserializeStream(input: InputStream): Any {
        val jr = gson.newJsonReader(InputStreamReader(input, StandardCharsets.UTF_8))
        return gson.fromJson(jr, type)
    }
}
