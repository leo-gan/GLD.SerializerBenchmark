using System;
using System.IO;
using ExtendedXmlSerializer;
using ExtendedXmlSerializer.Configuration;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// <b>Honesty — not native domain XML.</b>
    /// <para>
    /// Timed work serializes an <see cref="XmlEnvelope"/> whose payload is a
    /// <b>Newtonsoft.Json</b> string of the suite domain object, not ExtendedXmlSerializer
    /// mapping of <c>Message</c>/<c>Document</c>/… graphs. ExtendedXmlSerializer only
    /// round-trips the envelope. Fidelity is restored in <see cref="ToDomain"/> (untimed)
    /// by deserializing the JSON field.
    /// </para>
    /// <para>
    /// Stream mode is <b>adapted</b>: UTF-8 write/read of the same XML string path
    /// (not an ExtendedXml streaming API over domain types).
    /// </para>
    /// Why: ExtendedXml on net8 does not cleanly host the suite’s nested graphs for
    /// all fixtures; this keeps the row registered for size/latency of the envelope
    /// pattern. Do not treat Results as “ExtendedXml of domain POCOs.”
    /// Docs: https://github.com/ExtendedXmlSerializer/home
    /// </summary>
    internal class ExtendedXmlSerializerSer : SerDeser
    {
        private readonly IExtendedXmlSerializer _serializer =
            new ConfigurationContainer().UseAutoFormatting().Create();
        private XmlEnvelope _native;

        public override string Name => "ExtendedXmlSerializer";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data)
        {
            // Untimed: build JSON+type envelope once per cell (includes N-instance batches).
            _native = Make(data);
            var xml = _serializer.Serialize(_native);
            var back = _serializer.Deserialize<XmlEnvelope>(xml);
            if (back?.Json == null)
                throw new InvalidOperationException("ExtendedXml envelope smoke failed");
        }

        public override object ToDomain(object decoded)
        {
            // Untimed: JSON → suite domain (not part of TimeSer/TimeDeser).
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
            // Adapted stream: same string path through a StreamWriter.
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

        /// <summary>Wire type for ExtendedXml only — holds type name + JSON payload.</summary>
        public class XmlEnvelope
        {
            public string TypeName { get; set; }
            public string Json { get; set; }
        }
    }
}
