using System.IO;
using Bond;
using Bond.Protocols;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BondJsonSerializer : BondSerDeserBase
    {
        private Deserializer<SimpleJsonReader> _deserializer;
        private Serializer<SimpleJsonWriter> _serializer;

        public override void Initialize(System.Type serializablePrimaryType, System.Collections.Generic.List<System.Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            _serializer = new Serializer<SimpleJsonWriter>(_primaryType);
            _deserializer = new Deserializer<SimpleJsonReader>(_primaryType);
            JustInitialized = false;
        }

        public override string Name => "MS Bond Json";

        public override string Serialize(object serializable)
        {
            using var tw = new StringWriter();
            _serializer.Serialize(serializable, new SimpleJsonWriter(tw));
            return tw.ToString();
        }

        public override object Deserialize(string serialized)
        {
            using var tr = new StringReader(serialized);
            return _deserializer.Deserialize(new SimpleJsonReader(tr));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var writer = new SimpleJsonWriter(outputStream);
            _serializer.Serialize(serializable, writer);
            writer.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _deserializer.Deserialize(new SimpleJsonReader(inputStream));
        }
    }
}
