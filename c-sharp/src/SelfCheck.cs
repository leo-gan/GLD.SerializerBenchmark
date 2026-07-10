using System;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using GLD.SerializerBenchmark.TestData.V2;

namespace GLD.SerializerBenchmark
{
    /// <summary>Lightweight in-process checks (run: app selfcheck) — Data Model v2 only.</summary>
    internal static class SelfCheck
    {
        public static int Run()
        {
            var fixtures = new List<ITestDataDescription>
            {
                new MessageDescription(),
                new DocumentDescription(),
                new TelemetryV2Description(),
                new StringsDescription(),
                new EventDescription(),
            };

            int failures = 0;

            var zf = new ZeroFormatterSerializerSer();
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

            // SpanJson/Utf8Json/Jil on a simple v2 message fixture
            foreach (ISerDeser ser in new ISerDeser[] { new SpanJsonSerializerSer(), new Utf8JsonSerializerSer(), new JilSerializer() })
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
