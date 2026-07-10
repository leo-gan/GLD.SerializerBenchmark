using System;
using System.IO;
using System.Linq;
using System.Reflection;
using GroBuf;
using GroBuf.DataMembersExtracters;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class GroBufSerializerSer : SerDeser
    {
        private readonly Serializer _serializer = new Serializer(new PropertiesExtractor());

        public override string Name => "GroBuf";
        public override bool Supports(string testDataName) => true;

        public override string Serialize(object serializable)
        {
            var mi = typeof(Serializer).GetMethods()
                .First(m => m.Name == "Serialize" && m.IsGenericMethod && m.GetParameters().Length == 1);
            var bytes = (byte[])mi.MakeGenericMethod(serializable.GetType()).Invoke(_serializer, new[] { serializable });
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
            => _serializer.Deserialize(_primaryType, Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = Convert.FromBase64String(Serialize(serializable));
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Deserialize(_primaryType, ms.ToArray());
        }
    }
}
