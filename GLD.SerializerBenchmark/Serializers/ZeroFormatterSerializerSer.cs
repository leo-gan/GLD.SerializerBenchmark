using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // ZeroFormatter
    internal class ZeroFormatterSerializerSer : SerDeser
    {
        public override string Name => "ZeroFormatter";

        public override bool Supports(string testDataName)
        {
            // ZeroFormatter requires types to be registered at compile time with [ZeroFormattable] attribute
            // It cannot deserialize to 'object' without proper type registration
            return false;
        }

        public override string Serialize(object serializable) => Convert.ToBase64String(ZeroFormatter.ZeroFormatterSerializer.Serialize(serializable));
        public override object Deserialize(string serialized) => ZeroFormatter.ZeroFormatterSerializer.Deserialize<object>(Convert.FromBase64String(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            var bytes = ZeroFormatter.ZeroFormatterSerializer.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }
        public override object Deserialize(Stream inputStream) {
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return ZeroFormatter.ZeroFormatterSerializer.Deserialize<object>(ms.ToArray());
        }
    }
}
