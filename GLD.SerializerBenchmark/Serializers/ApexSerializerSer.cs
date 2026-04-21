using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // Apex.Serialization
    internal class ApexSerializerSer : SerDeser
    {
        private static readonly Apex.Serialization.IBinary _serializer = Apex.Serialization.Binary.Create();
        public override string Name => "Apex.Serialization";
        public override string Serialize(object serializable) {
            using var ms = new MemoryStream();
            _serializer.Write(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }
        public override object Deserialize(string serialized) {
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Read<object>(ms);
        }
        public override void Serialize(object serializable, Stream outputStream) {
            _serializer.Write(serializable, outputStream);
        }
        public override object Deserialize(Stream inputStream) {
            return _serializer.Read<object>(inputStream);
        }
    }
}
