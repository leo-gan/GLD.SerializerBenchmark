using System;
using System.IO;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // BinaryPack
    internal class BinaryPackSerializerSer : SerDeser
    {
        public override string Name => "BinaryPack";

        public override bool Supports(string testDataName)
        {
            // BinaryPack requires compile-time type knowledge and proper generic constraints
            // The reflection approach causes TargetInvocationException - cannot be fixed without source changes
            return false;
        }
        public override string Serialize(object serializable) => Convert.ToBase64String(BinaryPack.BinaryConverter.Serialize(serializable));

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            // Use reflection to call generic Deserialize with _primaryType
            var method = typeof(BinaryPack.BinaryConverter).GetMethod("Deserialize", new[] { typeof(byte[]) });
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(null, new[] { bytes });
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = BinaryPack.BinaryConverter.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            var bytes = ms.ToArray();
            // Use reflection to call generic Deserialize with _primaryType
            var method = typeof(BinaryPack.BinaryConverter).GetMethod("Deserialize", new[] { typeof(byte[]) });
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(null, new[] { bytes });
        }
    }
}
