package benchmark.serializers

import benchmark.model.Fixture
import java.io.InputStream
import java.io.OutputStream

/**
 * Prepare/timed call-path contract (aligned with Java/Go/Python/Rust).
 *
 * ```
 * prepare(fixture)                 # untimed
 * serializeBytes / stream          # timed
 * deserializeBytes / stream        # timed (codec only)
 * toDomain (optional)              # untimed
 * fidelity                         # untimed
 * ```
 *
 * For table, table_project, nested_table, and signal only, row-to-column conversion and
 * the SBE flyweight fill stay inside serialize. Schema objects and writer properties stay
 * in prepare.
 */
interface BenchSerializer {
    fun name(): String

    fun version(): String

    /** native | adapted */
    fun streamMode(): String = "adapted"

    /** reflect | message | schema */
    fun nativeKind(): String = "reflect"

    /** Original five publication types. Columnar rows and the four peers override this. */
    fun supports(testDataName: String): Boolean = testDataName in TypeUtil.ORIGINAL_IDS

    fun prepare(fx: Fixture)

    fun serializeBytes(fx: Fixture): ByteArray

    fun deserializeBytes(data: ByteArray): Any

    fun serializeStream(fx: Fixture, out: OutputStream): Int {
        val b = serializeBytes(fx)
        out.write(b)
        return b.size
    }

    fun deserializeStream(input: InputStream): Any = deserializeBytes(input.readAllBytes())

    /**
     * Optional untimed conversion from library-native value to suite domain object.
     * Default is identity.
     */
    fun toDomain(decoded: Any): Any = decoded
}
