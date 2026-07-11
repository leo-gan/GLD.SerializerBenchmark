package benchmark.serializers;

import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.Strings;
import benchmark.model.v2.Telemetry;
import com.fasterxml.jackson.core.type.TypeReference;

import java.lang.reflect.Array;
import java.util.ArrayList;
import java.util.List;

/** Helpers for typed empty targets and list TypeReferences. */
public final class TypeUtil {
  private TypeUtil() {}

  public static Class<?> elementClass(Object value) {
    if (value instanceof List<?> list && !list.isEmpty()) {
      return list.get(0).getClass();
    }
    return value.getClass();
  }

  public static boolean isList(Object value) {
    return value instanceof List<?>;
  }

  @SuppressWarnings("unchecked")
  public static <T> T newEmpty(Object prototype) {
    if (prototype instanceof List<?> list) {
      // Return empty ArrayList; serializers that need typed list use TypeReference.
      return (T) new ArrayList<>();
    }
    try {
      return (T) prototype.getClass().getDeclaredConstructor().newInstance();
    } catch (ReflectiveOperationException e) {
      throw new IllegalStateException("cannot instantiate " + prototype.getClass(), e);
    }
  }

  public static TypeReference<?> listTypeRef(Object prototype) {
    if (!(prototype instanceof List<?> list) || list.isEmpty()) {
      throw new IllegalArgumentException("expected non-empty List prototype");
    }
    Object first = list.get(0);
    if (first instanceof Message) return new TypeReference<List<Message>>() {};
    if (first instanceof Document) return new TypeReference<List<Document>>() {};
    if (first instanceof Telemetry) return new TypeReference<List<Telemetry>>() {};
    if (first instanceof Strings) return new TypeReference<List<Strings>>() {};
    if (first instanceof Event) return new TypeReference<List<Event>>() {};
    return new TypeReference<List<Object>>() {};
  }

  public static Class<?> javaType(Object prototype) {
    if (prototype instanceof List<?>) {
      return List.class;
    }
    return prototype.getClass();
  }

  /** Create an empty array of the prototype element type (for codecs that use arrays). */
  public static Object emptyArrayLike(Object prototype) {
    Class<?> el = elementClass(prototype);
    return Array.newInstance(el, 0);
  }
}
