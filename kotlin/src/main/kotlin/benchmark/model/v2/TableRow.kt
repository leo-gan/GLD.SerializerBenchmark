package benchmark.model.v2

import kotlinx.serialization.Serializable
import java.io.Serializable as JavaSerializable

/** Wide flat row (type_id=table and table_project). Field order matches the catalog. */
@Serializable
data class TableRow @JvmOverloads constructor(
    @JvmField var fFloat0: Double = 0.0,
    @JvmField var fFloat1: Double = 0.0,
    @JvmField var fFloat2: Double = 0.0,
    @JvmField var fFloat3: Double = 0.0,
    @JvmField var fFloat4: Double = 0.0,
    @JvmField var fFloat5: Double = 0.0,
    @JvmField var fFloat6: Double = 0.0,
    @JvmField var fFloat7: Double = 0.0,
    @JvmField var fFloat8: Double = 0.0,
    @JvmField var fFloat9: Double = 0.0,
    @JvmField var fFloat10: Double = 0.0,
    @JvmField var fFloat11: Double = 0.0,
    @JvmField var fFloat12: Double = 0.0,
    @JvmField var fFloat13: Double = 0.0,
    @JvmField var fFloat14: Double = 0.0,
    @JvmField var fFloat15: Double = 0.0,
    @JvmField var fInt0: Long = 0L,
    @JvmField var fInt1: Long = 0L,
    @JvmField var fInt2: Long = 0L,
    @JvmField var fInt3: Long = 0L,
    @JvmField var fStr0: String = "",
    @JvmField var fStr1: String = "",
) : JavaSerializable {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TableRow) return false
        return close(fFloat0, other.fFloat0) &&
            close(fFloat1, other.fFloat1) &&
            close(fFloat2, other.fFloat2) &&
            close(fFloat3, other.fFloat3) &&
            close(fFloat4, other.fFloat4) &&
            close(fFloat5, other.fFloat5) &&
            close(fFloat6, other.fFloat6) &&
            close(fFloat7, other.fFloat7) &&
            close(fFloat8, other.fFloat8) &&
            close(fFloat9, other.fFloat9) &&
            close(fFloat10, other.fFloat10) &&
            close(fFloat11, other.fFloat11) &&
            close(fFloat12, other.fFloat12) &&
            close(fFloat13, other.fFloat13) &&
            close(fFloat14, other.fFloat14) &&
            close(fFloat15, other.fFloat15) &&
            fInt0 == other.fInt0 &&
            fInt1 == other.fInt1 &&
            fInt2 == other.fInt2 &&
            fInt3 == other.fInt3 &&
            fStr0 == other.fStr0 &&
            fStr1 == other.fStr1
    }

    override fun hashCode(): Int {
        var result = fFloat0.hashCode()
        result = 31 * result + fFloat1.hashCode()
        result = 31 * result + fFloat2.hashCode()
        result = 31 * result + fFloat3.hashCode()
        result = 31 * result + fFloat4.hashCode()
        result = 31 * result + fFloat5.hashCode()
        result = 31 * result + fFloat6.hashCode()
        result = 31 * result + fFloat7.hashCode()
        result = 31 * result + fFloat8.hashCode()
        result = 31 * result + fFloat9.hashCode()
        result = 31 * result + fFloat10.hashCode()
        result = 31 * result + fFloat11.hashCode()
        result = 31 * result + fFloat12.hashCode()
        result = 31 * result + fFloat13.hashCode()
        result = 31 * result + fFloat14.hashCode()
        result = 31 * result + fFloat15.hashCode()
        result = 31 * result + fInt0.hashCode()
        result = 31 * result + fInt1.hashCode()
        result = 31 * result + fInt2.hashCode()
        result = 31 * result + fInt3.hashCode()
        result = 31 * result + fStr0.hashCode()
        result = 31 * result + fStr1.hashCode()
        return result
    }

    private fun close(a: Double, b: Double) = kotlin.math.abs(a - b) <= 1e-9
}
