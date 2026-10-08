using System.IO;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using GLD.SerializerBenchmark.TestData.V2.Maps;

namespace GLD.SerializerBenchmark
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            if (args.Length > 0 && args[0].ToLower() == "export-data")
            {
                var outputDir = args.Length > 1 ? args[1] : "../data";
                Exporter.ExportData(outputDir);
                return;
            }

            if (args.Length > 0 && args[0].Equals("selfcheck", System.StringComparison.OrdinalIgnoreCase))
            {
                System.Environment.Exit(SelfCheck.Run());
                return;
            }

            if (args.Length > 0 && args[0].Equals("compliance", System.StringComparison.OrdinalIgnoreCase))
            {
                System.Environment.Exit(Compliance.Run(args.Skip(1).ToArray()));
                return;
            }

            if (args.Length > 0 && args[0].Equals("column-timing", System.StringComparison.OrdinalIgnoreCase))
            {
                System.Environment.Exit(SelfCheck.ColumnTiming());
                return;
            }

            var repetitions = args.Length > 0 ? int.Parse(args[0]) : 100;
            var serializerFilter = args.Length > 1 ? args[1] : null;
            var testDataFilter = args.Length > 2 ? args[2] : null;

            // Expand run-config cells (type_id × data_type_instance_count).
            var seed = 42;
            var seedEnv = System.Environment.GetEnvironmentVariable("BENCHMARK_SEED");
            if (!string.IsNullOrEmpty(seedEnv) && int.TryParse(seedEnv, out var seedParsed))
                seed = seedParsed;

            List<ITestDataDescription> allTestDataDescriptions;
            try
            {
                var cells = GLD.SerializerBenchmark.TestData.V2.RunCells.Load(
                    runConfigPath: null, seed: seed, dataFilter: testDataFilter);
                allTestDataDescriptions = new List<ITestDataDescription>(cells);
                System.Console.WriteLine(
                    $"[PROGRESS] Run-config cells: {cells.Count} (seed={seed})");
            }
            catch (System.Exception ex)
            {
                System.Console.WriteLine(
                    $"[WARN] resolve_run_config unavailable ({ex.Message}); falling back to N=1 fixtures");
                allTestDataDescriptions = new List<ITestDataDescription>
                {
                    new GLD.SerializerBenchmark.TestData.V2.MessageDescription(seed),
                    new GLD.SerializerBenchmark.TestData.V2.DocumentDescription(seed),
                    new GLD.SerializerBenchmark.TestData.V2.TelemetryV2Description(seed),
                    new GLD.SerializerBenchmark.TestData.V2.StringsDescription(seed),
                    new GLD.SerializerBenchmark.TestData.V2.EventDescription(seed),
                };
            }

            var allSerializers = CreateSerializers();

            var testDataDescriptions = allTestDataDescriptions
                .Where(td => string.IsNullOrEmpty(testDataFilter) || td.Name.Contains(testDataFilter, System.StringComparison.OrdinalIgnoreCase))
                .ToList();

            var serializers = SelectSerializers(allSerializers, serializerFilter);

            if (testDataDescriptions.Count == 0 || serializers.Count == 0)
            {
                System.Console.WriteLine("No test data or serializers matched the filters.");
                return;
            }

            System.Console.WriteLine("[PROGRESS] Serializers: " + string.Join(",", serializers.Select(s => s.Name)));

            Tester.Tests(serializers, testDataDescriptions, repetitions);
        }

        internal static List<ISerDeser> CreateSerializers() => new List<ISerDeser>
        {
                new BinarySerializer(),
                new BondCompactSerializer(),
                new BondFastSerializer(),
                new BondJsonSerializer(),
                new DataContractSerializerSerializer(),
                new DataContractJsonSer(),
                new XmlSerializerSer(),
                new FastJsonSerializer(),
                new JsonNetHelperSerializer(),
                new JsonNetSerializer(),
                new FsPicklerBinarySerializer(),
                new FsPicklerJsonSerializer(),
                new NetJSONSer(),
                new ProtoBufSerializer(),
                new LightProtoSerializer(),
                new SharpSerializer(),
                new ServiceStackJsonSerializer(),
                new ServiceStackTypeSerializer(),
                new CerasSerializerSer(),
                new CsvHelperSerializerSer(new CsvHelperDomainMap()),
                new FlatSharpSerializerSer(new FlatSharpDomainMap()),
                new GoogleProtobufSerializerSer(new GoogleProtobufDomainMap()),
                new ApacheAvroSerializerSer(),
                new HyperionSerializerSer(),
                new NetSerializerSer(),
                new SpanJsonSerializerSer(),
                new Utf8JsonSerializerSer(),
                new YamlDotNetSerializerSer(),
                new YAXLibSerializerSer(),
                new ZeroFormatterSerializerSer(new ZeroFormatterDomainMap()),
                new BinaryPackSerializerSer(),
                new MemoryPackSerializerSer(),
                new MessagePackCSharpSerializerSer(),
                new AmazonIonDotnetSerializerSer(),
                new NerdbankMessagePackSerializerSer(),
                new SharpYamlSerializerSer(),
                new GroBufSerializerSer(),
                new ExtendedXmlSerializerSer(),
                new MigrantSerializerSer(),
                new SystemTextJsonSerializerSer(),
                new ShapeShiftCborSerializerSer(),
                new ShapeShiftJsonSerializerSer(),
                new ShapeShiftMsgPackSerializerSer(),
                new ShapeShiftProtobufSerializerSer(),
                new ShapeShiftTamlSerializerSer(),
                new ShapeShiftTomlSerializerSer(),
                new ShapeShiftYamlSerializerSer(),
                new ArrowIpcSerializerSer(),
                new ParquetColumnarSerializerSer(uncompressed: false),
                new ParquetColumnarSerializerSer(uncompressed: true),
        };

        /// <summary>
        /// Empty selects all. A comma-separated filter is case-insensitive exact names.
        /// No comma keeps substring matching.
        /// </summary>
        internal static List<ISerDeser> SelectSerializers(List<ISerDeser> all, string filter)
        {
            if (string.IsNullOrEmpty(filter))
                return all;
            if (filter.IndexOf(',') >= 0)
            {
                var wanted = new HashSet<string>(
                    filter.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries),
                    StringComparer.OrdinalIgnoreCase);
                return all.Where(s => wanted.Contains(s.Name)).ToList();
            }
            return all.Where(s => s.Name.Contains(filter, System.StringComparison.OrdinalIgnoreCase)).ToList();
        }
    }
}
