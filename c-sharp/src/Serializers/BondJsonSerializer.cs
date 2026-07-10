using System.IO;
using Bond;
using Bond.Protocols;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BondJsonSerializer : BondSerDeserBase
    {
        private Deserializer<SimpleJsonReader> _deserializer;
        private Serializer<SimpleJsonWriter> _serializer;

        private void Ensure()
        {
            if (!JustInitialized) return;
            var t = _bondType ?? _primaryType;
            _serializer = new Serializer<SimpleJsonWriter>(t);
            _deserializer = new Deserializer<SimpleJsonReader>(t);
            JustInitialized = false;
        }

        public override string Name => "MS Bond Json";

        public override string Serialize(object serializable)
        {
            Ensure();
            using (var tw = new StringWriter())
            {
                var writer = new SimpleJsonWriter(tw);
                _serializer.Serialize(Payload(serializable), writer);
                return tw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            Ensure();
            using (var tr = new StringReader(serialized))
            {
                var reader = new SimpleJsonReader(tr);
                return _deserializer.Deserialize(reader);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Ensure();
            var writer = new SimpleJsonWriter(outputStream);
            _serializer.Serialize(Payload(serializable), writer);
            writer.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            Ensure();
            inputStream.Seek(0, SeekOrigin.Begin);
            var reader = new SimpleJsonReader(inputStream);
            return _deserializer.Deserialize(reader);
        }
    }
}
