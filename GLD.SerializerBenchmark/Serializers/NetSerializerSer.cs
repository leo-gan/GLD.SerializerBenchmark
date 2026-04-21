using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // NetSerializer
    internal class NetSerializerSer : SerDeser
    {
        public override string Name => "NetSerializer";
        public override string Serialize(object serializable) {
            var serializer = new NetSerializer.Serializer(new[] { serializable.GetType() });
            using var ms = new MemoryStream();
            serializer.Serialize(ms, serializable);
            return Convert.ToBase64String(ms.ToArray());
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var serializer = new NetSerializer.Serializer(new[] { serializable.GetType() });
            serializer.Serialize(outputStream, serializable);
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
