using System;
using System.IO;
using System.Linq;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    // SpanJson
    internal class SpanJsonSerializerSer : SerDeser
    {
        public override string Name => "SpanJson";

        public override bool Supports(string testDataName)
        {
            // SpanJson does not support circular references in ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable) => SpanJson.JsonSerializer.Generic.Utf16.Serialize(serializable);

        public override object Deserialize(string serialized)
        {
            // Use reflection to call generic Deserialize<T>(string) with _primaryType
            var method = typeof(SpanJson.JsonSerializer.Generic.Utf16).GetMethods()
                .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(string));
            var genericMethod = method.MakeGenericMethod(_primaryType);
            return genericMethod.Invoke(null, new[] { serialized });
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var json = SpanJson.JsonSerializer.Generic.Utf8.Serialize(serializable);
            outputStream.Write(json, 0, json.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using (var ms = new MemoryStream())
            {
                inputStream.CopyTo(ms);
                var bytes = ms.ToArray();
                // Use reflection to call generic Deserialize<T>(byte[]) with _primaryType
                var method = typeof(SpanJson.JsonSerializer.Generic.Utf8).GetMethods()
                    .First(m => m.Name == "Deserialize" && m.IsGenericMethod && m.GetGenericArguments().Length == 1 && m.GetParameters().Length == 1 && m.GetParameters()[0].ParameterType == typeof(byte[]));
                var genericMethod = method.MakeGenericMethod(_primaryType);
                return genericMethod.Invoke(null, new[] { bytes });
            }
        }
    }
}
