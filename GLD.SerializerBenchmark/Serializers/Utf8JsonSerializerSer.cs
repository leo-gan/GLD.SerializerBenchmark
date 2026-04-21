using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // Utf8Json
    internal class Utf8JsonSerializerSer : SerDeser
    {
        public override string Name => "Utf8Json";

        public override bool Supports(string testDataName)
        {
            // Utf8Json does not support circular references in ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable) => Utf8Json.JsonSerializer.ToJsonString(serializable);
        public override object Deserialize(string serialized) => Utf8Json.JsonSerializer.Deserialize<dynamic>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            Utf8Json.JsonSerializer.Serialize(outputStream, serializable);
        }
        public override object Deserialize(Stream inputStream) {
            return Utf8Json.JsonSerializer.Deserialize<dynamic>(inputStream);
        }
    }
}
