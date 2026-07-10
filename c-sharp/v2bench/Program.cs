using System.Diagnostics;
using System.Text.Json;

var reps = args.Length > 0 ? int.Parse(args[0]) : 10;
var repo = FindRepo();
var runCfg = Environment.GetEnvironmentVariable("BENCHMARK_RUN_CONFIG")
    ?? Path.Combine(repo, "config/library/default.yaml");
var seed = int.TryParse(Environment.GetEnvironmentVariable("BENCHMARK_SEED"), out var s) ? s : 42;
// Use LOG_DIR as-is when set (orchestrators pass the final language log directory).
var logDir = Environment.GetEnvironmentVariable("LOG_DIR")
    ?? Path.Combine(repo, "logs", "csharp");
Directory.CreateDirectory(logDir);

var psi = new ProcessStartInfo {
    FileName = "python3",
    Arguments = $"\"{Path.Combine(repo, "scripts/resolve_run_config.py")}\" \"{runCfg}\" --seed {seed}",
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    UseShellExecute = false,
    WorkingDirectory = repo,
};
psi.Environment["PYTHONPATH"] = Path.Combine(repo, "analysis/src");
using var proc = Process.Start(psi)!;
var stdout = proc.StandardOutput.ReadToEnd();
proc.WaitForExit();
if (proc.ExitCode != 0) {
    Console.Error.WriteLine(proc.StandardError.ReadToEnd());
    return 1;
}
using var doc = JsonDocument.Parse(stdout);
var ts = Environment.GetEnvironmentVariable("BENCHMARK_TS") ?? DateTime.Now.ToString("yyyy-MM-dd-HHmmss");
var csv = Path.Combine(logDir, ts + ".csv");
using var w = new StreamWriter(csv);
w.WriteLine("Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash");
var opts = new JsonSerializerOptions();
foreach (var cell in doc.RootElement.GetProperty("cells").EnumerateArray())
{
    var typeId = cell.GetProperty("type_id").GetString()!;
    var n = cell.GetProperty("data_type_instance_count").GetInt32();
    var hash = cell.TryGetProperty("type_config_hash", out var h) ? h.GetString() ?? "" : "";
    var cfg = cell.GetProperty("type_config");
    int children = cfg.TryGetProperty("children", out var ch) ? ch.GetInt32() : 8;
    int points = cfg.TryGetProperty("points", out var pt) ? pt.GetInt32() : 32;
    int count = cfg.TryGetProperty("count", out var ct) ? ct.GetInt32() : 32;
    int attrs = cfg.TryGetProperty("attr_count", out var ac) ? ac.GetInt32() : 4;
    object payload;
    if (n <= 1) payload = MakeOne(typeId, seed, 0, children, points, count, attrs);
    else {
        var list = new List<object>();
        for (int i = 0; i < n; i++) list.Add(MakeOne(typeId, seed, i, children, points, count, attrs));
        payload = list;
    }
    Console.WriteLine($"[PROGRESS] Cell {typeId} N={n}");
    for (int i = 0; i < reps; i++)
    {
        var sw = Stopwatch.StartNew();
        var bytes = JsonSerializer.SerializeToUtf8Bytes(payload, opts);
        sw.Stop();
        var serNs = (long)(sw.Elapsed.TotalMilliseconds * 1_000_000);
        sw.Restart();
        _ = JsonSerializer.Deserialize<JsonElement>(bytes);
        sw.Stop();
        var deserNs = (long)(sw.Elapsed.TotalMilliseconds * 1_000_000);
        var total = serNs + deserNs;
        double opsSer = serNs > 0 ? 1e9 / serNs : 0;
        double opsDeser = deserNs > 0 ? 1e9 / deserNs : 0;
        double opsTot = total > 0 ? 1e9 / total : 0;
        w.WriteLine($"csharp,bytes,{typeId},{reps},{i},System.Text.Json,{Environment.Version},{serNs},{deserNs},{bytes.Length},{total},{opsSer:F6},{opsDeser:F6},{opsTot:F6},0,1.00,{n},{hash}");
    }
}
Console.WriteLine("[PROGRESS] Complete. Results: " + csv);
return 0;

static string FindRepo()
{
    var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (dir != null)
    {
        if (File.Exists(Path.Combine(dir.FullName, "config", "benchmark_config.yaml")))
            return dir.FullName;
        dir = dir.Parent;
    }
    return Directory.GetCurrentDirectory();
}

static object MakeOne(string typeId, int seed, int idx, int children, int points, int count, int attrCount)
{
    var r = new Rng(Mix(seed, typeId, idx));
    return typeId switch
    {
        "message" => new Dictionary<string, object?> {
            ["f_bool"] = r.NextBool(), ["f_int32"] = r.NextInt(0, 1_000_000),
            ["f_int64"] = (long)r.NextInt(0, 1_000_000), ["f_float64"] = r.NextF64() * 1000,
            ["f_string"] = r.Word(3, 16), ["f_bool_2"] = r.NextBool(),
            ["f_int32_2"] = r.NextInt(0, 1_000_000), ["f_string_2"] = r.Word(3, 16),
        },
        "document" => new Dictionary<string, object?> {
            ["id"] = r.Word(8, 12), ["status"] = r.NextInt(0, 5),
            ["meta"] = new Dictionary<string, object?> { ["region"] = r.Word(2, 4), ["version"] = r.NextInt(1, 10) },
            ["items"] = Enumerable.Range(0, children).Select(_ => new Dictionary<string, object?> {
                ["sku"] = r.Word(3, 12), ["qty"] = r.NextInt(1, 100), ["price_minor"] = (long)r.NextInt(0, 100000)
            }).ToList()
        },
        "telemetry" => new Dictionary<string, object?> {
            ["source"] = r.Word(3, 10), ["ts"] = 1704067200000L + r.NextInt(0, 86400000),
            ["tags"] = Enumerable.Range(0, 2).Select(_ => r.Word(3, 10)).ToList(),
            ["values"] = Enumerable.Range(0, points).Select(_ => r.NextF64() * 100).ToList(),
        },
        "strings" => new Dictionary<string, object?> {
            ["items"] = Enumerable.Range(0, count).Select(_ => r.Word(3, 16)).ToList()
        },
        "event" => new Dictionary<string, object?> {
            ["event_id"] = r.Word(8, 12), ["event_type"] = r.Word(3, 12),
            ["occurred_at"] = 1704067200000L + r.NextInt(0, 86400000),
            ["producer"] = r.Word(3, 12),
            ["attrs"] = Enumerable.Range(0, attrCount).Select(_ => new Dictionary<string, object?> {
                ["key"] = r.Word(3, 12), ["value"] = r.Word(3, 12)
            }).ToList()
        },
        _ => throw new ArgumentException(typeId)
    };
}

static ulong Mix(int seed, string typeId, int idx)
{
    ulong h = (ulong)seed;
    foreach (var ch in typeId) h = (h ^ ch) * 0x100000001B3UL;
    h ^= (ulong)idx * 0x9E3779B97F4A7C15UL;
    return h == 0 ? 1UL : h;
}

sealed class Rng
{
    ulong _s;
    public Rng(ulong seed) => _s = seed == 0 ? 0x9E3779B97F4A7C15UL : seed;
    public ulong NextU64() { var x = _s; x ^= x << 13; x ^= x >> 7; x ^= x << 17; _s = x; return x; }
    public int NextInt(int lo, int hi) => hi <= lo ? lo : lo + (int)(NextU64() % (ulong)(hi - lo + 1));
    public bool NextBool() => (NextU64() & 1) == 1;
    public double NextF64() => (NextU64() >> 11) * (1.0 / (1UL << 53));
    public string Word(int a, int b)
    {
        int n = NextInt(a, b);
        const string alpha = "abcdefghijklmnopqrstuvwxyz";
        return new string(Enumerable.Range(0, n).Select(_ => alpha[(int)(NextU64() % 26)]).ToArray());
    }
}
