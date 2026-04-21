using System;
using System.IO;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // SharpYaml
    internal class SharpYamlSerializerSer : SerDeser
    {
        public override string Name => "SharpYaml";

        public override bool Supports(string testDataName)
        {
            // SharpYaml has maximum nesting depth limit of 64 which is exceeded by ObjectGraph
            return testDataName != "ObjectGraph";
        }

        public override string Serialize(object serializable)
        {
            return SharpYaml.YamlSerializer.Serialize(serializable);
        }

        public override object Deserialize(string serialized)
        {
            return SharpYaml.YamlSerializer.Deserialize(serialized, _primaryType);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            using (var sw = new StreamWriter(outputStream, Encoding.UTF8, 1024, true))
            {
                sw.Write(SharpYaml.YamlSerializer.Serialize(serializable));
            }
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using (var sr = new StreamReader(inputStream, Encoding.UTF8, false, 1024, true))
            {
                return SharpYaml.YamlSerializer.Deserialize(sr.ReadToEnd(), _primaryType);
            }
        }
    }
}
