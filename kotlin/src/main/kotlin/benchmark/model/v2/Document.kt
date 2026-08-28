package benchmark.model.v2

import com.squareup.moshi.JsonClass
import kotlinx.serialization.Serializable
import kotlinx.serialization.protobuf.ProtoNumber
import java.io.Serializable as JavaSerializable

@Serializable
@JsonClass(generateAdapter = true)
data class DocumentMeta(
    @ProtoNumber(1) @JvmField var region: String = "",
    @ProtoNumber(2) @JvmField var version: Int = 0,
) : JavaSerializable

@Serializable
@JsonClass(generateAdapter = true)
data class DocumentItem(
    @ProtoNumber(1) @JvmField var sku: String = "",
    @ProtoNumber(2) @JvmField var qty: Int = 0,
    @ProtoNumber(3) @JvmField var priceMinor: Long = 0L,
) : JavaSerializable

@Serializable
@JsonClass(generateAdapter = true)
data class Document(
    @ProtoNumber(1) @JvmField var id: String = "",
    @ProtoNumber(2) @JvmField var status: Int = 0,
    @ProtoNumber(3) @JvmField var meta: DocumentMeta = DocumentMeta(),
    @ProtoNumber(4) @JvmField var items: MutableList<DocumentItem> = mutableListOf(),
) : JavaSerializable
