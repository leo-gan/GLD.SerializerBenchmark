package benchmark;

import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

/** Writes monorepo CSV schema (Language=java, times in nanoseconds). */
public final class CsvLogger implements AutoCloseable {
  private final BufferedWriter w;

  public CsvLogger(Path path) throws IOException {
    Files.createDirectories(path.getParent());
    w = Files.newBufferedWriter(path, StandardCharsets.UTF_8);
    w.write(
        "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,"
            + "SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,"
            + "OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,"
            + "DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition,SizeGzip,SizeZstd\n");
  }

  public void writeRow(
      String mode,
      String testData,
      int repetitions,
      int repIndex,
      String serializer,
      long timeSerNs,
      long timeDeserNs,
      int size,
      double fidelity,
      String version,
      String nativeKind,
      String streamMode,
      int instanceCount,
      String typeConfigHash,
      int runOrder,
      int schedulePosition,
      int sizeGzip,
      int sizeZstd)
      throws IOException {
    long total = timeSerNs + timeDeserNs;
    double opsSer = timeSerNs > 0 ? 1e9 / timeSerNs : 0;
    double opsDeser = timeDeserNs > 0 ? 1e9 / timeDeserNs : 0;
    double opsTot = total > 0 ? 1e9 / total : 0;
    String ic = instanceCount > 0 ? Integer.toString(instanceCount) : "";
    String ro = runOrder >= 0 ? Integer.toString(runOrder) : "";
    String sp = schedulePosition >= 0 ? Integer.toString(schedulePosition) : "";
    String gz = sizeGzip > 0 ? Integer.toString(sizeGzip) : "";
    String zs = sizeZstd > 0 ? Integer.toString(sizeZstd) : "";
    // Locale.US: decimal point must stay '.' — default locales (e.g. de_DE) use ',' and
    // would inject extra CSV columns for OpPerSec* / FidelityScore.
    w.write(
        String.format(
            Locale.US,
            "java,%s,%s,%d,%d,%s,%s,%d,%d,%d,%d,%.6f,%.6f,%.6f,0,%.1f,%s,%s,%s,%s,%s,%s,%s,%s\n",
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
            typeConfigHash == null ? "" : typeConfigHash,
            ro,
            sp,
            gz,
            zs));
  }

  public void flush() throws IOException {
    w.flush();
  }

  @Override
  public void close() throws IOException {
    w.close();
  }
}
