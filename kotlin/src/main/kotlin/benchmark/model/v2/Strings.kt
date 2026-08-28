package benchmark.model.v2

import com.squareup.moshi.JsonClass
import kotlinx.serialization.Serializable
import kotlinx.serialization.protobuf.ProtoNumber
import java.io.Serializable as JavaSerializable

@Serializable
@JsonClass(generateAdapter = true)
data class Strings(
    @ProtoNumber(1) @JvmField var items: MutableList<String> = mutableListOf(),
) : JavaSerializable
