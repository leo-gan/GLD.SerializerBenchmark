using System.IO;
using System.Xml.Serialization;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class XmlSerializerSer : SerDeser
    {
        private XmlSerializer _serializer;

        private void Initialize()
        {
            if (!JustInitialized) return;
            _serializer = new XmlSerializer(_primaryType, _secondaryTypes.ToArray());
            JustInitialized = false;
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "MS XmlSerializer"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            using (var sw = new StringWriter())
            {
                _serializer.Serialize(sw, serializable);
                return sw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            using (var sr = new StringReader(serialized))
            {
                return _serializer.Deserialize(sr);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            _serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}