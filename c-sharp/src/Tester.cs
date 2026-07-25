using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class Tester
    {
        public static void Tests(List<ISerDeser> serializers, List<ITestDataDescription> testDataDescriptions,
            int repetitions)
        {
            // Prefer LOG_DIR (orchestrator) so monorepo logs/csharp stays consistent.
            var logDir = Environment.GetEnvironmentVariable("LOG_DIR");
            if (string.IsNullOrEmpty(logDir))
                logDir = "logs/csharp";
            else if (!logDir.EndsWith("csharp") && !logDir.EndsWith("c-sharp"))
                logDir = Path.Combine(logDir, "csharp");
            Directory.CreateDirectory(logDir);

            // Timestamped result file — each run creates YYYY-MM-DD-HHMMSS.csv, never overwritten.
            var ts = Environment.GetEnvironmentVariable("BENCHMARK_TS");
            if (string.IsNullOrEmpty(ts))
                ts = DateTime.Now.ToString("yyyy-MM-dd-HHmmss");
            var logPath = Path.Combine(logDir, $"{ts}.csv");
            // Per-run errors beside the result CSV (same stem as .configs.json)
            var errorsPath = Path.Combine(logDir, $"{ts}.errors.csv");

            var logStorage = new LogStorage(logPath);
            var errors = new List<Error>();

            _scheduleStrategy = Schedule.ResolveStrategy();
            _recordRunOrder = Schedule.ResolveRecordRunOrder();
            _globalRunOrder = 0;
            var seedEnv = Environment.GetEnvironmentVariable("BENCHMARK_SEED");
            if (!string.IsNullOrEmpty(seedEnv) && long.TryParse(seedEnv, out var seedParsed))
                _baseSeed = seedParsed;
            Console.WriteLine(
                $"[PROGRESS] schedule={_scheduleStrategy} record_run_order={_recordRunOrder} seed={_baseSeed}");

            foreach (var testDataDescription in testDataDescriptions)
            {
                var n = GetInstanceCount(testDataDescription);
                var hash = GetTypeConfigHash(testDataDescription);
                Console.WriteLine(
                    $"\n[PROGRESS] Testing Data: {testDataDescription.Name} N={n} " +
                    $"(Targeting {serializers.Count} serializers, {repetitions} reps)");
                TestOnData(testDataDescription, repetitions, serializers, logStorage, errors, n, hash);
                Error.SaveErrors(errors, errorsPath);
            }

            Report.AllResults(repetitions, logStorage, errors, serializers, testDataDescriptions);

            TryCaptureEnvironment(logPath);

            Console.WriteLine($"\n[PROGRESS] Benchmark Complete. Results saved to {logPath}");
        }

        /// <summary>
        /// Write logs/csharp/&lt;ts&gt;.configs.json via analysis package when available on PATH.
        /// run-benchmarks.sh / run-all-benchmarks.sh also capture sidecars on the host.
        /// </summary>
        private static void TryCaptureEnvironment(string logPath)
        {
            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = "python3",
                    Arguments = $"-m benchmark_analysis.environment \"{logPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                };
                var analysisSrc = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "analysis", "src"));
                if (!Directory.Exists(analysisSrc))
                    analysisSrc = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "analysis", "src"));
                if (Directory.Exists(analysisSrc))
                    psi.Environment["PYTHONPATH"] = analysisSrc +
                        (string.IsNullOrEmpty(Environment.GetEnvironmentVariable("PYTHONPATH"))
                            ? ""
                            : Path.PathSeparator + Environment.GetEnvironmentVariable("PYTHONPATH"));
                using (var p = Process.Start(psi))
                {
                    if (p == null) return;
                    p.WaitForExit(15000);
                    if (p.ExitCode == 0)
                        Console.WriteLine($"[PROGRESS] Environment captured beside {logPath}");
                }
            }
            catch
            {
                // Optional sidecar; ignore failures
            }
        }

        private static void TestOnData(ITestDataDescription testDataDescription, int repetitions,
            List<ISerDeser> serializers, LogStorage logStorage, List<Error> errors,
            int instanceCount = 1, string typeConfigHash = "")
        {
            // Untimed: Initialize + PrepareData once per fixture (not inside Stopwatch).
            var prepareFailed = new Dictionary<string, bool>();
            foreach (var serializer in serializers)
            {
                if (!serializer.Supports(testDataDescription.Name))
                    continue;
                Console.WriteLine($"[DEBUG] Initializing {serializer.Name}");
                try
                {
                    serializer.Initialize(testDataDescription.DataType, testDataDescription.SecondaryDataTypes);
                    serializer.PrepareData(testDataDescription.Data);
                }
                catch (Exception ex)
                {
                    prepareFailed[serializer.Name] = true;
                    var error = new Error
                    {
                        StringOrStream = "prepare",
                        TestDataName = testDataDescription.Name,
                        SerializerName = serializer.Name,
                        Run = 1,
                        Repetition = 0,
                        ErrorText = $"PrepareData: {ex.GetType().Name}: {ex.Message}",
                    };
                    error.TryAddTo(errors);
                    Console.WriteLine($"[ERROR] {serializer.Name} prepare: {ex.GetType().Name}: {ex.Message}");
                }
            }

            TestsOnRepetition(testDataDescription, false, repetitions, serializers, logStorage, errors,
                instanceCount, typeConfigHash, prepareFailed);
            TestsOnRepetition(testDataDescription, true, repetitions, serializers, logStorage, errors,
                instanceCount, typeConfigHash, prepareFailed);
        }

        // Shared across stream trials in this process; keyed per serializer (B-1 interleaving).
        private static readonly Dictionary<string, int> StreamCapFloorBySer = new Dictionary<string, int>();
        private static int _globalRunOrder;
        private static bool _recordRunOrder = true;
        private static string _scheduleStrategy = "block_shuffle";
        private static long _baseSeed = 42;

        public static void TestsOnRepetition(ITestDataDescription testDataDescription, bool streaming, int repetitions,
            List<ISerDeser> serializers, LogStorage logStorage, List<Error> errors,
            int instanceCount = 1, string typeConfigHash = "",
            Dictionary<string, bool> prepareFailed = null)
        {
            var wasError = new Dictionary<string, bool>();
            if (prepareFailed != null)
            {
                foreach (var kv in prepareFailed)
                    wasError[kv.Key] = true;
            }
            var original = testDataDescription;
            var modeLabel = streaming ? "Stream" : "string";
            var strategy = _scheduleStrategy;

            for (var i = 0; i < repetitions; i++)
            {
                List<ISerDeser> ordered;
                if (strategy == "none")
                {
                    ordered = new List<ISerDeser>(serializers);
                }
                else
                {
                    var eligible = new List<ISerDeser>();
                    foreach (var s in serializers)
                    {
                        if (wasError.ContainsKey(s.Name)) continue;
                        if (!s.Supports(original.Name)) continue;
                        eligible.Add(s);
                    }
                    var seed = Schedule.DeriveScheduleSeed(
                        _baseSeed, original.Name, instanceCount < 1 ? 1 : instanceCount,
                        typeConfigHash ?? "", modeLabel, i);
                    ordered = Schedule.FisherYates(eligible, seed);
                }

                for (var pos = 0; pos < ordered.Count; pos++)
                {
                    var serializer = ordered[pos];
                    if (wasError.ContainsKey(serializer.Name)) continue;
                    if (!serializer.Supports(original.Name)) continue;

                    var log = new Log
                    {
                        Run = 1,
                        TestDataName = original.Name,
                        Repetitions = repetitions,
                        RepetitionIndex = i,
                        StringOrStream = modeLabel,
                        DataTypeInstanceCount = instanceCount < 1 ? 1 : instanceCount,
                        TypeConfigHash = typeConfigHash ?? "",
                    };
                    if (_recordRunOrder)
                    {
                        log.RunOrder = _globalRunOrder;
                        log.SchedulePosition = pos;
                    }
                    SingleTest(serializer, original, errors, streaming, log, logStorage, out bool isRepeatedError);
                    if (isRepeatedError)
                    {
                        wasError[serializer.Name] = true;
                        continue;
                    }
                    // Written result row — advance global RunOrder (set on log before SingleTest).
                    if (_recordRunOrder)
                        _globalRunOrder++;
                }
            }
        }

        private static int GetInstanceCount(ITestDataDescription d)
        {
            if (d is TestData.V2.RunCellDescription cell)
                return cell.InstanceCount;
            return 1;
        }

        private static string GetTypeConfigHash(ITestDataDescription d)
        {
            if (d is TestData.V2.RunCellDescription cell)
                return cell.TypeConfigHash ?? "";
            return "";
        }

        // Capacity floor for stream mode (issue #59): grow floor across reps so
        // cold expansion is amortized; always use a writable expandable stream.
        // Per-serializer floors under block_shuffle so one codec does not amortize
        // capacity growth for others.

        private static void SingleTest(ISerDeser serializer, ITestDataDescription original, List<Error> errors,
            bool streaming, Log log, LogStorage logStorage, out bool isRepeatedError)
        {
            isRepeatedError = false;
            string serializedString = null;
            MemoryStream serializedStream = null;
            if (streaming)
            {
                if (!StreamCapFloorBySer.TryGetValue(serializer.Name, out var floor) || floor < 64 * 1024)
                    floor = 64 * 1024;
                StreamCapFloorBySer[serializer.Name] = floor;
                serializedStream = new MemoryStream(floor);
            }
            object processed;
            log.SerializerName = serializer.Name;
            log.SerializerVersion = serializer.Version ?? "";

            var serSuccessful = false;
            var error = new Error
            {
                StringOrStream = log.StringOrStream,
                TestDataName = log.TestDataName,
                SerializerName = log.SerializerName,
                Run = log.Run,
                Repetition = log.RepetitionIndex
            };
            try
            {
                var sw = Stopwatch.StartNew();
                if (streaming)
                {
                    serializer.Serialize(original.Data, serializedStream);
                    log.Size = (int) serializedStream.Length;
                    var floor = StreamCapFloorBySer[serializer.Name];
                    if (serializedStream.Capacity > floor)
                        StreamCapFloorBySer[serializer.Name] = serializedStream.Capacity;
                }
                else
                {
                    serializedString = serializer.Serialize(original.Data);
                    log.Size = serializedString.Length;
                }
                serSuccessful = true;
                // Nanoseconds from high-resolution Stopwatch ticks (not TimeSpan.TotalNanoseconds,
                // which quantizes to 100 ns and loses sub-tick precision on many platforms).
                log.TimeSer = ElapsedNanoseconds(sw);
                // KeepAlive: prevent JIT from DCE'ing timed work (issue #59).
                if (streaming)
                    GC.KeepAlive(serializedStream);
                else
                    GC.KeepAlive(serializedString);

                processed = streaming
                    ? serializer.Deserialize(serializedStream)
                    : serializer.Deserialize(serializedString);
                log.TimeDeser = ElapsedNanoseconds(sw) - log.TimeSer;
                sw.Stop();
                GC.KeepAlive(processed);
                // Untimed domain conversion (annotated/KeyTuple → suite POCO).
                processed = serializer.ToDomain(processed);
            }
            catch (Exception ex)
            {
                {
                    var parts = new System.Collections.Generic.List<string>();
                    for (var e = ex; e != null; e = e.InnerException)
                        parts.Add(e.GetType().Name + ": " + e.Message);
                    error.ErrorText = (serSuccessful ? "Deserialization" : "Serialization") + " " + string.Join(" || ", parts);
                }
                isRepeatedError = !error.TryAddTo(errors);
                return;
            }

            string errorText;
            if (Comparer.Compare(original.Data, processed, out errorText, log, false))
            {
                logStorage.Write(log);
            }
            else
            {
                error.ErrorText = errorText;
                isRepeatedError = !error.TryAddTo(errors);
            }
        }

        /// <summary>
        /// Convert <see cref="Stopwatch"/> elapsed time to whole nanoseconds using
        /// <see cref="Stopwatch.Frequency"/> so resolution is not limited to TimeSpan's 100 ns units.
        /// </summary>
        private static long ElapsedNanoseconds(Stopwatch sw) =>
            (long)((double)sw.ElapsedTicks * 1_000_000_000.0 / Stopwatch.Frequency);
    }
}
