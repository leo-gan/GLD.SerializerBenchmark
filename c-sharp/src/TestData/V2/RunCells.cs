// Resolve config/library run configs into benchmark cells (type_id × N × hash).
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text.Json;

namespace GLD.SerializerBenchmark.TestData.V2
{
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
                var typeConfig = cell.TryGetProperty("type_config", out var tc) ? tc : default;
                var (data, dataType, secondary) = Generator.BuildPayload(typeId, typeConfig, n, seed);
                cells.Add(new RunCellDescription(typeId, n, hash, data, dataType, secondary));
            }
            return cells;
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
