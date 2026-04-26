using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // YamlDotNet
    internal class YamlDotNetSerializerSer : SerDeser
    {
        private static readonly YamlDotNet.Serialization.ISerializer _serializer = new YamlDotNet.Serialization.SerializerBuilder().Build();
        private static readonly YamlDotNet.Serialization.IDeserializer _deserializer = new YamlDotNet.Serialization.DeserializerBuilder().Build();
        public override string Name => "YamlDotNet";
        public override string Serialize(object serializable) => _serializer.Serialize(serializable);
        public override object Deserialize(string serialized)
        {
            // Use reflection to call generic Deserialize<T>(TextReader) with _primaryType
            var method = _deserializer.GetType().GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(TextReader));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(_deserializer, new object[] { new StringReader(serialized) });
        }
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            _serializer.Serialize(sw, serializable);
        }
        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            // Use reflection to call generic Deserialize<T>(TextReader) with _primaryType
            var method = _deserializer.GetType().GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(TextReader));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(_deserializer, new object[] { sr });
        }
    }
}
