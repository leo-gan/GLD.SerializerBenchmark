package benchmark;

import java.lang.reflect.Array;
import java.util.List;
import java.util.Objects;

/** Semantic equality for suite fixtures (float tolerance). */
public final class Fidelity {
  private Fidelity() {}

  public static boolean check(Object expected, Object actual) {
    if (expected == actual) return true;
    if (expected == null || actual == null) return false;
    if (expected instanceof List<?> el && actual instanceof List<?> al) {
      if (el.size() != al.size()) return false;
      for (int i = 0; i < el.size(); i++) {
        if (!check(el.get(i), al.get(i))) return false;
      }
      return true;
    }
    if (expected.getClass().isArray() && actual.getClass().isArray()) {
      int n = Array.getLength(expected);
      if (n != Array.getLength(actual)) return false;
      for (int i = 0; i < n; i++) {
        if (!check(Array.get(expected, i), Array.get(actual, i))) return false;
      }
      return true;
    }
    if (expected instanceof Double || expected instanceof Float
        || actual instanceof Double || actual instanceof Float) {
      if (expected instanceof Number en && actual instanceof Number an) {
        return Math.abs(en.doubleValue() - an.doubleValue()) <= 1e-9;
      }
    }
    // Prefer equals when both sides implement meaningful equals (our POJOs do).
    if (expected.equals(actual)) return true;
    // Jackson/Gson may produce LinkedHashMap for untyped decode — not used if typed.
    return Objects.deepEquals(expected, actual);
  }
}
