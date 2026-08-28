package benchmark

import benchmark.model.Fixture
import benchmark.model.v2.Cells
import benchmark.serializers.BenchSerializer
import benchmark.serializers.Registry
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.file.Files
import java.nio.file.Path
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Kotlin serializer benchmark runner (Java/Python/Go/Rust-aligned prepare/timed call path).
 *
 * Default schedule is block_shuffle: prepare once per cell, then mode → rep → shuffled
 * serializers. Escape hatch: `BENCHMARK_SCHEDULE=none`.
 */
fun main(args: Array<String>) {
    var repetitions = 10
    var serFilter = ""
    var dataFilter = ""
    var logDirArg = ""

    var i = 0
    while (i < args.size) {
        val a = args[i]
        when {
            a == "--reps" && i + 1 < args.size -> {
                repetitions = args[++i].toInt()
            }
            a == "--serializer" && i + 1 < args.size -> {
                serFilter = args[++i]
            }
            a == "--data" && i + 1 < args.size -> {
                dataFilter = args[++i]
            }
            a == "--log-dir" && i + 1 < args.size -> {
                logDirArg = args[++i]
            }
            !a.startsWith("-") -> {
                if (repetitions == 10 && a.matches(Regex("\\d+"))) {
                    repetitions = a.toInt()
                } else if (serFilter.isEmpty()) {
                    serFilter = a
                } else if (dataFilter.isEmpty()) {
                    dataFilter = a
                }
            }
        }
        i++
    }

    val logDir = resolveLogDir(logDirArg)
    Files.createDirectories(logDir)

    var ts = System.getenv("BENCHMARK_TS")
    if (ts.isNullOrBlank()) {
        ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss"))
    }
    val logPath = logDir.resolve("$ts.csv")
    val errPath = logDir.resolve("$ts.errors.csv")

    System.err.println("[PROGRESS] Writing results under $logDir")

    val sers = Registry.select(serFilter)
    var seed = 42L
    val seedEnv = System.getenv("BENCHMARK_SEED")
    if (!seedEnv.isNullOrBlank()) {
        seed = seedEnv.toLong()
    }

    val runCfg = System.getenv("BENCHMARK_RUN_CONFIG")
    val resolved = Cells.loadResolved(runCfg, seed)
    var modes = resolved.ioModes
    if (modes.isEmpty()) {
        modes = listOf("bytes", "stream")
    }
    seed = if (resolved.seed != 0L) resolved.seed else seed

    val work = mutableListOf<Cells.WorkItem>()
    for (c in resolved.cells) {
        if (dataFilter.isNotEmpty() &&
            !c.typeId.lowercase(Locale.ROOT).contains(dataFilter.lowercase(Locale.ROOT))
        ) {
            continue
        }
        work.add(Cells.fixtureFromCell(c, seed))
    }

    val strategy = Schedule.resolveStrategy()
    val recordRO = Schedule.resolveRecordRunOrder()

    println(
        "[PROGRESS] Kotlin Data Model v2: ${sers.size} serializers, ${work.size} cells, " +
            "$repetitions reps, modes=$modes schedule=$strategy",
    )

    val errors = mutableListOf<BenchError>()
    var runOrder = 0
    CsvLogger(logPath).use { logger ->
        for (w in work) {
            val fx = w.fixture
            println("[PROGRESS] Testing Data: ${fx.name} (N=${w.instanceCount})")

            val ready = mutableListOf<Prepared>()
            val byName = HashMap<String, Prepared>()
            val failed = HashSet<String>()
            for (ser in sers) {
                if (!ser.supports(fx.name)) continue
                try {
                    ser.prepare(fx)
                } catch (e: Exception) {
                    System.err.printf("[ERROR] prepare %s / %s: %s%n", ser.name(), fx.name, e)
                    errors.add(BenchError(fx.name, ser.name(), "prepare", 0, e.toString()))
                    failed.add(ser.name())
                    continue
                }
                var gz = 0
                var zs = 0
                try {
                    val csz = Compress.sizes(ser.serializeBytes(fx))
                    gz = csz[0]
                    zs = csz[1]
                } catch (_: Exception) {
                    // leave compressed sizes empty
                }
                val p = Prepared(ser, gz, zs)
                ready.add(p)
                byName[ser.name()] = p
            }

            for (mode in modes) {
                for (rep in 0 until repetitions) {
                    val order: List<Prepared> =
                        if (strategy == "none") {
                            ready
                        } else {
                            val names = ready.filter { it.ser.name() !in failed }.map { it.ser.name() }
                            val schedSeed =
                                Schedule.deriveScheduleSeed(
                                    seed,
                                    fx.name,
                                    w.instanceCount,
                                    w.typeConfigHash,
                                    mode,
                                    rep,
                                )
                            val shuffled = Schedule.fisherYates(names, schedSeed)
                            shuffled.mapNotNull { byName[it] }
                        }

                    for ((pos, p) in order.withIndex()) {
                        if (p.ser.name() in failed) continue
                        val ser = p.ser
                        try {
                            val m =
                                if (mode == "bytes") {
                                    measureBytes(ser, fx)
                                } else {
                                    measureStream(ser, fx, p.streamScratch)
                                }
                            var ro = -1
                            var sp = -1
                            if (recordRO) {
                                ro = runOrder
                                sp = pos
                                runOrder++
                            }
                            logger.writeRow(
                                mode,
                                fx.name,
                                repetitions,
                                rep,
                                ser.name(),
                                m.serNs,
                                m.deserNs,
                                m.size,
                                1.0,
                                ser.version(),
                                ser.nativeKind(),
                                ser.streamMode(),
                                w.instanceCount,
                                w.typeConfigHash,
                                ro,
                                sp,
                                p.sizeGzip,
                                p.sizeZstd,
                            )
                        } catch (e: Exception) {
                            System.err.printf(
                                "[ERROR] %s / %s / %s: %s%n",
                                ser.name(),
                                fx.name,
                                mode,
                                e.toString(),
                            )
                            errors.add(BenchError(fx.name, ser.name(), mode, rep, e.toString()))
                            failed.add(ser.name())
                        }
                    }
                }
            }
        }
        logger.flush()
    }

    saveErrors(errPath, errors)
    println("[PROGRESS] Complete. Results: $logPath")
}

private data class BenchError(
    val testDataName: String,
    val serializerName: String,
    val stringOrStream: String,
    val repetition: Int,
    val errorText: String,
)

private data class Measure(val serNs: Long, val deserNs: Long, val size: Int)

private class Prepared(val ser: BenchSerializer, val sizeGzip: Int, val sizeZstd: Int) {
    val streamScratch = ByteArrayOutputStream(64 * 1024)
}

/** Volatile sink so the JIT cannot dead-code timed work (issue #59). */
@Volatile private var preventDce: Any? = null

private fun keep(o: Any?) {
    preventDce = o
}

private fun measureBytes(ser: BenchSerializer, fx: Fixture): Measure {
    var t0 = System.nanoTime()
    val buf = ser.serializeBytes(fx)
    val serNs = System.nanoTime() - t0
    keep(buf)
    t0 = System.nanoTime()
    var out = ser.deserializeBytes(buf)
    val deserNs = System.nanoTime() - t0
    keep(out)
    out = ser.toDomain(out)
    if (!Fidelity.check(fx.value, out)) {
        throw IllegalStateException("roundtrip fidelity failed for ${ser.name()}")
    }
    return Measure(serNs, deserNs, buf.size)
}

private fun measureStream(ser: BenchSerializer, fx: Fixture, baos: ByteArrayOutputStream): Measure {
    baos.reset()
    var t0 = System.nanoTime()
    var n = ser.serializeStream(fx, baos)
    val serNs = System.nanoTime() - t0
    keep(baos)
    if (n < 0) n = baos.size()
    val bais = ByteArrayInputStream(baos.toByteArray())
    t0 = System.nanoTime()
    var out = ser.deserializeStream(bais)
    val deserNs = System.nanoTime() - t0
    keep(out)
    out = ser.toDomain(out)
    if (!Fidelity.check(fx.value, out)) {
        throw IllegalStateException("stream roundtrip fidelity failed for ${ser.name()}")
    }
    return Measure(serNs, deserNs, if (n > 0) n else baos.size())
}

private fun resolveLogDir(logDirArg: String): Path {
    if (logDirArg.isNotBlank()) {
        val p = Path.of(logDirArg)
        if (p.fileName != null && p.fileName.toString() == "kotlin") return p
        return p.resolve("kotlin")
    }
    val env = System.getenv("LOG_DIR")
    if (!env.isNullOrBlank()) {
        val p = Path.of(env)
        if (p.fileName != null && p.fileName.toString() == "kotlin") return p
        return p.resolve("kotlin")
    }
    return Cells.repoRoot().resolve("logs/kotlin")
}

private fun saveErrors(path: Path, errors: List<BenchError>) {
    if (errors.isEmpty()) {
        Files.deleteIfExists(path)
        return
    }
    val sb = StringBuilder()
    sb.append("TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n")
    for (e in errors) {
        val text = e.errorText.replace('\n', ' ').replace(',', ';')
        sb.append(e.testDataName).append(',')
            .append(e.serializerName).append(',')
            .append(e.stringOrStream).append(',')
            .append(e.repetition).append(',')
            .append(text).append('\n')
    }
    Files.writeString(path, sb.toString())
}
