///
/// See here https://github.com/Microsoft/bond/
/// >PM Install-Package Bond.CSharp
/// 

using System.IO;
using Bond;
using Bond.Protocols;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BondJsonSerializer : SerDeser
    {
        private Deserializer<SimpleJsonReader> _deserializer;
        private Serializer<SimpleJsonWriter> _serializer;

        private void Initialize()
        {
            if (!JustInitialized) return;
            _serializer = new Serializer<SimpleJsonWriter>(_primaryType);
            _deserializer = new Deserializer<SimpleJsonReader>(_primaryType);
            JustInitialized = false;
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "MS Bond Json"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            using (var tw = new StringWriter())
            {
                var writer = new SimpleJsonWriter(tw);
                _serializer.Serialize(serializable, writer);
                return tw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            using (var tr = new StringReader(serialized))
            {
                var reader = new SimpleJsonReader(tr);
                return _deserializer.Deserialize(reader);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            var writer = new SimpleJsonWriter(outputStream);
            _serializer.Serialize(serializable, writer);
            writer.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            inputStream.Seek(0, SeekOrigin.Begin);
            var reader = new SimpleJsonReader(inputStream);
            return _deserializer.Deserialize(reader);
        }

        #endregion
    }
}