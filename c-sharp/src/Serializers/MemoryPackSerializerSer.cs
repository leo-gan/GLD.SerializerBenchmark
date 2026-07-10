using System;
using System.IO;
using MemoryPack;

namespace GLD.SerializerBenchmark.Serializers
{
    // Domain types are [MemoryPackable] V2 models — no type conversion.
    internal class MemoryPackSerializerSer : SerDeser
    {
        public override string Name => "MemoryPack";
        public override bool Supports(string testDataName) => true;

        public override string Serialize(object serializable)
        {
            var bytes = MemoryPackSerializer.Serialize(serializable.GetType(), serializable);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return MemoryPackSerializer.Deserialize(_primaryType, bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = MemoryPackSerializer.Serialize(serializable.GetType(), serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return MemoryPackSerializer.Deserialize(_primaryType, ms.ToArray());
        }
    }
}
