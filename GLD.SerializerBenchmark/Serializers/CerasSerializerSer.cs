using System;
using System.IO;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // Ceras
    internal class CerasSerializerSer : SerDeser
    {
        private static readonly Lazy<Ceras.CerasSerializer> _serializer = new Lazy<Ceras.CerasSerializer>(() => new Ceras.CerasSerializer());
        public override string Name => "Ceras";
        public override string Serialize(object serializable) => Convert.ToBase64String(_serializer.Value.Serialize(serializable));

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            // Use reflection to call generic Deserialize with _primaryType
            var method = typeof(Ceras.CerasSerializer).GetMethod("Deserialize", new[] { typeof(byte[]), typeof(byte).MakeByRefType() });
            var genericMethod = method.MakeGenericMethod(_primaryType);
            byte protocolMembers = 0;
            return genericMethod.Invoke(_serializer.Value, new object[] { bytes, protocolMembers });
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = _serializer.Value.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            var bytes = ms.ToArray();
            // Use reflection to call generic Deserialize with _primaryType
            var method = typeof(Ceras.CerasSerializer).GetMethod("Deserialize", new[] { typeof(byte[]), typeof(byte).MakeByRefType() });
            var genericMethod = method.MakeGenericMethod(_primaryType);
            byte protocolMembers = 0;
            return genericMethod.Invoke(_serializer.Value, new object[] { bytes, protocolMembers });
        }
    }
}
