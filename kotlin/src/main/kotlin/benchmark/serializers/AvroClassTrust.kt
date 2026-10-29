package benchmark.serializers

import org.apache.avro.util.ClassSecurityValidator

/**
 * Avro 1.12 rejects classes outside its trust list. Reflect rows use
 * `benchmark.model`. Parquet specific rows use generated `benchmark.v2.avro` records.
 */
internal object AvroClassTrust {
    fun install() {
        ClassSecurityValidator.setGlobal { clazz ->
            val name = clazz.name
            name.startsWith("benchmark.")
                || name.startsWith("java.util.")
                || name.startsWith("kotlin.")
                || ClassSecurityValidator.DEFAULT.isTrusted(clazz)
        }
    }
}
