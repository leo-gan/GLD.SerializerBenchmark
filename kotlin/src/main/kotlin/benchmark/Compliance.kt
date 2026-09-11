package benchmark

import com.charleskorn.kaml.Yaml
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.cbor.CBORFactory
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import kotlinx.serialization.json.Json
import java.nio.file.Files
import java.nio.file.Path
import java.time.Instant
import kotlin.io.path.isDirectory
import kotlin.io.path.readText
import kotlin.io.path.writeText
import net.peanuuutz.tomlkt.Toml

/** Kotlin compliance runner — same catalog as Python. */
fun complianceMain(args: Array<String>) {
    var jsonOut: String? = null
    val formats = mutableListOf<String>()
    var i = 0
    while (i < args.size) {
        when (args[i]) {
            "--json-out", "-o" -> if (i + 1 < args.size) jsonOut = args[++i]
            "--format", "-f" -> if (i + 1 < args.size) formats.add(args[++i].lowercase())
        }
        i++
    }
    val root = repoRoot()
    var suites = loadSuites(root.resolve("compliance/data"))
    if (formats.isNotEmpty()) {
        val want = formats.toSet()
        suites = suites.filter { it["format"].toString().lowercase() in want }
    }
    val adapters = adapters()
    val byFmt = adapters.groupBy { it.format }
    val results = mutableListOf<MutableMap<String, Any?>>()
    val adapterErrs = mutableListOf<String>()
    for (suite in suites) {
        val fmt = suite["format"].toString()
        val chosen = byFmt[fmt].orEmpty()
        if (chosen.isEmpty()) {
            adapterErrs.add("No adapter registered for format $fmt (${suite["standard"]} (${suite["version"]}))")
            continue
        }
        @Suppress("UNCHECKED_CAST")
        val cases = suite["cases"] as List<Map<String, Any?>>
        for (a in chosen) {
            for (c in cases) results.add(runOne(suite, c, a))
        }
    }
    printSummary(results, adapterErrs)
    if (jsonOut != null) {
        writeReport(Path.of(jsonOut), results, adapterErrs)
        println("\nWrote $jsonOut")
    }
}

private data class Adapter(val name: String, val format: String, val decode: (ByteArray) -> Any?)

private fun adapters(): List<Adapter> {
    val jackson = jacksonObjectMapper()
    val cbor = ObjectMapper(CBORFactory())
    return listOf(
        Adapter("kotlinx-json", "json") { b ->
            if (b.count { it == '['.code.toByte() || it == '{'.code.toByte() } > 4_000) {
                error("input too nested for this runner")
            }
            Json.parseToJsonElement(b.decodeToString())
        },
        Adapter("jackson", "json") { jackson.readValue(it, Any::class.java) },
        Adapter("kaml", "yaml") { Yaml.default.parseToYamlNode(it.decodeToString()) },
        Adapter("jackson-cbor", "cbor") { cbor.readValue(it, Any::class.java) },
        Adapter("tomlkt", "toml") { Toml.parseToTomlTable(it.decodeToString()) },
    )
}

private fun repoRoot(): Path {
    var dir = Path.of("").toAbsolutePath()
    repeat(8) {
        if (Files.isDirectory(dir.resolve("compliance/data"))) return dir
        dir = dir.parent ?: return@repeat
    }
    error("cannot locate compliance/data")
}

private fun loadSuites(root: Path): List<Map<String, Any?>> {
    val mapper = jacksonObjectMapper()
    val suites = mutableListOf<Map<String, Any?>>()
    Files.list(root).use { dirs ->
        dirs.filter { it.isDirectory() }.forEach { fmt ->
            Files.list(fmt).use { files ->
                files.filter { it.fileName.toString().endsWith(".json") && !it.fileName.toString().startsWith("_") }
                    .forEach { f ->
                        @Suppress("UNCHECKED_CAST")
                        val raw = mapper.readValue(f.toFile(), Map::class.java) as Map<String, Any?>
                        val cases = raw["cases"] as? List<*>
                        if (!cases.isNullOrEmpty() && raw["format"] != null) suites.add(raw)
                    }
            }
        }
    }
    check(suites.isNotEmpty()) { "no compliance suites under $root" }
    return suites
}

private fun inputBytes(c: Map<String, Any?>): ByteArray {
    val enc = c["input_encoding"]?.toString() ?: "utf-8"
    val input = c["input"]?.toString() ?: ""
    if (enc == "hex") {
        val compact = input.replace(Regex("\\s+"), "")
        return if (compact.isEmpty()) ByteArray(0) else compact.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    }
    return input.toByteArray()
}

private fun runOne(suite: Map<String, Any?>, c: Map<String, Any?>, a: Adapter): MutableMap<String, Any?> {
    val base = mutableMapOf<String, Any?>(
        "id" to c["id"],
        "language" to "kotlin",
        "serializer" to a.name,
        "serializer_version" to "",
        "format" to suite["format"],
        "standard" to suite["standard"],
        "standard_url" to suite["standard_url"],
        "version" to suite["version"],
        "version_key" to "${suite["format"]}.${suite["version"]}",
        "requirement" to c["requirement"],
        "expect" to c["expect"],
        "section" to c["section"],
        "section_title" to c["section_title"],
        "section_url" to c["section_url"],
        "paragraph" to c["paragraph"],
        "title" to c["title"],
        "input" to c["input"],
        "input_encoding" to (c["input_encoding"] ?: "utf-8"),
        "detail" to "",
        "observed" to "",
        "outcome" to "pass",
    )
    var got: Any? = null
    var ok = true
    var err = ""
    try {
        got = a.decode(inputBytes(c))
    } catch (ex: Exception) {
        ok = false
        err = "${ex.javaClass.simpleName}: ${ex.message}"
    }
    when (c["expect"]) {
        "any" -> base["observed"] = if (ok) preview(got) else err
        "reject" -> if (ok) {
            base["outcome"] = "fail"
            base["detail"] = "parser accepted input the spec requires to be rejected"
            base["observed"] = "accepted as ${preview(got)}"
        } else {
            base["observed"] = err
        }
        else -> if (!ok) {
            base["outcome"] = "fail"
            base["detail"] = "parser rejected input the spec requires to accept"
            base["observed"] = err
        } else {
            base["observed"] = preview(got)
        }
    }
    return base
}

private fun preview(v: Any?): String {
    val s = try {
        jacksonObjectMapper().writeValueAsString(v)
    } catch (_: Exception) {
        v.toString()
    }
    return if (s.length > 120) s.substring(0, 117) + "..." else s
}

private fun printSummary(results: List<Map<String, Any?>>, adapterErrs: List<String>) {
    var p = 0; var f = 0; var s = 0; var e = 0
    val by = sortedMapOf<String, IntArray>()
    for (r in results) {
        when (r["outcome"]) {
            "pass" -> p++
            "fail" -> f++
            "skip" -> s++
            else -> e++
        }
        val k = "${r["standard"]} (${r["version"]}) × ${r["serializer"]}"
        val c = by.getOrPut(k) { IntArray(3) }
        when (r["outcome"]) {
            "pass" -> c[0]++
            "fail" -> c[1]++
            else -> c[2]++
        }
    }
    println("Serialization compliance (library deviations are catalogued, not a red build)")
    println("  $p pass  $f fail  $s skip  $e error  ${results.size} total")
    if (adapterErrs.isNotEmpty()) {
        println("  Adapter errors:")
        adapterErrs.forEach { println("    - $it") }
    }
    println("  By suite × adapter:")
    by.forEach { (k, c) -> println("    $k: ${c[0]} pass, ${c[1]} fail, ${c[2]} skip") }
}

private fun writeReport(path: Path, results: List<Map<String, Any?>>, adapterErrs: List<String>) {
    val p = results.count { it["outcome"] == "pass" }
    val f = results.count { it["outcome"] == "fail" }
    val s = results.count { it["outcome"] == "skip" }
    val e = results.size - p - f - s
    val fmts = results.map { it["format"].toString() }.distinct()
    val doc = mapOf(
        "schema" to "gld.dashboard.compliance/1",
        "generated_at" to Instant.now().toString(),
        "language" to "kotlin",
        "languages" to listOf("kotlin"),
        "policy" to "report-only",
        "scope" to mapOf("formats" to fmts),
        "passed" to p,
        "failed" to f,
        "skipped" to s,
        "errors" to e,
        "catalog_errors" to emptyList<String>(),
        "serializer_errors" to adapterErrs,
        "results" to results,
    )
    Files.createDirectories(path.parent)
    path.writeText(jacksonObjectMapper().writerWithDefaultPrettyPrinter().writeValueAsString(doc) + "\n")
}
