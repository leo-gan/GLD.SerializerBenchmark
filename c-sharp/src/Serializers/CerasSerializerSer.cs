using System;
using System.IO;
using System.Linq;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // Ceras
    internal class CerasSerializerSer : SerDeser
    {
        private static readonly Lazy<Ceras.CerasSerializer> _serializer = new Lazy<Ceras.CerasSerializer>(() => new Ceras.CerasSerializer());
        public override string Name => "Ceras";

        public override bool Supports(string testDataName)
        {
            // Ceras is now enabled - uses reflection for generic type deserialization
            return true;
        }
        public override string Serialize(object serializable) => Convert.ToBase64String(_serializer.Value.Serialize(serializable));

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            // Use reflection to call generic Deserialize<T>(byte[]) with _primaryType
            var method = typeof(Ceras.CerasSerializer).GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(byte[]));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(_serializer.Value, new object[] { bytes });
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = _serializer.Value.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            var bytes = ms.ToArray();
            // Use reflection to call generic Deserialize<T>(byte[]) with _primaryType
            var method = typeof(Ceras.CerasSerializer).GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(byte[]));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(_serializer.Value, new object[] { bytes });
        }
    }
}
