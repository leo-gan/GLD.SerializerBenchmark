package benchmark.model.v2;

import benchmark.model.Fixture;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/** Resolve run-config cells via scripts/resolve_run_config.py (same as Go/Python). */
public final class Cells {
  private static final ObjectMapper MAPPER = new ObjectMapper();

  public record Cell(
      String typeId,
      Map<String, Object> typeConfig,
      String typeConfigHash,
      int dataTypeInstanceCount) {}

  public record ResolvedRun(List<Cell> cells, List<String> ioModes, long seed) {}

  public record WorkItem(Fixture fixture, int instanceCount, String typeConfigHash) {}

  private Cells() {}

  public static Path repoRoot() {
    Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath();
    for (Path p = dir; p != null; p = p.getParent()) {
      if (Files.isRegularFile(p.resolve("config/benchmark_config.yaml"))) {
        return p;
      }
    }
    return dir;
  }

  public static ResolvedRun loadResolved(String runConfigPath, long seed) throws Exception {
    Path root = repoRoot();
    Path script = root.resolve("scripts/resolve_run_config.py");
    if (runConfigPath == null || runConfigPath.isBlank()) {
      runConfigPath = root.resolve("config/library/default.yaml").toString();
    } else {
      Path candidate = root.resolve(runConfigPath);
      if (Files.isRegularFile(candidate)) {
        runConfigPath = candidate.toString();
      }
    }
    ProcessBuilder pb =
        new ProcessBuilder(
            "python3",
            script.toString(),
            runConfigPath,
            "--seed",
            Long.toString(seed));
    pb.directory(root.toFile());
    Map<String, String> env = pb.environment();
    String analysisSrc = root.resolve("analysis/src").toString();
    String prev = env.getOrDefault("PYTHONPATH", "");
    env.put("PYTHONPATH", prev.isEmpty() ? analysisSrc : analysisSrc + ":" + prev);
    pb.redirectErrorStream(true);
    Process proc = pb.start();
    StringBuilder out = new StringBuilder();
    try (BufferedReader br =
        new BufferedReader(new InputStreamReader(proc.getInputStream(), StandardCharsets.UTF_8))) {
      String line;
      while ((line = br.readLine()) != null) out.append(line).append('\n');
    }
    int code = proc.waitFor();
    if (code != 0) {
      throw new IllegalStateException("resolve_run_config failed (" + code + "): " + out);
    }
    JsonNode rootNode = MAPPER.readTree(out.toString());
    List<Cell> cells = new ArrayList<>();
    for (JsonNode c : rootNode.path("cells")) {
      Map<String, Object> cfg = new HashMap<>();
      JsonNode tc = c.path("type_config");
      if (tc.isObject()) {
        Iterator<Map.Entry<String, JsonNode>> it = tc.fields();
        while (it.hasNext()) {
          Map.Entry<String, JsonNode> e = it.next();
          cfg.put(e.getKey(), MAPPER.convertValue(e.getValue(), Object.class));
        }
      }
      cells.add(
          new Cell(
              c.path("type_id").asText(),
              cfg,
              c.path("type_config_hash").asText(""),
              c.path("data_type_instance_count").asInt(1)));
    }
    List<String> modes = new ArrayList<>();
    for (JsonNode m : rootNode.path("execution").path("io_modes")) {
      modes.add(m.asText());
    }
    long resolvedSeed = seed;
    if (rootNode.hasNonNull("seed")) {
      resolvedSeed = rootNode.get("seed").asLong(seed);
    }
    return new ResolvedRun(cells, modes, resolvedSeed);
  }

  public static WorkItem fixtureFromCell(Cell cell, long seed) {
    int n = Math.max(1, cell.dataTypeInstanceCount());
    List<Object> insts = Generators.instances(cell.typeId(), cell.typeConfig(), seed, n);
    Object value;
    if (n == 1) {
      value = insts.get(0);
    } else {
      value =
          switch (cell.typeId()) {
            case "message" -> {
              List<Message> list = new ArrayList<>(n);
              for (Object o : insts) list.add((Message) o);
              yield list;
            }
            case "document" -> {
              List<Document> list = new ArrayList<>(n);
              for (Object o : insts) list.add((Document) o);
              yield list;
            }
            case "telemetry" -> {
              List<Telemetry> list = new ArrayList<>(n);
              for (Object o : insts) list.add((Telemetry) o);
              yield list;
            }
            case "strings" -> {
              List<Strings> list = new ArrayList<>(n);
              for (Object o : insts) list.add((Strings) o);
              yield list;
            }
            case "event" -> {
              List<Event> list = new ArrayList<>(n);
              for (Object o : insts) list.add((Event) o);
              yield list;
            }
            default -> insts;
          };
    }
    return new WorkItem(new Fixture(cell.typeId(), value), n, cell.typeConfigHash());
  }
}
