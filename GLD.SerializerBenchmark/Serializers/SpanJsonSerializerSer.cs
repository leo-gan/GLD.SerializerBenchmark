using System;
using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // SpanJson
    internal class SpanJsonSerializerSer : SerDeser
    {
        public override string Name => "SpanJson";
        public override string Serialize(object serializable) => SpanJson.JsonSerializer.Generic.Utf16.Serialize(serializable);
        public override object Deserialize(string serialized) => SpanJson.JsonSerializer.Generic.Utf16.Deserialize<object>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            sw.Write(SpanJson.JsonSerializer.Generic.Utf16.Serialize(serializable));
        }
        public override object Deserialize(Stream inputStream) {
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            return SpanJson.JsonSerializer.Generic.Utf16.Deserialize<object>(sr.ReadToEnd());
        }
    }
}
