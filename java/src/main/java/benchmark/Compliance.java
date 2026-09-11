package benchmark;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.cbor.CBORFactory;
import com.fasterxml.jackson.dataformat.smile.SmileFactory;
import com.fasterxml.jackson.dataformat.yaml.YAMLMapper;
import com.google.gson.Gson;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import org.bson.RawBsonDocument;
import org.msgpack.jackson.dataformat.MessagePackFactory;

/** Java compliance runner — same catalog as Python. */
public final class Compliance {
  private static final ObjectMapper JSON = new ObjectMapper();

  public static void main(String[] args) throws Exception {
    String jsonOut = null;
    List<String> formats = new ArrayList<>();
    for (int i = 0; i < args.length; i++) {
      if (("-o".equals(args[i]) || "--json-out".equals(args[i])) && i + 1 < args.length) {
        jsonOut = args[++i];
      } else if (("-f".equals(args[i]) || "--format".equals(args[i])) && i + 1 < args.length) {
        formats.add(args[++i].toLowerCase());
      }
    }
    Path root = repoRoot();
    List<Map<String, Object>> suites = loadSuites(root.resolve("compliance/data"));
    if (!formats.isEmpty()) {
      suites.removeIf(s -> !formats.contains(String.valueOf(s.get("format")).toLowerCase()));
    }
    List<Adapter> adapters = adapters();
    Map<String, List<Adapter>> byFmt = new TreeMap<>();
    for (Adapter a : adapters) {
      byFmt.computeIfAbsent(a.format, k -> new ArrayList<>()).add(a);
    }
    List<Map<String, Object>> results = new ArrayList<>();
    List<String> adapterErrs = new ArrayList<>();
    for (Map<String, Object> suite : suites) {
      String fmt = String.valueOf(suite.get("format"));
      List<Adapter> chosen = byFmt.getOrDefault(fmt, List.of());
      if (chosen.isEmpty()) {
        adapterErrs.add(
            "No adapter registered for format "
                + fmt
                + " ("
                + suite.get("standard")
                + " ("
                + suite.get("version")
                + "))");
        continue;
      }
      @SuppressWarnings("unchecked")
      List<Map<String, Object>> cases = (List<Map<String, Object>>) suite.get("cases");
      for (Adapter a : chosen) {
        for (Map<String, Object> c : cases) {
          results.add(runOne(suite, c, a));
        }
      }
    }
    printSummary(results, adapterErrs);
    if (jsonOut != null) {
      writeReport(Path.of(jsonOut), results, adapterErrs);
      System.out.println("\nWrote " + jsonOut);
    }
  }

  private static Path repoRoot() throws Exception {
    Path dir = Path.of("").toAbsolutePath();
    for (int i = 0; i < 8; i++) {
      if (Files.isDirectory(dir.resolve("compliance/data"))) {
        return dir;
      }
      Path parent = dir.getParent();
      if (parent == null) {
        break;
      }
      dir = parent;
    }
    throw new IllegalStateException("cannot locate compliance/data");
  }

  @SuppressWarnings("unchecked")
  private static List<Map<String, Object>> loadSuites(Path root) throws Exception {
    List<Map<String, Object>> suites = new ArrayList<>();
    try (var dirs = Files.list(root)) {
      for (Path fmt : dirs.filter(Files::isDirectory).toList()) {
        try (var files = Files.list(fmt)) {
          for (Path f : files.filter(p -> p.getFileName().toString().endsWith(".json")).toList()) {
            if (f.getFileName().toString().startsWith("_")) {
              continue;
            }
            Map<String, Object> raw = JSON.readValue(f.toFile(), Map.class);
            Object cases = raw.get("cases");
            if (cases instanceof List<?> list && !list.isEmpty() && raw.get("format") != null) {
              suites.add(raw);
            }
          }
        }
      }
    }
    if (suites.isEmpty()) {
      throw new IllegalStateException("no compliance suites under " + root);
    }
    return suites;
  }

  private record Adapter(String name, String format, String version, Fn decode) {}

  @FunctionalInterface
  private interface Fn {
    Object apply(byte[] data) throws Exception;
  }

  private static List<Adapter> adapters() {
    ObjectMapper cbor = new ObjectMapper(new CBORFactory());
    ObjectMapper smile = new ObjectMapper(new SmileFactory());
    ObjectMapper msgpack = new ObjectMapper(new MessagePackFactory());
    Gson gson = new Gson();
    List<Adapter> out = new ArrayList<>();
    out.add(new Adapter("jackson", "json", "", b -> JSON.readValue(b, Object.class)));
    out.add(new Adapter("gson", "json", "", b -> gson.fromJson(new String(b, StandardCharsets.UTF_8), Object.class)));
    out.add(new Adapter("jackson-cbor", "cbor", "", b -> cbor.readValue(b, Object.class)));
    out.add(new Adapter("jackson-smile", "smile", "", b -> smile.readValue(b, Object.class)));
    out.add(new Adapter("msgpack", "msgpack", "", b -> msgpack.readValue(b, Object.class)));
    out.add(
        new Adapter(
            "bson",
            "bson",
            "",
            b -> {
              RawBsonDocument raw = new RawBsonDocument(b);
              return JSON.readValue(raw.toJson(), Object.class);
            }));
    ObjectMapper yaml = new YAMLMapper();
    out.add(new Adapter("jackson-yaml", "yaml", "", b -> yaml.readValue(b, Object.class)));
    return out;
  }

  private static Map<String, Object> runOne(
      Map<String, Object> suite, Map<String, Object> c, Adapter a) {
    Map<String, Object> base = new LinkedHashMap<>();
    base.put("id", c.get("id"));
    base.put("language", "java");
    base.put("serializer", a.name);
    base.put("serializer_version", a.version);
    base.put("format", suite.get("format"));
    base.put("standard", suite.get("standard"));
    base.put("standard_url", suite.get("standard_url"));
    base.put("version", suite.get("version"));
    base.put("version_key", suite.get("format") + "." + suite.get("version"));
    base.put("requirement", c.get("requirement"));
    base.put("expect", c.get("expect"));
    base.put("section", c.get("section"));
    base.put("section_title", c.get("section_title"));
    base.put("section_url", c.get("section_url"));
    base.put("paragraph", c.get("paragraph"));
    base.put("title", c.get("title"));
    base.put("input", c.get("input"));
    base.put("input_encoding", c.getOrDefault("input_encoding", "utf-8"));
    base.put("detail", "");
    base.put("observed", "");
    base.put("outcome", "pass");
    Object got;
    boolean ok;
    String err = "";
    try {
      got = a.decode.apply(inputBytes(c));
      ok = true;
    } catch (Exception ex) {
      got = null;
      ok = false;
      err = ex.getClass().getSimpleName() + ": " + ex.getMessage();
    }
    String expect = String.valueOf(c.getOrDefault("expect", ""));
    if ("any".equals(expect)) {
      base.put("observed", ok ? preview(got) : err);
      return base;
    }
    if ("reject".equals(expect)) {
      if (!ok) {
        base.put("observed", err);
        return base;
      }
      base.put("outcome", "fail");
      base.put("detail", "parser accepted input the spec requires to be rejected");
      base.put("observed", "accepted as " + preview(got));
      return base;
    }
    if (!ok) {
      base.put("outcome", "fail");
      base.put("detail", "parser rejected input the spec requires to accept");
      base.put("observed", err);
      return base;
    }
    if (c.containsKey("decoded") && !valuesEqual(c.get("decoded"), got)) {
      base.put("outcome", "fail");
      base.put("detail", "decoded value does not match the catalog case");
      base.put("observed", "got " + preview(got) + ", want " + preview(c.get("decoded")));
      return base;
    }
    base.put("observed", preview(got));
    return base;
  }

  private static byte[] inputBytes(Map<String, Object> c) {
    String enc = String.valueOf(c.getOrDefault("input_encoding", "utf-8"));
    String in = String.valueOf(c.getOrDefault("input", ""));
    if ("hex".equals(enc)) {
      String compact = in.replaceAll("\\s+", "");
      return compact.isEmpty() ? new byte[0] : HexFormat.of().parseHex(compact);
    }
    return in.getBytes(StandardCharsets.UTF_8);
  }

  private static boolean valuesEqual(Object expected, Object observed) {
    if (expected == null) {
      return observed == null;
    }
    if (expected instanceof Boolean || observed instanceof Boolean) {
      return expected.equals(observed);
    }
    if (expected instanceof Number && observed instanceof Number) {
      return ((Number) expected).doubleValue() == ((Number) observed).doubleValue();
    }
    if (expected instanceof String) {
      return expected.equals(observed);
    }
    if (expected instanceof List<?> e && observed instanceof List<?> o) {
      if (e.size() != o.size()) {
        return false;
      }
      for (int i = 0; i < e.size(); i++) {
        if (!valuesEqual(e.get(i), o.get(i))) {
          return false;
        }
      }
      return true;
    }
    if (expected instanceof Map<?, ?> e && observed instanceof Map<?, ?> o) {
      if (e.size() != o.size()) {
        return false;
      }
      for (var en : e.entrySet()) {
        if (!valuesEqual(en.getValue(), o.get(en.getKey()))) {
          return false;
        }
      }
      return true;
    }
    return String.valueOf(expected).equals(String.valueOf(observed));
  }

  private static String preview(Object v) {
    try {
      String s = JSON.writeValueAsString(v);
      return s.length() > 120 ? s.substring(0, 117) + "..." : s;
    } catch (Exception e) {
      String s = String.valueOf(v);
      return s.length() > 120 ? s.substring(0, 117) + "..." : s;
    }
  }

  private static void printSummary(List<Map<String, Object>> results, List<String> adapterErrs) {
    int p = 0, f = 0, s = 0, e = 0;
    Map<String, int[]> by = new TreeMap<>();
    for (var r : results) {
      String o = String.valueOf(r.get("outcome"));
      switch (o) {
        case "pass" -> p++;
        case "fail" -> f++;
        case "skip" -> s++;
        default -> e++;
      }
      String k = r.get("standard") + " (" + r.get("version") + ") × " + r.get("serializer");
      int[] c = by.computeIfAbsent(k, x -> new int[3]);
      if ("pass".equals(o)) {
        c[0]++;
      } else if ("fail".equals(o)) {
        c[1]++;
      } else {
        c[2]++;
      }
    }
    System.out.println("Serialization compliance (library deviations are catalogued, not a red build)");
    System.out.printf("  %d pass  %d fail  %d skip  %d error  %d total%n", p, f, s, e, results.size());
    if (!adapterErrs.isEmpty()) {
      System.out.println("  Adapter errors:");
      adapterErrs.forEach(a -> System.out.println("    - " + a));
    }
    System.out.println("  By suite × adapter:");
    by.forEach((k, c) -> System.out.printf("    %s: %d pass, %d fail, %d skip%n", k, c[0], c[1], c[2]));
  }

  private static void writeReport(Path path, List<Map<String, Object>> results, List<String> adapterErrs)
      throws Exception {
    int p = 0, f = 0, s = 0, e = 0;
    List<String> fmts = new ArrayList<>();
    for (var r : results) {
      switch (String.valueOf(r.get("outcome"))) {
        case "pass" -> p++;
        case "fail" -> f++;
        case "skip" -> s++;
        default -> e++;
      }
      String fmt = String.valueOf(r.get("format"));
      if (!fmts.contains(fmt)) {
        fmts.add(fmt);
      }
    }
    Map<String, Object> doc = new LinkedHashMap<>();
    doc.put("schema", "gld.dashboard.compliance/1");
    doc.put(
        "generated_at",
        DateTimeFormatter.ISO_INSTANT.format(Instant.now().atOffset(ZoneOffset.UTC)));
    doc.put("language", "java");
    doc.put("languages", List.of("java"));
    doc.put("policy", "report-only");
    doc.put("scope", Map.of("formats", fmts));
    doc.put("passed", p);
    doc.put("failed", f);
    doc.put("skipped", s);
    doc.put("errors", e);
    doc.put("catalog_errors", List.of());
    doc.put("serializer_errors", adapterErrs);
    doc.put("results", results);
    Files.createDirectories(path.getParent());
    JSON.getFactory().configure(com.fasterxml.jackson.core.JsonGenerator.Feature.ESCAPE_NON_ASCII, true);
    Files.writeString(path, JSON.writerWithDefaultPrettyPrinter().writeValueAsString(doc) + "\n");
  }
}
