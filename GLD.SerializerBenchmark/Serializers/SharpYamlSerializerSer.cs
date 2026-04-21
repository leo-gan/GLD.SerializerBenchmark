using System;
using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // SharpYaml
    internal class SharpYamlSerializerSer : SerDeser
    {
        public override string Name => "SharpYaml";
        public override string Serialize(object serializable) => SharpYaml.YamlSerializer.Serialize(serializable);
        public override object Deserialize(string serialized) => SharpYaml.YamlSerializer.Deserialize<object>(serialized);
        public override void Serialize(object serializable, Stream outputStream) {
            using var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true);
            sw.Write(SharpYaml.YamlSerializer.Serialize(serializable));
        }
        public override object Deserialize(Stream inputStream) {
            using var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true);
            return SharpYaml.YamlSerializer.Deserialize<object>(sr.ReadToEnd());
        }
    }
}
