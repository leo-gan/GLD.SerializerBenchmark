using System;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using GLD.SerializerBenchmark.TestData.V2;
using GLD.SerializerBenchmark.TestData.V2.Maps;

namespace GLD.SerializerBenchmark
{
    /// <summary>Lightweight in-process checks (run: app selfcheck) — Data Model v2 only.</summary>
    internal static class SelfCheck
    {
        public static int Run()
        {
            // Architecture: Serializers/* must not import suite domain types.
            var serDir = System.IO.Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "Serializers");
            if (!System.IO.Directory.Exists(serDir))
                serDir = System.IO.Path.GetFullPath(System.IO.Path.Combine(System.IO.Directory.GetCurrentDirectory(), "src", "Serializers"));
            if (System.IO.Directory.Exists(serDir))
            {
                foreach (var file in System.IO.Directory.EnumerateFiles(serDir, "*.cs", System.IO.SearchOption.AllDirectories))
                {
                    var name = System.IO.Path.GetFileName(file);
                    if (name is "DomainNativeMap.cs") continue; // interface docs only
                    var text = System.IO.File.ReadAllText(file);
                    if (text.Contains("using GLD.SerializerBenchmark.TestData")
                        || text.Contains("TestData.V2.Message")
                        || text.Contains("TestData.V2.Telemetry"))
                    {
                        Console.WriteLine($"FAIL isolation: {name} references suite TestData");
                        return 1;
                    }
                }
                Console.WriteLine("OK   serializer isolation (no suite TestData imports)");
            }

            var fixtures = new List<ITestDataDescription>
            {
                new MessageDescription(),
                new DocumentDescription(),
                new TelemetryV2Description(),
                new StringsDescription(),
                new EventDescription(),
            };

            int failures = 0;

            var zf = new ZeroFormatterSerializerSer(new ZeroFormatterDomainMap());
            foreach (var fx in fixtures)
            {
                if (!zf.Supports(fx.Name))
                {
                    Console.WriteLine($"FAIL ZeroFormatter.Supports({fx.Name})");
                    failures++;
                    continue;
                }
                try
                {
                    zf.Initialize(fx.DataType, fx.SecondaryDataTypes);
                    zf.PrepareData(fx.Data);
                    var s = zf.Serialize(fx.Data);
                    var d = zf.ToDomain(zf.Deserialize(s));
                    if (!Comparer.Compare(fx.Data, d, out var err, new Log { Size = s?.Length ?? 1 }, false))
                    {
                        Console.WriteLine($"FAIL ZeroFormatter roundtrip {fx.Name}: {err}");
                        failures++;
                    }
                    else
                        Console.WriteLine($"OK   ZeroFormatter {fx.Name}");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"FAIL ZeroFormatter {fx.Name}: {ex.GetType().Name}: {ex.Message}");
                    failures++;
                }
            }

            var ion = new AmazonIonDotnetSerializerSer();
            foreach (var fx in fixtures)
            {
                try
                {
                    ion.Initialize(fx.DataType, fx.SecondaryDataTypes);
                    ion.PrepareData(fx.Data);
                    var s = ion.Serialize(fx.Data);
                    var d = ion.ToDomain(ion.Deserialize(s));
                    if (!Comparer.Compare(fx.Data, d, out var err, new Log { Size = s?.Length ?? 1 }, false))
                    {
                        Console.WriteLine($"FAIL Amazon.IonDotnet bytes {fx.Name}: {err}");
                        failures++;
                    }
                    else
                    {
                        using var ms = new System.IO.MemoryStream();
                        ion.Serialize(fx.Data, ms);
                        var d2 = ion.ToDomain(ion.Deserialize(ms));
                        if (!Comparer.Compare(fx.Data, d2, out var err2, new Log { Size = (int)ms.Length }, false))
                        {
                            Console.WriteLine($"FAIL Amazon.IonDotnet stream {fx.Name}: {err2}");
                            failures++;
                        }
                        else
                            Console.WriteLine($"OK   Amazon.IonDotnet {fx.Name}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"FAIL Amazon.IonDotnet {fx.Name}: {ex.GetType().Name}: {ex.Message}");
                    failures++;
                }
            }

            // SpanJson/Utf8Json on a simple v2 message fixture
            foreach (ISerDeser ser in new ISerDeser[] { new SpanJsonSerializerSer(), new Utf8JsonSerializerSer() })
            {
                var fx = fixtures.First(f => f.Name == "message");
                try
                {
                    ser.Initialize(fx.DataType, fx.SecondaryDataTypes);
                    ser.PrepareData(fx.Data);
                    var s = ser.Serialize(fx.Data);
                    var d = ser.ToDomain(ser.Deserialize(s));
                    if (!Comparer.Compare(fx.Data, d, out var err, new Log { Size = s?.Length ?? 1 }, false))
                    {
                        Console.WriteLine($"FAIL {ser.Name} message: {err}");
                        failures++;
                    }
                    else
                        Console.WriteLine($"OK   {ser.Name} message");
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"FAIL {ser.Name}: {ex}");
                    failures++;
                }
            }

            failures += Columnar();

            Console.WriteLine(failures == 0 ? "SELFCHECK PASS" : $"SELFCHECK FAIL ({failures})");
            return failures == 0 ? 0 : 1;
        }

        static int Columnar()
        {
            int failures = 0;
            var a = Generator.MakeOne("table", default, 42, 0);
            var b = Generator.MakeOne("table", default, 42, 0);
            if (!Comparer.Compare(a, b, out var derr, new Log { Size = 1 }, false))
            {
                Console.WriteLine("FAIL table determinism: " + derr);
                failures++;
            }
            else
                Console.WriteLine("OK   table determinism");

            var (batch, _, _) = Generator.BuildPayload("table", default, 40, 42);
            var strs = new HashSet<string>();
            foreach (var row in ((BatchTable)batch).Items)
                strs.Add(row.FStr0);
            if (strs.Count >= 40)
            {
                Console.WriteLine($"FAIL table 40-row duplication set={strs.Count}");
                failures++;
            }
            else
                Console.WriteLine($"OK   table 40-row duplication set={strs.Count}");

            var sig = (Signal)Generator.MakeOne("signal", default, 42, 0);
            var (sigBatch, _, _) = Generator.BuildPayload("signal", default, 40, 7);
            var padBad = sig.Legs.Any(l => l.LegPad != 0)
                || ((BatchSignal)sigBatch).Items.Any(s => s.Legs.Any(l => l.LegPad != 0));
            if (padBad || sig.Legs.Count == 0)
            {
                Console.WriteLine("FAIL signal leg_pad");
                failures++;
            }
            else
                Console.WriteLine("OK   signal leg_pad 0");

            var allow = "arrow-ipc,parquet,parquet-uncompressed,System.Text.Json,Google.Protobuf,FlatSharp,Apache.Avro";
            var all = Program.CreateSerializers();
            var selected = Program.SelectSerializers(all, allow);
            var selectedNames = string.Join(",", selected.Select(s => s.Name));
            Console.WriteLine("SELECTED " + selectedNames);
            var expect = new[]
            {
                "FlatSharp", "Google.Protobuf", "Apache.Avro", "System.Text.Json",
                "arrow-ipc", "parquet", "parquet-uncompressed",
            };
            if (selected.Count != expect.Length || selected.Select(s => s.Name).Zip(expect).Any(p => p.First != p.Second))
            {
                Console.WriteLine("FAIL allow-list selection");
                failures++;
            }
            else
                Console.WriteLine("OK   allow-list exact");

            // Trailing comma forces exact-name mode. "json" alone stays a substring.
            var jsonExact = Program.SelectSerializers(all, "json,");
            var protoExact = Program.SelectSerializers(all, "protobuf,");
            Console.WriteLine("COMMA json -> " + (jsonExact.Count == 0 ? "(none)" : string.Join(",", jsonExact.Select(s => s.Name))));
            Console.WriteLine("COMMA protobuf -> " + string.Join(",", protoExact.Select(s => s.Name)));
            if (jsonExact.Count != 0)
            {
                Console.WriteLine("FAIL comma json selected a serializer");
                failures++;
            }
            if (protoExact.Count != 1 || protoExact[0].Name != "ProtoBuf")
            {
                Console.WriteLine("FAIL comma protobuf should select only ProtoBuf");
                failures++;
            }
            var jsonSub = Program.SelectSerializers(all, "Json");
            if (jsonSub.Count < 2)
            {
                Console.WriteLine("FAIL substring Json should keep matching more than one name");
                failures++;
            }
            else
                Console.WriteLine("OK   substring Json count=" + jsonSub.Count);

            foreach (var n in new[] { 1, 100 })
            {
                foreach (var typeId in new[] { "table", "table_project", "nested_table", "signal" })
                {
                    foreach (var ser in selected)
                    {
                        if (!RoundTrip(ser, typeId, n, stream: false, out var err))
                        {
                            Console.WriteLine($"FAIL {ser.Name} {typeId} N={n} bytes: {err}");
                            failures++;
                        }
                        else if (n == 1 && !RoundTrip(ser, typeId, n, stream: true, out var err2))
                        {
                            Console.WriteLine($"FAIL {ser.Name} {typeId} N={n} stream: {err2}");
                            failures++;
                        }
                        else
                            Console.WriteLine($"OK   {ser.Name} {typeId} N={n}");
                    }
                }
            }

            var (rows, dt, sec) = Generator.BuildPayload("table", default, 100, 42);
            var snappy = new ParquetColumnarSerializerSer(uncompressed: false);
            var raw = new ParquetColumnarSerializerSer(uncompressed: true);
            snappy.BindFixture("table");
            raw.BindFixture("table");
            snappy.Initialize(dt, sec);
            raw.Initialize(dt, sec);
            snappy.PrepareData(rows);
            raw.PrepareData(rows);
            var left = snappy.Serialize(rows);
            var right = raw.Serialize(rows);
            if (left == right)
            {
                Console.WriteLine("FAIL parquet and parquet-uncompressed bytes match at N=100");
                failures++;
            }
            else
                Console.WriteLine($"OK   parquet compression differs snappy={left.Length} raw={right.Length}");

            return failures;
        }

        static bool RoundTrip(ISerDeser ser, string typeId, int n, bool stream, out string err)
        {
            var (data, dt, sec) = Generator.BuildPayload(typeId, default, n, 42);
            ser.BindFixture(typeId);
            ser.Initialize(dt, sec);
            ser.PrepareData(data);
            object back;
            int size;
            if (stream)
            {
                using var ms = new System.IO.MemoryStream();
                ser.Serialize(data, ms);
                size = (int)ms.Length;
                if (size == 0)
                {
                    err = "empty stream";
                    return false;
                }
                back = ser.ToDomain(ser.Deserialize(ms));
            }
            else
            {
                var s = ser.Serialize(data);
                size = s?.Length ?? 0;
                back = ser.ToDomain(ser.Deserialize(s));
            }
            object expected = data;
            if (typeId == "table_project")
            {
                List<double> col;
                if (data is TableRow row)
                    col = new List<double> { row.FFloat0 };
                else
                    col = ((BatchTable)data).Items.Select(r => r.FFloat0).ToList();
                if (back is not System.Collections.IList list || list.Count != n)
                {
                    err = "table_project length " + ((back as System.Collections.IList)?.Count.ToString() ?? "null") + " != " + n;
                    return false;
                }
                expected = col;
            }
            return Comparer.Compare(expected, back, out err, new Log { Size = size == 0 ? 0 : size }, false);
        }

        /// <summary>Deserialize times for arrow-ipc and parquet, table vs table_project, N=10000.</summary>
        public static int ColumnTiming()
        {
            const int n = 10000;
            const int reps = 5;
            foreach (var typeId in new[] { "table", "table_project" })
            {
                var (data, dt, sec) = Generator.BuildPayload(typeId, default, n, 42);
                foreach (ISerDeser ser in new ISerDeser[]
                         {
                             new ArrowIpcSerializerSer(),
                             new ParquetColumnarSerializerSer(uncompressed: false),
                         })
                {
                    ser.BindFixture(typeId);
                    ser.Initialize(dt, sec);
                    ser.PrepareData(data);
                    var payload = ser.Serialize(data);
                    GC.KeepAlive(ser.Deserialize(payload));
                    var times = new long[reps];
                    for (int i = 0; i < reps; i++)
                    {
                        var sw = System.Diagnostics.Stopwatch.StartNew();
                        var back = ser.Deserialize(payload);
                        times[i] = (long)(sw.ElapsedTicks * 1_000_000_000.0 / System.Diagnostics.Stopwatch.Frequency);
                        GC.KeepAlive(back);
                    }
                    Array.Sort(times);
                    Console.WriteLine(
                        $"TIMING {ser.Name} {typeId} N={n} deser_ns {string.Join(",", times)} median={times[reps / 2]}");
                }
            }
            return 0;
        }
    }
}
