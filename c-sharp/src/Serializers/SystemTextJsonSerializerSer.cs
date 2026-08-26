using System.IO;
using System.Text.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class SystemTextJsonSerializerSer : SerDeser
    {
        private static readonly JsonSerializerOptions Options = new JsonSerializerOptions();
        private object _native;

        public override string Name => "System.Text.Json";
        public override string Version =>
            typeof(JsonSerializer).Assembly.GetName().Version?.ToString() ?? "System.Text.Json";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data) => _native = data;

        public override string Serialize(object serializable)
        {
            return JsonSerializer.Serialize(_native ?? serializable, Options);
        }

        public override object Deserialize(string serialized)
        {
            return JsonSerializer.Deserialize(serialized, _primaryType, Options);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            using var writer = new Utf8JsonWriter(outputStream);
            JsonSerializer.Serialize(writer, _native ?? serializable, Options);
            writer.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return JsonSerializer.Deserialize(inputStream, _primaryType, Options);
        }
    }
}
