using System;
using System.IO;
using System.Reflection;
using Antmicro.Migrant;

namespace GLD.SerializerBenchmark.Serializers
{
    // Migrant
    internal class MigrantSerializerSer : SerDeser
    {
        private readonly Serializer _serializer;

        public MigrantSerializerSer()
        {
            _serializer = new Serializer();
        }

        public override string Name => "Migrant";

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
                // Use reflection to call generic Deserialize with _primaryType
                var method = typeof(Serializer).GetMethod("Deserialize", new[] { typeof(Stream) });
                var genericMethod = method.MakeGenericMethod(_primaryType);
                return genericMethod.Invoke(_serializer, new[] { ms });
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _serializer.Serialize(serializable, outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            // Use reflection to call generic Deserialize with _primaryType
            var method = typeof(Serializer).GetMethod("Deserialize", new[] { typeof(Stream) });
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(_serializer, new[] { inputStream });
        }
    }
}
