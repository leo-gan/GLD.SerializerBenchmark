using System;
using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // YAXLib
    internal class YAXLibSerializerSer : SerDeser
    {
        public override string Name => "YAXLib";
        public override string Serialize(object serializable) {
            var serializer = new YAXLib.YAXSerializer(serializable.GetType());
            return serializer.Serialize(serializable);
        }
        public override object Deserialize(string serialized) {
            return null; // YAXLib requires generic type, hard to do `object`
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var serializer = new YAXLib.YAXSerializer(serializable.GetType());
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            serializer.Serialize(serializable, sw);
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
