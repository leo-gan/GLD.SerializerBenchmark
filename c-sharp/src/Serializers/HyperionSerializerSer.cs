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

        public override bool Supports(string testDataName)
        {
            // Hyperion can crash with StackOverflow/SegFault on very deep circular references like ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(serializable, ms);
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
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
