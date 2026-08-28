package benchmark.model.v2

import benchmark.model.Fixture
import com.fasterxml.jackson.databind.JsonNode
import com.fasterxml.jackson.databind.ObjectMapper
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path

/** Resolve run-config cells via scripts/resolve_run_config.py (same as Java/Go/Python). */
object Cells {
    private val mapper = ObjectMapper()

    data class Cell(
        val typeId: String,
        val typeConfig: Map<String, Any?>,
        val typeConfigHash: String,
        val dataTypeInstanceCount: Int,
    )

    data class ResolvedRun(val cells: List<Cell>, val ioModes: List<String>, val seed: Long)

    data class WorkItem(val fixture: Fixture, val instanceCount: Int, val typeConfigHash: String)

    fun repoRoot(): Path {
        var dir = Path.of(System.getProperty("user.dir")).toAbsolutePath()
        var p: Path? = dir
        while (p != null) {
            if (Files.isRegularFile(p.resolve("config/benchmark_config.yaml"))) {
                return p
            }
            p = p.parent
        }
        return dir
    }

    fun loadResolved(runConfigPath: String?, seed: Long): ResolvedRun {
        val root = repoRoot()
        val script = root.resolve("scripts/resolve_run_config.py")
        var cfgPath = runConfigPath
        if (cfgPath.isNullOrBlank()) {
            cfgPath = root.resolve("config/library/default.yaml").toString()
        } else {
            val candidate = root.resolve(cfgPath)
            if (Files.isRegularFile(candidate)) {
                cfgPath = candidate.toString()
            }
        }
        val pb = ProcessBuilder(
            "python3",
            script.toString(),
            cfgPath,
            "--seed",
            seed.toString(),
        )
        pb.directory(root.toFile())
        val env = pb.environment()
        val analysisSrc = root.resolve("analysis/src").toString()
        val prev = env.getOrDefault("PYTHONPATH", "")
        env["PYTHONPATH"] = if (prev.isEmpty()) analysisSrc else "$analysisSrc:$prev"
        pb.redirectErrorStream(true)
        val proc = pb.start()
        val out = String(proc.inputStream.readAllBytes(), StandardCharsets.UTF_8)
        val code = proc.waitFor()
        if (code != 0) {
            throw IllegalStateException("resolve_run_config failed ($code): $out")
        }
        val rootNode = mapper.readTree(out)
        val cells = mutableListOf<Cell>()
        for (c in rootNode.path("cells")) {
            val cfg = mutableMapOf<String, Any?>()
            val tc = c.path("type_config")
            if (tc.isObject) {
                val it = tc.fields()
                while (it.hasNext()) {
                    val e = it.next()
                    cfg[e.key] = mapper.convertValue(e.value, Any::class.java)
                }
            }
            cells.add(
                Cell(
                    c.path("type_id").asText(),
                    cfg,
                    c.path("type_config_hash").asText(""),
                    c.path("data_type_instance_count").asInt(1),
                ),
            )
        }
        val modes = mutableListOf<String>()
        for (m in rootNode.path("execution").path("io_modes")) {
            modes.add(m.asText())
        }
        var resolvedSeed = seed
        if (rootNode.hasNonNull("seed")) {
            resolvedSeed = rootNode.get("seed").asLong(seed)
        }
        return ResolvedRun(cells, modes, resolvedSeed)
    }

    fun fixtureFromCell(cell: Cell, seed: Long): WorkItem {
        val n = maxOf(1, cell.dataTypeInstanceCount)
        val insts = Generators.instances(cell.typeId, cell.typeConfig, seed, n)
        val value: Any =
            if (n == 1) {
                insts[0]
            } else {
                when (cell.typeId) {
                    "message" -> insts.map { it as Message }.toMutableList()
                    "document" -> insts.map { it as Document }.toMutableList()
                    "telemetry" -> insts.map { it as Telemetry }.toMutableList()
                    "strings" -> insts.map { it as Strings }.toMutableList()
                    "event" -> insts.map { it as Event }.toMutableList()
                    else -> insts
                }
            }
        return WorkItem(Fixture(cell.typeId, value), n, cell.typeConfigHash)
    }
}
