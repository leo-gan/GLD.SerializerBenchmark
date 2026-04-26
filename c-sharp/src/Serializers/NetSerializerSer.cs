using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // NetSerializer
    internal class NetSerializerSer : SerDeser
    {
        private NetSerializer.Serializer _serializer;

        public override string Name => "NetSerializer";

        public override void Initialize(Type type, List<Type> secondaryTypes)
        {
            base.Initialize(type, secondaryTypes);
            try
            {
                _serializer = new NetSerializer.Serializer(new[] { type });
            }
            catch
            {
                _serializer = null;
            }
        }

        public override bool Supports(string testDataName)
        {
            // NetSerializer crashes on circular references
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable) {
            if (_serializer == null) return "";
            using var ms = new MemoryStream();
            _serializer.Serialize(ms, serializable);
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized) {
            if (_serializer == null) return null;
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Deserialize(ms);
        }

        public override void Serialize(object serializable, Stream outputStream) {
            if (_serializer == null) return;
            _serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream) {
            if (_serializer == null) return null;
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }
    }
}
