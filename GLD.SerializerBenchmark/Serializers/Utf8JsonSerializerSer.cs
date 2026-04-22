using System;
using System.IO;
using System.Linq;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // Utf8Json
    internal class Utf8JsonSerializerSer : SerDeser
    {
        public override string Name => "Utf8Json";

        public override bool Supports(string testDataName)
        {
            // Utf8Json does not support circular references in ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable) => Utf8Json.JsonSerializer.ToJsonString(serializable);
        public override object Deserialize(string serialized)
        {
            // Use reflection to call generic Deserialize<T>(string) with _primaryType
            var method = typeof(Utf8Json.JsonSerializer).GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(string));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(null, new[] { serialized });
        }
        public override void Serialize(object serializable, Stream outputStream) {
            Utf8Json.JsonSerializer.Serialize(outputStream, serializable);
        }
        public override object Deserialize(Stream inputStream)
        {
            // Use reflection to call generic Deserialize<T>(Stream) with _primaryType
            var method = typeof(Utf8Json.JsonSerializer).GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(Stream));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(null, new[] { inputStream });
        }
    }
}
