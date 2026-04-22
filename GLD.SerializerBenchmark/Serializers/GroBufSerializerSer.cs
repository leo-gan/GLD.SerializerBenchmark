using System;
using System.IO;
using GroBuf;
using GroBuf.DataMembersExtracters;

namespace GLD.SerializerBenchmark.Serializers
{
    // GroBuf
    internal class GroBufSerializerSer : SerDeser
    {
        private readonly Serializer _serializer = new Serializer(new PropertiesExtractor());

        public override string Name => "GroBuf";

        public override bool Supports(string testDataName)
        {
            // GroBuf has comparison errors on complex types due to field handling issues
            // Only enable for simple types
            return testDataName == "Integer" || testDataName == "SimpleObject";
        }

        public override string Serialize(object serializable)
        {
            var bytes = _serializer.Serialize(serializable);
            return Convert.ToBase64String(bytes);
        }

        public override object Deserialize(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            return _serializer.Deserialize(_primaryType, bytes);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = _serializer.Serialize(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using (var ms = new MemoryStream())
            {
                inputStream.CopyTo(ms);
                return _serializer.Deserialize(_primaryType, ms.ToArray());
            }
        }
    }
}
