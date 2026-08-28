package benchmark.model.v2

import com.squareup.moshi.JsonClass
import kotlinx.serialization.Serializable
import kotlinx.serialization.protobuf.ProtoNumber
import java.io.Serializable as JavaSerializable
import kotlin.math.abs

@Serializable
@JsonClass(generateAdapter = true)
data class Telemetry(
    @ProtoNumber(1) @JvmField var source: String = "",
    @ProtoNumber(2) @JvmField var ts: Long = 0L,
    @ProtoNumber(3) @JvmField var tags: MutableList<String> = mutableListOf(),
    @ProtoNumber(4) @JvmField var values: MutableList<Double> = mutableListOf(),
) : JavaSerializable {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Telemetry) return false
        if (ts != other.ts || source != other.source || tags != other.tags) return false
        if (values.size != other.values.size) return false
        for (i in values.indices) {
            if (abs(values[i] - other.values[i]) > 1e-5) return false
        }
        return true
    }

    override fun hashCode(): Int {
        var result = source.hashCode()
        result = 31 * result + ts.hashCode()
        result = 31 * result + tags.hashCode()
        result = 31 * result + values.hashCode()
        return result
    }
}
