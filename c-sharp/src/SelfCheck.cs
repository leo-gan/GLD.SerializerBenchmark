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

            Console.WriteLine(failures == 0 ? "SELFCHECK PASS" : $"SELFCHECK FAIL ({failures})");
            return failures == 0 ? 0 : 1;
        }
    }
}
