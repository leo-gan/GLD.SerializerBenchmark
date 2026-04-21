using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // Hyperion
    internal class HyperionSerializerSer : SerDeser
    {
        private static readonly Hyperion.Serializer _serializer = new Hyperion.Serializer(new Hyperion.SerializerOptions());
        public override string Name => "Hyperion";
        public override string Serialize(object serializable) {
            using var ms = new MemoryStream();
            _serializer.Serialize(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }
        public override object Deserialize(string serialized) {
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Deserialize<object>(ms);
        }
        public override void Serialize(object serializable, Stream outputStream) {
            _serializer.Serialize(serializable, outputStream);
        }
        public override object Deserialize(Stream inputStream) {
            return _serializer.Deserialize<object>(inputStream);
        }
    }
}
