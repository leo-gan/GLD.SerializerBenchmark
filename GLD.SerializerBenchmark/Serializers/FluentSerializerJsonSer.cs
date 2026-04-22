using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // FluentSerializer.Json
    internal class FluentSerializerJsonSer : SerDeser
    {
        public override string Name => "FluentSerializer";

        public override bool Supports(string testDataName)
        {
            // FluentSerializer requires profile mappings for each type
            return false;
        }

        public override string Serialize(object serializable) {
            // FluentSerializer requires mappings
            return ""; 
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
