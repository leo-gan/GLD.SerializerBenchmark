using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // Apex.Serialization
    internal class ApexSerializerSer : SerDeser
    {
        private static bool IsEnabled = true; 
        private static readonly Apex.Serialization.IBinary _serializer = IsEnabled ? Apex.Serialization.Binary.Create() : null;

        public override string Name => "Apex.Serialization";

        public override bool Supports(string testDataName)
        {
            // Apex.Serialization crashes on circular references (ObjectGraph)
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable) {
            if (!IsEnabled) return "";
            using var ms = new MemoryStream();
            _serializer.Write(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized) {
            if (!IsEnabled) return null;
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Read<object>(ms);
        }

        public override void Serialize(object serializable, Stream outputStream) {
            if (!IsEnabled) return;
            _serializer.Write(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream) {
            if (!IsEnabled) return null;
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Read<object>(inputStream);
        }
    }
}
