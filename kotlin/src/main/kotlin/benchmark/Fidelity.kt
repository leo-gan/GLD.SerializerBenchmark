package benchmark

import benchmark.model.v2.V2Rows
import java.lang.reflect.Array as JArray

/** Semantic equality for suite fixtures (float tolerance). */
object Fidelity {
    /**
     * Value compared after deserialize. table_project serializes the full row and
     * returns f_float_0 only, including when N is 1.
     */
    fun expectedForFidelity(typeId: String, value: Any?): Any? {
        if (typeId == "table_project") return V2Rows.float0(value)
        return value
    }

    fun check(expected: Any?, actual: Any?): Boolean {
        if (expected === actual) return true
        if (expected == null || actual == null) return false
        if (expected is List<*> && actual is List<*>) {
            if (expected.size != actual.size) return false
            for (i in expected.indices) {
                if (!check(expected[i], actual[i])) return false
            }
            return true
        }
        if (expected.javaClass.isArray && actual.javaClass.isArray) {
            val n = JArray.getLength(expected)
            if (n != JArray.getLength(actual)) return false
            for (i in 0 until n) {
                if (!check(JArray.get(expected, i), JArray.get(actual, i))) return false
            }
            return true
        }
        if (expected is Double || expected is Float || actual is Double || actual is Float) {
            if (expected is Number && actual is Number) {
                return kotlin.math.abs(expected.toDouble() - actual.toDouble()) <= 1e-9
            }
        }
        if (expected == actual) return true
        return expected == actual
    }
}
