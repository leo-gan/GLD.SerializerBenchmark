using System;
using System.IO;
using ExtendedXmlSerializer;
using ExtendedXmlSerializer.Configuration;
using GLD.SerializerBenchmark.TestData;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class ExtendedXmlSerializerSer : SerDeser
    {
        private readonly IExtendedXmlSerializer _serializer =
            new ConfigurationContainer().UseAutoFormatting().Create();
        private XmlEnvelope _native;

        public override string Name => "ExtendedXmlSerializer";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data)
        {
            _native = new XmlEnvelope
            {
                TypeName = data.GetType().AssemblyQualifiedName,
                Json = JsonConvert.SerializeObject(data)
            };
            // untimed smoke
            var xml = _serializer.Serialize(_native);
            var back = _serializer.Deserialize<XmlEnvelope>(xml);
            if (back?.Json == null) throw new InvalidOperationException("ExtendedXml envelope smoke failed");
        }

        public override object ToDomain(object decoded)
        {
            if (decoded is XmlEnvelope env)
                return JsonConvert.DeserializeObject(env.Json, Type.GetType(env.TypeName));
            return decoded;
        }

        public override string Serialize(object serializable)
        {
            var env = _native ?? Make(serializable);
            return _serializer.Serialize(env);
        }

        public override object Deserialize(string serialized)
            => _serializer.Deserialize<XmlEnvelope>(serialized);

        public override void Serialize(object serializable, Stream outputStream)
        {
            using var sw = new StreamWriter(outputStream, System.Text.Encoding.UTF8, 1024, true);
            sw.Write(Serialize(serializable));
            sw.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var sr = new StreamReader(inputStream, System.Text.Encoding.UTF8, false, 1024, true);
            return Deserialize(sr.ReadToEnd());
        }

        static XmlEnvelope Make(object data) => new XmlEnvelope
        {
            TypeName = data.GetType().AssemblyQualifiedName,
            Json = JsonConvert.SerializeObject(data)
        };

        public class XmlEnvelope
        {
            public string TypeName { get; set; }
            public string Json { get; set; }
        }
    }
}
