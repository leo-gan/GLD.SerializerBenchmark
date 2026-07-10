// Data Model v2 generators + fixtures for harness cutover.
// Within-language deterministic. Cross-language identity not required.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Linq;

namespace GLD.SerializerBenchmark.TestData.V2
{
    public static class DataV2
    {
        const long BaseTsMs = 1704067200000L;

        sealed class Rng
        {
            ulong _state;
            public Rng(ulong seed) { _state = seed == 0 ? 0x9E3779B97F4A7C15UL : seed; }
            public ulong NextU64()
            {
                var x = _state;
                x ^= x << 13; x ^= x >> 7; x ^= x << 17;
                _state = x;
                return x;
            }
            public int NextInt(int lo, int hi)
            {
                if (hi <= lo) return lo;
                return lo + (int)(NextU64() % (ulong)(hi - lo + 1));
            }
            public bool NextBool() => (NextU64() & 1) == 1;
            public double NextF64() => (NextU64() >> 11) * (1.0 / (1UL << 53));
            public string Word(int minL, int maxL)
            {
                int n = NextInt(minL, maxL);
                const string a = "abcdefghijklmnopqrstuvwxyz";
                var chars = new char[n];
                for (int i = 0; i < n; i++) chars[i] = a[(int)(NextU64() % 26)];
                return new string(chars);
            }
        }

        static ulong MixSeed(ulong seed, string typeId, int idx)
        {
            ulong h = seed;
            foreach (var ch in typeId)
                h = (h ^ ch) * 0x100000001B3UL;
            h ^= (ulong)idx * 0x9E3779B97F4A7C15UL;
            return h == 0 ? 1UL : h;
        }

        public static object MakeOne(string typeId, int seed = 42, int instanceIndex = 0,
            int children = 8, int points = 32, int count = 32, int attrCount = 4, int tagCount = 2)
        {
            var r = new Rng(MixSeed((ulong)seed, typeId, instanceIndex));
            switch (typeId)
            {
                case "message":
                    return new Dictionary<string, object> {
                        ["f_bool"] = r.NextBool(), ["f_int32"] = r.NextInt(0, 1_000_000),
                        ["f_int64"] = (long)r.NextInt(0, 1_000_000), ["f_float64"] = r.NextF64() * 1000,
                        ["f_string"] = r.Word(3, 16), ["f_bool_2"] = r.NextBool(),
                        ["f_int32_2"] = r.NextInt(0, 1_000_000), ["f_string_2"] = r.Word(3, 16),
                    };
                case "document":
                {
                    var items = new List<object>();
                    for (int i = 0; i < children; i++)
                        items.Add(new Dictionary<string, object> {
                            ["sku"] = r.Word(3, 12), ["qty"] = r.NextInt(1, 100),
                            ["price_minor"] = (long)r.NextInt(0, 100000)
                        });
                    return new Dictionary<string, object> {
                        ["id"] = r.Word(8, 12), ["status"] = r.NextInt(0, 5),
                        ["meta"] = new Dictionary<string, object> {
                            ["region"] = r.Word(2, 4), ["version"] = r.NextInt(1, 10)
                        },
                        ["items"] = items
                    };
                }
                case "telemetry":
                {
                    var tags = new List<string>();
                    for (int i = 0; i < tagCount; i++) tags.Add(r.Word(3, 10));
                    var values = new List<double>();
                    for (int i = 0; i < points; i++) values.Add(r.NextF64() * 100);
                    return new Dictionary<string, object> {
                        ["source"] = r.Word(3, 10), ["ts"] = BaseTsMs + r.NextInt(0, 86400000),
                        ["tags"] = tags, ["values"] = values,
                    };
                }
                case "strings":
                {
                    var items = new List<string>();
                    for (int i = 0; i < count; i++) items.Add(r.Word(3, 16));
                    return new Dictionary<string, object> { ["items"] = items };
                }
                case "event":
                {
                    var attrs = new List<object>();
                    for (int i = 0; i < attrCount; i++)
                        attrs.Add(new Dictionary<string, object> {
                            ["key"] = r.Word(3, 12), ["value"] = r.Word(3, 12)
                        });
                    return new Dictionary<string, object> {
                        ["event_id"] = r.Word(8, 12), ["event_type"] = r.Word(3, 12),
                        ["occurred_at"] = BaseTsMs + r.NextInt(0, 86400000),
                        ["producer"] = r.Word(3, 12), ["attrs"] = attrs,
                    };
                }
                default:
                    throw new ArgumentException("unknown type_id: " + typeId);
            }
        }

        public static object BuildPayload(string typeId, int n, int seed, Dictionary<string, object> cfg)
        {
            int children = cfg != null && cfg.ContainsKey("children") ? Convert.ToInt32(cfg["children"]) : 8;
            int points = cfg != null && cfg.ContainsKey("points") ? Convert.ToInt32(cfg["points"]) : 32;
            int count = cfg != null && cfg.ContainsKey("count") ? Convert.ToInt32(cfg["count"]) : 32;
            int attrs = cfg != null && cfg.ContainsKey("attr_count") ? Convert.ToInt32(cfg["attr_count"]) : 4;
            if (n <= 1)
                return MakeOne(typeId, seed, 0, children, points, count, attrs);
            var list = new List<object>();
            for (int i = 0; i < n; i++)
                list.Add(MakeOne(typeId, seed, i, children, points, count, attrs));
            return list;
        }

        /// <summary>
        /// Minimal STJ-only v2 smoke/full path when full serializer matrix is not yet ported.
        /// </summary>
        public static int RunSystemTextJsonBenchmark(int repetitions, string logDir, string runConfigPath, int seed)
        {
            // Resolve cells via python (same as other languages)
            var repo = FindRepoRoot();
            var psi = new ProcessStartInfo
            {
                FileName = "python3",
                Arguments = $"\"{Path.Combine(repo, "scripts/resolve_run_config.py")}\" \"{runConfigPath}\" --seed {seed}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                WorkingDirectory = repo,
            };
            psi.Environment["PYTHONPATH"] = Path.Combine(repo, "analysis", "src");
            using var p = Process.Start(psi);
            var stdout = p.StandardOutput.ReadToEnd();
            p.WaitForExit();
            if (p.ExitCode != 0)
                throw new Exception("resolve_run_config failed: " + p.StandardError.ReadToEnd());

            using var doc = JsonDocument.Parse(stdout);
            var cells = doc.RootElement.GetProperty("cells");
            Directory.CreateDirectory(logDir);
            var ts = Environment.GetEnvironmentVariable("BENCHMARK_TS")
                     ?? DateTime.Now.ToString("yyyy-MM-dd-HHmmss");
            var path = Path.Combine(logDir, ts + ".csv");
            using var w = new StreamWriter(path);
            w.WriteLine("Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash");
            var opts = new JsonSerializerOptions { PropertyNamingPolicy = null };
            foreach (var cell in cells.EnumerateArray())
            {
                var typeId = cell.GetProperty("type_id").GetString();
                var n = cell.GetProperty("data_type_instance_count").GetInt32();
                var hash = cell.GetProperty("type_config_hash").GetString() ?? "";
                var cfgEl = cell.GetProperty("type_config");
                var cfg = new Dictionary<string, object>();
                if (cfgEl.TryGetProperty("points", out var pts)) cfg["points"] = pts.GetInt32();
                if (cfgEl.TryGetProperty("children", out var ch)) cfg["children"] = ch.GetInt32();
                if (cfgEl.TryGetProperty("count", out var ct)) cfg["count"] = ct.GetInt32();
                if (cfgEl.TryGetProperty("attr_count", out var ac)) cfg["attr_count"] = ac.GetInt32();
                var payload = BuildPayload(typeId, n, seed, cfg);
                Console.WriteLine($"[PROGRESS] Cell {typeId} N={n}");
                for (int i = 0; i < repetitions; i++)
                {
                    var sw = Stopwatch.StartNew();
                    var bytes = JsonSerializer.SerializeToUtf8Bytes(payload, opts);
                    sw.Stop();
                    var serNs = (long)(sw.Elapsed.TotalMilliseconds * 1e6);
                    sw.Restart();
                    var back = JsonSerializer.Deserialize<JsonElement>(bytes);
                    sw.Stop();
                    var deserNs = (long)(sw.Elapsed.TotalMilliseconds * 1e6);
                    var total = serNs + deserNs;
                    double opsSer = serNs > 0 ? 1e9 / serNs : 0;
                    double opsDeser = deserNs > 0 ? 1e9 / deserNs : 0;
                    double opsTot = total > 0 ? 1e9 / total : 0;
                    w.WriteLine($"csharp,bytes,{typeId},{repetitions},{i},System.Text.Json,{Environment.Version},{serNs},{deserNs},{bytes.Length},{total},{opsSer:F6},{opsDeser:F6},{opsTot:F6},0,1.00,{n},{hash}");
                }
            }
            Console.WriteLine("[PROGRESS] Complete. Results: " + path);
            return 0;
        }

        static string FindRepoRoot()
        {
            var dir = new DirectoryInfo(AppContext.BaseDirectory);
            while (dir != null)
            {
                if (File.Exists(Path.Combine(dir.FullName, "config", "benchmark_config.yaml")))
                    return dir.FullName;
                dir = dir.Parent;
            }
            return Directory.GetCurrentDirectory();
        }
    }
}
