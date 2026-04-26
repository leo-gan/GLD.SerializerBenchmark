using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // YAXLib
    internal class YAXLibSerializerSer : SerDeser
    {
        public override string Name => "YAXLib";

        public override bool Supports(string testDataName)
        {
            // YAXLib has TargetInvocationException on Stream operations
            // Also has comparison errors on ObjectGraph
            // Note: This is checked in TestOnSerializer, we need additional logic for Stream in the test itself
            return testDataName != "ObjectGraph";
        }
        public override string Serialize(object serializable) {
            var serializer = new YAXLib.YAXSerializer(serializable.GetType());
            return serializer.Serialize(serializable);
        }
        public override object Deserialize(string serialized)
        {
            // Use reflection to call generic YAXSerializer(_primaryType) and Deserialize(string)
            var serializerType = typeof(YAXLib.YAXSerializer);
            var serializer = Activator.CreateInstance(serializerType, _primaryType);
            var method = serializerType.GetMethods()
                .First(m => m.Name == "Deserialize" && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(string));
            return method.Invoke(serializer, new[] { serialized });
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var serializer = new YAXLib.YAXSerializer(serializable.GetType());
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            serializer.Serialize(serializable, sw);
        }
        public override object Deserialize(Stream inputStream)
        {
            // Use reflection to call generic YAXSerializer(_primaryType) and Deserialize(TextReader)
            inputStream.Seek(0, SeekOrigin.Begin);
            var serializerType = typeof(YAXLib.YAXSerializer);
            var serializer = Activator.CreateInstance(serializerType, _primaryType);
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            var method = serializerType.GetMethods()
                .First(m => m.Name == "Deserialize" && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(TextReader));
            return method.Invoke(serializer, new object[] { sr });
        }
    }
}
