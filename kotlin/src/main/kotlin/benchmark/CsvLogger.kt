package benchmark

import java.io.BufferedWriter
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import java.util.Locale

/** Writes monorepo CSV schema (Language=kotlin, times in nanoseconds). */
class CsvLogger(path: Path) : AutoCloseable {
    private val w: BufferedWriter

    init {
        Files.createDirectories(path.parent)
        w = Files.newBufferedWriter(path, StandardCharsets.UTF_8)
        w.write(
            "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName," +
                "SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser," +
                "OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode," +
                "DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition,SizeGzip,SizeZstd\n",
        )
    }

    fun writeRow(
        mode: String,
        testData: String,
        repetitions: Int,
        repIndex: Int,
        serializer: String,
        timeSerNs: Long,
        timeDeserNs: Long,
        size: Int,
        fidelity: Double,
        version: String,
        nativeKind: String,
        streamMode: String,
        instanceCount: Int,
        typeConfigHash: String?,
        runOrder: Int,
        schedulePosition: Int,
        sizeGzip: Int,
        sizeZstd: Int,
    ) {
        val total = timeSerNs + timeDeserNs
        val opsSer = if (timeSerNs > 0) 1e9 / timeSerNs else 0.0
        val opsDeser = if (timeDeserNs > 0) 1e9 / timeDeserNs else 0.0
        val opsTot = if (total > 0) 1e9 / total else 0.0
        val ic = if (instanceCount > 0) instanceCount.toString() else ""
        val ro = if (runOrder >= 0) runOrder.toString() else ""
        val sp = if (schedulePosition >= 0) schedulePosition.toString() else ""
        val gz = if (sizeGzip > 0) sizeGzip.toString() else ""
        val zs = if (sizeZstd > 0) sizeZstd.toString() else ""
        w.write(
            String.format(
                Locale.US,
                "kotlin,%s,%s,%d,%d,%s,%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,0,%.1f,%s,%s,%s,%s,%s,%s,%s,%s\n",
                mode,
                testData,
                repetitions,
                repIndex,
                serializer,
                version,
                timeSerNs,
                timeDeserNs,
                size,
                total,
                opsSer,
                opsDeser,
                opsTot,
                fidelity,
                nativeKind,
                streamMode,
                ic,
                typeConfigHash ?: "",
                ro,
                sp,
                gz,
                zs,
            ),
        )
    }

    fun flush() {
        w.flush()
    }

    override fun close() {
        w.close()
    }
}
