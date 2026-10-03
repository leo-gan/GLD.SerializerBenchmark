package benchmark.model.v2

import kotlinx.serialization.Serializable
import java.io.Serializable as JavaSerializable

/** Struct plus a list of structs (type_id=nested_table). Not an SBE body. */
@Serializable
data class NestedRow @JvmOverloads constructor(
    @JvmField var id: String = "",
    @JvmField var status: Int = 0,
    @JvmField var meta: NestedMeta = NestedMeta(),
    @JvmField var items: MutableList<NestedItem> = mutableListOf(),
) : JavaSerializable {
    @Serializable
    data class NestedMeta @JvmOverloads constructor(
        @JvmField var region: String = "",
        @JvmField var version: Int = 0,
    ) : JavaSerializable

    @Serializable
    data class NestedItem @JvmOverloads constructor(
        @JvmField var sku: String = "",
        @JvmField var qty: Int = 0,
        @JvmField var priceMinor: Long = 0L,
    ) : JavaSerializable
}
