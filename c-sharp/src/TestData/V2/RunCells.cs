// Resolve config/library run configs into benchmark cells (type_id × N × hash).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace GLD.SerializerBenchmark.TestData.V2
{
    /// <summary>One expanded cell from resolve_run_config.py.</summary>
    public sealed class RunCellDescription : ITestDataDescription
    {
        private readonly object _data;
        private readonly Type _dataType;
        private readonly List<Type> _secondary;

        public RunCellDescription(
            string typeId,
            int instanceCount,
            string typeConfigHash,
            object data,
            Type dataType,
            List<Type> secondary = null)
        {
            Name = typeId ?? throw new ArgumentNullException(nameof(typeId));
            InstanceCount = instanceCount < 1 ? 1 : instanceCount;
            TypeConfigHash = typeConfigHash ?? "";
            _data = data;
            _dataType = dataType ?? data.GetType();
            _secondary = secondary ?? new List<Type>();
        }

        public string Name { get; }
        public string Description => $"{Name} N={InstanceCount}";
        public Type DataType => _dataType;
        public List<Type> SecondaryDataTypes => _secondary;
        public object Data => _data;
        public int InstanceCount { get; }
        public string TypeConfigHash { get; }
    }

    public static class RunCells
    {
        public static List<RunCellDescription> Load(
            string runConfigPath = null,
            int seed = 42,
            string dataFilter = null)
        {
            var repo = FindRepoRoot();
            if (string.IsNullOrEmpty(runConfigPath))
                runConfigPath = Environment.GetEnvironmentVariable("BENCHMARK_RUN_CONFIG");
            if (string.IsNullOrEmpty(runConfigPath))
                runConfigPath = Path.Combine(repo, "config", "library", "default.yaml");
            if (!Path.IsPathRooted(runConfigPath))
            {
                var cand = Path.Combine(repo, runConfigPath);
                if (File.Exists(cand)) runConfigPath = cand;
            }

            var script = Path.Combine(repo, "scripts", "resolve_run_config.py");
            var psi = new ProcessStartInfo
            {
                FileName = "python3",
                Arguments = $"\"{script}\" \"{runConfigPath}\" --seed {seed}",
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                WorkingDirectory = repo,
            };
            var analysisSrc = Path.Combine(repo, "analysis", "src");
            if (Directory.Exists(analysisSrc))
            {
                var prev = Environment.GetEnvironmentVariable("PYTHONPATH") ?? "";
                psi.Environment["PYTHONPATH"] = string.IsNullOrEmpty(prev)
                    ? analysisSrc
                    : analysisSrc + Path.PathSeparator + prev;
            }

            using var p = Process.Start(psi);
            if (p == null) throw new InvalidOperationException("failed to start resolve_run_config");
            var stdout = p.StandardOutput.ReadToEnd();
            var stderr = p.StandardError.ReadToEnd();
            p.WaitForExit(120_000);
            if (p.ExitCode != 0)
                throw new InvalidOperationException($"resolve_run_config failed: {stderr}\n{stdout}");

            using var doc = JsonDocument.Parse(stdout);
            var cells = new List<RunCellDescription>();
            foreach (var cell in doc.RootElement.GetProperty("cells").EnumerateArray())
            {
                var typeId = cell.GetProperty("type_id").GetString() ?? "";
                if (!string.IsNullOrEmpty(dataFilter) &&
                    typeId.IndexOf(dataFilter, StringComparison.OrdinalIgnoreCase) < 0)
                    continue;
                var n = cell.GetProperty("data_type_instance_count").GetInt32();
                if (n < 1) n = 1;
                var hash = cell.TryGetProperty("type_config_hash", out var h) ? h.GetString() ?? "" : "";
                var (data, dataType, secondary) = BuildPayload(typeId, n, seed);
                cells.Add(new RunCellDescription(typeId, n, hash, data, dataType, secondary));
            }
            return cells;
        }

        /// <summary>Typed single instance or List&lt;T&gt; batch for serializers.</summary>
        public static (object data, Type dataType, List<Type> secondary) BuildPayload(
            string typeId, int n, int seed)
        {
            switch (typeId)
            {
                case "message":
                case "event":
                {
                    var list = new List<SimpleObject>(n);
                    for (int i = 0; i < n; i++)
                        list.Add(MakeSimple(typeId, seed, i));
                    if (n == 1) return (list[0], typeof(SimpleObject), new List<Type>());
                    return (list, typeof(List<SimpleObject>), new List<Type>());
                }
                case "document":
                {
                    var list = new List<EDI835>(n);
                    for (int i = 0; i < n; i++)
                        list.Add(MakeDocument(seed, i));
                    var sec = new List<Type> { typeof(Claim), typeof(ServiceLine) };
                    if (n == 1) return (list[0], typeof(EDI835), sec);
                    return (list, typeof(List<EDI835>), sec);
                }
                case "telemetry":
                {
                    var list = new List<TelemetryData>(n);
                    int meas = Randomizer.Settings.CollectionOptions.TelemetryMeasurementsCount;
                    for (int i = 0; i < n; i++)
                        list.Add(MakeTelemetry(seed, i, meas));
                    if (n == 1) return (list[0], typeof(TelemetryData), new List<Type>());
                    return (list, typeof(List<TelemetryData>), new List<Type>());
                }
                case "strings":
                {
                    var list = new List<StringArrayObject>(n);
                    for (int i = 0; i < n; i++)
                        list.Add(StringArrayObject.Generate(32));
                    if (n == 1) return (list[0], typeof(StringArrayObject), new List<Type>());
                    return (list, typeof(List<StringArrayObject>), new List<Type>());
                }
                default:
                    throw new ArgumentException($"unknown type_id: {typeId}");
            }
        }

        static SimpleObject MakeSimple(string typeId, int seed, int idx)
        {
            var r = new Random(unchecked(seed * 397 ^ idx * 7919 ^ typeId.GetHashCode()));
            return new SimpleObject
            {
                Id = r.Next(0, 1_000_000),
                Name = (typeId == "event" ? "evt-" : "msg-") + r.Next(1000, 9999),
                Timestamp = DateTime.UtcNow.AddSeconds(-r.Next(0, 86400)),
                IsActive = r.Next(0, 2) == 1,
            };
        }

        static EDI835 MakeDocument(int seed, int idx)
        {
            // Deterministic-ish: reseeding Randomizer is global; use EDI835.Generate then tweak.
            var doc = EDI835.Generate();
            doc.TransactionControlNumber = $"TRN-{seed:x}-{idx}";
            doc.TotalActualAmount = 1000 + (seed % 100) + idx;
            return doc;
        }

        static TelemetryData MakeTelemetry(int seed, int idx, int measCount)
        {
            var r = new Random(unchecked(seed * 911 ^ idx * 1301));
            var t = new TelemetryData
            {
                Id = "tel-" + r.Next(100000, 999999),
                DataSource = "src-" + r.Next(1000, 9999),
                TimeStamp = DateTime.UtcNow.AddMilliseconds(-r.Next(0, 86400000)),
                Param1 = r.Next(int.MinValue / 4, int.MaxValue / 4),
                Param2 = (uint)r.Next(0, int.MaxValue / 2),
                Measurements = new double[measCount],
                AssociatedProblemID = 1000 + idx,
                AssociatedLogID = 2000 + idx,
                WasProcessed = (idx % 2) == 0,
            };
            for (int i = 0; i < measCount; i++)
                t.Measurements[i] = r.NextDouble() * 100.0;
            return t;
        }

        public static string FindRepoRoot()
        {
            var env = Environment.GetEnvironmentVariable("BENCHMARK_REPO_ROOT");
            if (!string.IsNullOrEmpty(env) &&
                File.Exists(Path.Combine(env, "config", "benchmark_config.yaml")))
                return Path.GetFullPath(env);

            foreach (var start in new[]
                     {
                         Directory.GetCurrentDirectory(),
                         AppContext.BaseDirectory,
                         // Common when binary is under c-sharp/src/bin/.../net8.0/
                         Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..")),
                         Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..")),
                         Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "..")),
                     })
            {
                try
                {
                    var dir = new DirectoryInfo(start);
                    while (dir != null)
                    {
                        if (File.Exists(Path.Combine(dir.FullName, "config", "benchmark_config.yaml")))
                            return dir.FullName;
                        dir = dir.Parent;
                    }
                }
                catch { /* ignore */ }
            }
            return Directory.GetCurrentDirectory();
        }
    }
}
