using System;
using System.IO;

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
        public override object Deserialize(string serialized) => SpanJson.JsonSerializer.Generic.Utf16.Deserialize<dynamic>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            // SpanJson usually works with byte[] or ReadOnlySpan<byte>
            var json = SpanJson.JsonSerializer.Generic.Utf8.Serialize(serializable);
            outputStream.Write(json, 0, json.Length);
        }
        public override object Deserialize(Stream inputStream) {
             using (var ms = new MemoryStream())
            {
                inputStream.CopyTo(ms);
                return SpanJson.JsonSerializer.Generic.Utf8.Deserialize<dynamic>(ms.ToArray());
            }
        }
    }
}
