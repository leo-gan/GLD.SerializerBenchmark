using System;
using System.IO;
using Hyperion;

namespace GLD.SerializerBenchmark.Serializers
{
    // Hyperion
    internal class HyperionSerializerSer : SerDeser
    {
        private readonly Serializer _serializer = new Serializer(new SerializerOptions(preserveObjectReferences: true));

        public override string Name => "Hyperion";

        public override byte[] SerializeBytes(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(serializable, ms);
                return ms.ToArray();
            }
        }

        public override object DeserializeBytes(byte[] serialized)
        {
            var b = serialized;
            using (var ms = new MemoryStream(b))
            {
                return _serializer.Deserialize<object>(ms);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _serializer.Serialize(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize<object>(inputStream);
        }
    }
}
