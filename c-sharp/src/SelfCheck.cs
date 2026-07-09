using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark
{
    /// <summary>Lightweight in-process checks (run: app selfcheck).</summary>
    internal static class SelfCheck
    {
        public static int Run()
        {
            var fixtures = new List<ITestDataDescription>
            {
                new PersonDescription(),
                new IntDescription(),
                new TelemetryDescription(),
                new SimpleObjectDescription(),
                new StringArrayDescription(),
                new EDI_X12_835Description(),
                new ObjectGraphDescription()
            };

            int failures = 0;

            // ZeroFormatter must support every fixture.
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

            // SpanJson/Utf8Json must not throw after Initialize and roundtrip Person.
            foreach (ISerDeser ser in new ISerDeser[] { new SpanJsonSerializerSer(), new Utf8JsonSerializerSer(), new JilSerializer() })
            {
                var fx = fixtures.First(f => f.Name == "Person");
                try
                {
                    ser.Initialize(fx.DataType, fx.SecondaryDataTypes);
                    ser.PrepareData(fx.Data);
                    var s = ser.Serialize(fx.Data);
                    var d = ser.ToDomain(ser.Deserialize(s));
                    if (!Comparer.Compare(fx.Data, d, out var err, new Log { Size = s?.Length ?? 1 }, false))
                    {
                        Console.WriteLine($"FAIL {ser.Name} Person: {err}");
                        failures++;
                    }
                    else
                        Console.WriteLine($"OK   {ser.Name} Person");
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
