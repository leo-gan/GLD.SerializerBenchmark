package benchmark.model.v2

import kotlinx.serialization.Serializable
import java.io.Serializable as JavaSerializable

/**
 * Fixed fields, then strings, then a repeating group (type_id=signal).
 * leg_pad is always 0 and is not drawn from the PRNG.
 * SBE wire order differs: the legs group is before symbol and venue.
 */
@Serializable
data class Signal @JvmOverloads constructor(
    @JvmField var seq: Long = 0L,
    @JvmField var ts: Long = 0L,
    @JvmField var priceMantissa: Long = 0L,
    @JvmField var qty: Int = 0,
    @JvmField var flags: Int = 0,
    @JvmField var symbol: String = "",
    @JvmField var venue: String = "",
    @JvmField var legs: MutableList<SignalLeg> = mutableListOf(),
) : JavaSerializable {
    @Serializable
    data class SignalLeg @JvmOverloads constructor(
        @JvmField var legId: Long = 0L,
        @JvmField var legQty: Int = 0,
        @JvmField var legPad: Int = 0,
    ) : JavaSerializable
}
