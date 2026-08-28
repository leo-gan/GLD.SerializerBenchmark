package benchmark.serializers

import java.util.Properties

/**
 * Best-effort library version. Prefer filtered versions.properties; fall back to package
 * Implementation-Version (often missing in shaded jars).
 */
object Versions {
    private val props: Properties = load()

    private fun load(): Properties {
        val p = Properties()
        try {
            Versions::class.java.classLoader.getResourceAsStream("benchmark-versions.properties")?.use {
                p.load(it)
            }
        } catch (_: Exception) {
            // optional resource
        }
        return p
    }

    fun of(cls: Class<*>): String {
        val key = cls.name
        var v = props.getProperty(key)
        if (!v.isNullOrBlank()) return v
        v = props.getProperty(cls.simpleName)
        if (!v.isNullOrBlank()) return v
        val iv = cls.`package`?.implementationVersion
        if (!iv.isNullOrBlank()) return iv
        return props.getProperty("default", "unknown")
    }

    fun of(key: String, fallbackClass: Class<*>? = null): String {
        val v = props.getProperty(key)
        if (!v.isNullOrBlank()) return v
        return if (fallbackClass != null) of(fallbackClass) else props.getProperty("default", "unknown")
    }
}
