package benchmark;

import benchmark.model.Fixture;
import benchmark.model.v2.Cells;
import benchmark.serializers.BenchSerializer;
import benchmark.serializers.Registry;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Java serializer benchmark runner (Python/Go/Rust-aligned prepare/timed call path).
 */
public final class Main {
  private record BenchError(
      String testDataName, String serializerName, String stringOrStream, int repetition, String errorText) {}

  private record Measure(long serNs, long deserNs, int size) {}

  public static void main(String[] args) throws Exception {
    int repetitions = 10;
    String serFilter = "";
    String dataFilter = "";
    String logDirArg = "";

    for (int i = 0; i < args.length; i++) {
      String a = args[i];
      if (a.equals("--reps") && i + 1 < args.length) {
        repetitions = Integer.parseInt(args[++i]);
      } else if (a.equals("--serializer") && i + 1 < args.length) {
        serFilter = args[++i];
      } else if (a.equals("--data") && i + 1 < args.length) {
        dataFilter = args[++i];
      } else if (a.equals("--log-dir") && i + 1 < args.length) {
        logDirArg = args[++i];
      } else if (!a.startsWith("-")) {
        // positional: reps [serFilter [dataFilter]]
        if (repetitions == 10 && a.matches("\\d+")) {
          repetitions = Integer.parseInt(a);
        } else if (serFilter.isEmpty()) {
          serFilter = a;
        } else if (dataFilter.isEmpty()) {
          dataFilter = a;
        }
      }
    }

    Path logDir = resolveLogDir(logDirArg);
    Files.createDirectories(logDir);

    String ts = System.getenv("BENCHMARK_TS");
    if (ts == null || ts.isBlank()) {
      ts = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd-HHmmss"));
      // export for sidecars
    }
    Path logPath = logDir.resolve(ts + ".csv");
    Path errPath = logDir.resolve(ts + ".errors.csv");

    System.err.println("[PROGRESS] Writing results under " + logDir);

    List<BenchSerializer> sers = Registry.select(serFilter);
    long seed = 42;
    String seedEnv = System.getenv("BENCHMARK_SEED");
    if (seedEnv != null && !seedEnv.isBlank()) {
      seed = Long.parseLong(seedEnv);
    }

    String runCfg = System.getenv("BENCHMARK_RUN_CONFIG");
    Cells.ResolvedRun resolved = Cells.loadResolved(runCfg, seed);
    List<String> modes = resolved.ioModes();
    if (modes == null || modes.isEmpty()) {
      modes = List.of("bytes", "stream");
    }
    seed = resolved.seed() != 0 ? resolved.seed() : seed;

    List<Cells.WorkItem> work = new ArrayList<>();
    for (Cells.Cell c : resolved.cells()) {
      if (!dataFilter.isEmpty()
          && !c.typeId().toLowerCase(Locale.ROOT).contains(dataFilter.toLowerCase(Locale.ROOT))) {
        continue;
      }
      work.add(Cells.fixtureFromCell(c, seed));
    }

    System.out.printf(
        "[PROGRESS] Java Data Model v2: %d serializers, %d cells, %d reps, modes=%s%n",
        sers.size(), work.size(), repetitions, modes);

    List<BenchError> errors = new ArrayList<>();
    try (CsvLogger logger = new CsvLogger(logPath)) {
      for (Cells.WorkItem w : work) {
        Fixture fx = w.fixture();
        System.out.printf("[PROGRESS] Testing Data: %s (N=%d)%n", fx.name, w.instanceCount());
        for (BenchSerializer ser : sers) {
          if (!ser.supports(fx.name)) continue;
          try {
            ser.prepare(fx);
          } catch (Exception e) {
            System.err.printf("[ERROR] prepare %s / %s: %s%n", ser.name(), fx.name, e);
            errors.add(new BenchError(fx.name, ser.name(), "prepare", 0, e.toString()));
            continue;
          }
          // Stream buffer reused across reps (issue #59).
          ByteArrayOutputStream streamScratch = new ByteArrayOutputStream(64 * 1024);
          for (String mode : modes) {
            for (int i = 0; i < repetitions; i++) {
              try {
                Measure m =
                    mode.equals("bytes")
                        ? measureBytes(ser, fx)
                        : measureStream(ser, fx, streamScratch);
                logger.writeRow(
                    mode,
                    fx.name,
                    repetitions,
                    i,
                    ser.name(),
                    m.serNs(),
                    m.deserNs(),
                    m.size(),
                    1.0,
                    ser.version(),
                    ser.nativeKind(),
                    ser.streamMode(),
                    w.instanceCount(),
                    w.typeConfigHash());
              } catch (Exception e) {
                System.err.printf(
                    "[ERROR] %s / %s / %s: %s%n", ser.name(), fx.name, mode, e.toString());
                errors.add(new BenchError(fx.name, ser.name(), mode, i, e.toString()));
                break;
              }
            }
          }
        }
      }
      logger.flush();
    }

    saveErrors(errPath, errors);
    System.out.println("[PROGRESS] Complete. Results: " + logPath);
  }

  /** Volatile sink so the JIT cannot dead-code timed work (issue #59). */
  private static volatile Object preventDce;

  private static void keep(Object o) {
    preventDce = o;
  }

  private static Measure measureBytes(BenchSerializer ser, Fixture fx) throws Exception {
    long t0 = System.nanoTime();
    byte[] buf = ser.serializeBytes(fx);
    long serNs = System.nanoTime() - t0;
    keep(buf);
    t0 = System.nanoTime();
    Object out = ser.deserializeBytes(buf);
    long deserNs = System.nanoTime() - t0;
    keep(out);
    out = ser.toDomain(out);
    if (!Fidelity.check(fx.value, out)) {
      throw new IllegalStateException("roundtrip fidelity failed for " + ser.name());
    }
    return new Measure(serNs, deserNs, buf.length);
  }

  /** Stream measure reuses {@code baos} across reps (caller resets; issue #59). */
  private static Measure measureStream(BenchSerializer ser, Fixture fx, ByteArrayOutputStream baos)
      throws Exception {
    baos.reset();
    long t0 = System.nanoTime();
    int n = ser.serializeStream(fx, baos);
    long serNs = System.nanoTime() - t0;
    keep(baos);
    if (n < 0) n = baos.size();
    ByteArrayInputStream bais = new ByteArrayInputStream(baos.toByteArray());
    t0 = System.nanoTime();
    Object out = ser.deserializeStream(bais);
    long deserNs = System.nanoTime() - t0;
    keep(out);
    out = ser.toDomain(out);
    if (!Fidelity.check(fx.value, out)) {
      throw new IllegalStateException("stream roundtrip fidelity failed for " + ser.name());
    }
    return new Measure(serNs, deserNs, n > 0 ? n : baos.size());
  }

  private static Path resolveLogDir(String logDirArg) {
    if (logDirArg != null && !logDirArg.isBlank()) {
      Path p = Path.of(logDirArg);
      if (p.getFileName() != null && p.getFileName().toString().equals("java")) {
        return p;
      }
      return p.resolve("java");
    }
    String env = System.getenv("LOG_DIR");
    if (env != null && !env.isBlank()) {
      Path p = Path.of(env);
      if (p.getFileName() != null && p.getFileName().toString().equals("java")) {
        return p;
      }
      return p.resolve("java");
    }
    Path root = Cells.repoRoot();
    return root.resolve("logs/java");
  }

  private static void saveErrors(Path path, List<BenchError> errors) throws Exception {
    if (errors.isEmpty()) {
      Files.deleteIfExists(path);
      return;
    }
    StringBuilder sb = new StringBuilder();
    sb.append("TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n");
    for (BenchError e : errors) {
      String text = e.errorText().replace('\n', ' ').replace(',', ';');
      sb.append(e.testDataName())
          .append(',')
          .append(e.serializerName())
          .append(',')
          .append(e.stringOrStream())
          .append(',')
          .append(e.repetition())
          .append(',')
          .append(text)
          .append('\n');
    }
    Files.writeString(path, sb.toString());
  }
}
