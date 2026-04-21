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
            var repetitions = args.Length > 0 ? int.Parse(args[0]) : 100;
            var serializerFilter = args.Length > 1 ? args[1] : null;
            var testDataFilter = args.Length > 2 ? args[2] : null;

            var allTestDataDescriptions = new List<ITestDataDescription>
            {
                new PersonDescription(),
                new IntDescription(),
                new TelemetryDescription(),
                new SimpleObjectDescription(),
                new StringArrayDescription(),
                new EDI_X12_835Description(),
                new ObjectGraphDescription()
            };

            var allSerializers = new List<ISerDeser>
            {
                new BinarySerializer(),
                new BondCompactSerializer(), 
                new BondFastSerializer(), 
                new BondJsonSerializer(), 
                new DataContractSerializerSerializer(),
                new DataContractJsonSer(),
                new JavaScriptSerializerSer(), 
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