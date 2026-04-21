using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // MemoryPack
    internal class MemoryPackSerializerSer : SerDeser
    {
        public override string Name => "MemoryPack";
        public override string Serialize(object serializable) => Convert.ToBase64String(MemoryPack.MemoryPackSerializer.Serialize(serializable));
        public override object Deserialize(string serialized) => MemoryPack.MemoryPackSerializer.Deserialize<object>(Convert.FromBase64String(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = MemoryPack.MemoryPackSerializer.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return MemoryPack.MemoryPackSerializer.Deserialize<object>(ms.ToArray());
        }
    }
}
