package benchmark

import java.lang.reflect.Array as JArray

/** Semantic equality for suite fixtures (float tolerance). */
object Fidelity {
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
