using System;
using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // YamlDotNet
    internal class YamlDotNetSerializerSer : SerDeser
    {
        private static readonly YamlDotNet.Serialization.ISerializer _serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
        private static readonly YamlDotNet.Serialization.IDeserializer _deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
        public override string Name => "YamlDotNet";
        public override string Serialize(object serializable) => _serializer.Serialize(serializable);
        public override object Deserialize(string serialized) => _deserializer.Deserialize(new StringReader(serialized));
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            _serializer.Serialize(sw, serializable);
        }
        public override object Deserialize(Stream inputStream) {
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            return _deserializer.Deserialize(sr);
        }
    }
}
