using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class NetSerializerSer : SerDeser
    {
        private NetSerializer.Serializer _serializer;

        public override string Name => "NetSerializer";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type type, List<Type> secondaryTypes)
        {
            base.Initialize(type, secondaryTypes);
            var types = new List<Type> { type };
            if (secondaryTypes != null) types.AddRange(secondaryTypes);
            // Nested collection element types
            types.AddRange(new[]
            {
                typeof(List<>).MakeGenericType(type),
            });
            // Common V2 nested
            types.Add(typeof(GLD.SerializerBenchmark.TestData.V2.DocumentMeta));
            types.Add(typeof(GLD.SerializerBenchmark.TestData.V2.DocumentItem));
            types.Add(typeof(GLD.SerializerBenchmark.TestData.V2.EventAttr));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.DocumentItem>));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.EventAttr>));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.Message>));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.Document>));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.Telemetry>));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.Strings>));
            types.Add(typeof(List<GLD.SerializerBenchmark.TestData.V2.Event>));
            types.Add(typeof(List<string>));
            types.Add(typeof(List<double>));
            try
            {
                _serializer = new NetSerializer.Serializer(types.Distinct());
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[WARN] NetSerializer init: {ex.Message}");
                _serializer = null;
            }
        }

        public override string Serialize(object serializable)
        {
            if (_serializer == null) throw new InvalidOperationException("NetSerializer not initialized");
            using var ms = new MemoryStream();
            _serializer.Serialize(ms, serializable);
            return Convert.ToBase64String(ms.ToArray());
        }

        public override object Deserialize(string serialized)
        {
            if (_serializer == null) throw new InvalidOperationException("NetSerializer not initialized");
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Deserialize(ms);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            if (_serializer == null) throw new InvalidOperationException("NetSerializer not initialized");
            _serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            if (_serializer == null) throw new InvalidOperationException("NetSerializer not initialized");
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }
    }
}
