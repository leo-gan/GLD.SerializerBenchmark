using System;
using System.IO;
using GLD.SerializerBenchmark.TestData.V2;
using ProtoBuf;

namespace GLD.SerializerBenchmark
{
    public static class Exporter
    {
        public static void ExportData(string outputDir)
        {
            if (!Directory.Exists(outputDir))
                Directory.CreateDirectory(outputDir);

            var descriptions = new ITestDataDescription[]
            {
                new MessageDescription(),
                new DocumentDescription(),
                new TelemetryV2Description(),
                new StringsDescription(),
                new EventDescription(),
            };

            foreach (var desc in descriptions)
            {
                var filePath = Path.Combine(outputDir, $"{desc.Name}.bin");
                using (var file = File.Create(filePath))
                    Serializer.Serialize(file, desc.Data);
                Console.WriteLine($"Exported {desc.Name} to {filePath}");
            }
        }
    }
}
