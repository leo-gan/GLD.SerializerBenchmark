using System;
using System.IO;
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
            // Use reflection to call generic Deserialize with _primaryType
            var method = typeof(SpanJson.JsonSerializer.Generic.Utf16).GetMethod("Deserialize", new[] { typeof(string) });
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
            using (var ms = new MemoryStream())
            {
                inputStream.CopyTo(ms);
                var bytes = ms.ToArray();
                // Use reflection to call generic Deserialize with _primaryType
                var method = typeof(SpanJson.JsonSerializer.Generic.Utf8).GetMethod("Deserialize", new[] { typeof(byte[]) });
                var genericMethod = method.MakeGenericMethod(_primaryType);
                return genericMethod.Invoke(null, new[] { bytes });
            }
        }
    }
}
