using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // BinaryPack
    internal class BinaryPackSerializerSer : SerDeser
    {
        public override string Name => "BinaryPack";
        public override string Serialize(object serializable) => Convert.ToBase64String(BinaryPack.BinaryConverter.Serialize(serializable));
        public override object Deserialize(string serialized) => BinaryPack.BinaryConverter.Deserialize<object>(Convert.FromBase64String(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = BinaryPack.BinaryConverter.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return BinaryPack.BinaryConverter.Deserialize<object>(ms.ToArray());
        }
    }
}
