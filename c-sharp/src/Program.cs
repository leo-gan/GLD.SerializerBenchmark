using System.IO;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using GLD.SerializerBenchmark.TestData;

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

            var repetitions = args.Length > 0 ? int.Parse(args[0]) : 100;
            var serializerFilter = args.Length > 1 ? args[1] : null;
            var testDataFilter = args.Length > 2 ? args[2] : null;

            // Data Model v2 type_ids; payloads use existing POCO proxies so all serializers run.
            var allTestDataDescriptions = new List<ITestDataDescription>
            {
                new GLD.SerializerBenchmark.TestData.V2.MessageDescription(),
                new GLD.SerializerBenchmark.TestData.V2.DocumentDescription(),
                new GLD.SerializerBenchmark.TestData.V2.TelemetryV2Description(),
                new GLD.SerializerBenchmark.TestData.V2.StringsDescription(),
                new GLD.SerializerBenchmark.TestData.V2.EventDescription(),
            };

            var allSerializers = new List<ISerDeser>
            {
                new BinarySerializer(),
                new BondCompactSerializer(), 
                new BondFastSerializer(), 
                new BondJsonSerializer(), 
                new DataContractSerializerSerializer(),
                new DataContractJsonSer(),
                new XmlSerializerSer(),
                new FastJsonSerializer(), 
                new JilSerializer(), 
                new JsonNetHelperSerializer(),
                new JsonNetSerializer(),
                new FsPicklerBinarySerializer(),
                new FsPicklerJsonSerializer(),
                new NetJSONSer(), 
                new ProtoBufSerializer(),
                new SharpSerializer(), 
                new ServiceStackJsonSerializer(), 
                new ServiceStackTypeSerializer(), 
                new CerasSerializerSer(),
                new CsvHelperSerializerSer(),
                new FlatSharpSerializerSer(),
                new FluentSerializerJsonSer(),
                new GoogleProtobufSerializerSer(),
                new HyperionSerializerSer(),
                new NetSerializerSer(),
                new SpanJsonSerializerSer(),
                new Utf8JsonSerializerSer(),
                new YamlDotNetSerializerSer(),
                new YAXLibSerializerSer(),
                new ZeroFormatterSerializerSer(),
                new BinaryPackSerializerSer(),
                new MemoryPackSerializerSer(),
                new SharpYamlSerializerSer(),
                new GroBufSerializerSer(),
                new ExtendedXmlSerializerSer(),
                new MigrantSerializerSer(),
                new ApexSerializerSer() // Moved to end
            };

            var testDataDescriptions = allTestDataDescriptions
                .Where(td => string.IsNullOrEmpty(testDataFilter) || td.Name.Contains(testDataFilter, System.StringComparison.OrdinalIgnoreCase))
                .ToList();

            var serializers = allSerializers
                .Where(s => string.IsNullOrEmpty(serializerFilter) || s.Name.Contains(serializerFilter, System.StringComparison.OrdinalIgnoreCase))
                .ToList();

            if (testDataDescriptions.Count == 0 || serializers.Count == 0)
            {
                System.Console.WriteLine("No test data or serializers matched the filters.");
                return;
            }

            Tester.Tests(serializers, testDataDescriptions, repetitions);
        }
    }
}