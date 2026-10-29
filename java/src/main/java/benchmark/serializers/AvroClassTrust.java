package benchmark.serializers;

import org.apache.avro.util.ClassSecurityValidator;

/**
 * Avro 1.12 rejects classes outside its trust list. Reflect rows use
 * {@code benchmark.model}. Parquet specific rows use generated
 * {@code benchmark.v2.avro} records.
 */
final class AvroClassTrust {
  private AvroClassTrust() {}

  static void install() {
    ClassSecurityValidator.setGlobal(
        clazz -> {
          String name = clazz.getName();
          if (name.startsWith("benchmark.")
              || name.startsWith("java.util.")
              || name.startsWith("kotlin.")) {
            return true;
          }
          return ClassSecurityValidator.DEFAULT.isTrusted(clazz);
        });
  }
}
