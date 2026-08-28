package benchmark.model.v2

import com.squareup.moshi.JsonClass
import kotlinx.serialization.Serializable
import kotlinx.serialization.protobuf.ProtoNumber
import java.io.Serializable as JavaSerializable

/** Single-level mixed-primitive record (type_id=message). */
@Serializable
@JsonClass(generateAdapter = true)
data class Message(
    @ProtoNumber(1) @JvmField var fBool: Boolean = false,
    @ProtoNumber(2) @JvmField var fInt32: Int = 0,
    @ProtoNumber(3) @JvmField var fInt64: Long = 0L,
    @ProtoNumber(4) @JvmField var fFloat64: Double = 0.0,
    @ProtoNumber(5) @JvmField var fString: String = "",
    @ProtoNumber(6) @JvmField var fBool2: Boolean = false,
    @ProtoNumber(7) @JvmField var fInt32_2: Int = 0,
    @ProtoNumber(8) @JvmField var fString2: String = "",
) : JavaSerializable {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Message) return false
        return fBool == other.fBool &&
            fInt32 == other.fInt32 &&
            fInt64 == other.fInt64 &&
            kotlin.math.abs(other.fFloat64 - fFloat64) <= 1e-5 &&
            fBool2 == other.fBool2 &&
            fInt32_2 == other.fInt32_2 &&
            fString == other.fString &&
            fString2 == other.fString2
    }

    override fun hashCode(): Int {
        var result = fBool.hashCode()
        result = 31 * result + fInt32
        result = 31 * result + fInt64.hashCode()
        result = 31 * result + fFloat64.hashCode()
        result = 31 * result + fString.hashCode()
        result = 31 * result + fBool2.hashCode()
        result = 31 * result + fInt32_2
        result = 31 * result + fString2.hashCode()
        return result
    }
}
