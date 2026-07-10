using System;
using System.Collections.Generic;
using System.IO;
using MemoryPack;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// MemoryPack via public Type-based APIs (no suite-type switch).
    /// https://github.com/Cysharp/MemoryPack
    /// </summary>
    internal class MemoryPackSerializerSer : SerDeser
    {
        public override string Name => "MemoryPack";
        public override bool Supports(string testDataName) => true;

        public override string Serialize(object serializable)
        {
            // byte[] Serialize(Type type, object? value, ...)
            var bytes = MemoryPackSerializer.Serialize(_primaryType, serializable);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return MemoryPackSerializer.Deserialize(_primaryType, (ReadOnlySpan<byte>)bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = MemoryPackSerializer.Serialize(_primaryType, serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            var bytes = ms.ToArray();
            return MemoryPackSerializer.Deserialize(_primaryType, (ReadOnlySpan<byte>)bytes);
        }
    }
}
