using System;
using System.IO;
using System.Linq;
using GLD.SerializerBenchmark.TestData;
using ProtoBuf;

namespace GLD.SerializerBenchmark
{
    public static class Exporter
    {
        public static void ExportData(string outputDir)
        {
            if (!Directory.Exists(outputDir))
            {
                Directory.CreateDirectory(outputDir);
            }

            var descriptions = new ITestDataDescription[]
            {
                new PersonDescription(),
                new SimpleObjectDescription(),
                new StringArrayDescription(),
                new TelemetryDescription(),
                new EDI_X12_835Description()
                // ObjectGraph might cause stack overflow in standard protobuf without AsReference
            };

            foreach (var desc in descriptions)
            {
                var filePath = Path.Combine(outputDir, $"{desc.Name}.bin");
                using (var file = File.Create(filePath))
                {
                    Serializer.Serialize(file, desc.Data);
                }
                Console.WriteLine($"Exported {desc.Name} to {filePath}");
            }
        }
    }
}
