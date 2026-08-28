package benchmark.model.v2

import com.squareup.moshi.JsonClass
import kotlinx.serialization.Serializable
import kotlinx.serialization.protobuf.ProtoNumber
import java.io.Serializable as JavaSerializable

@Serializable
@JsonClass(generateAdapter = true)
data class EventAttr(
    @ProtoNumber(1) @JvmField var key: String = "",
    @ProtoNumber(2) @JvmField var value: String = "",
) : JavaSerializable

@Serializable
@JsonClass(generateAdapter = true)
data class Event(
    @ProtoNumber(1) @JvmField var eventId: String = "",
    @ProtoNumber(2) @JvmField var eventType: String = "",
    @ProtoNumber(3) @JvmField var occurredAt: Long = 0L,
    @ProtoNumber(4) @JvmField var producer: String = "",
    @ProtoNumber(5) @JvmField var attrs: MutableList<EventAttr> = mutableListOf(),
) : JavaSerializable
