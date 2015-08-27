using System;
using System.IO;
using System.Linq;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class XmlSerializerSer : SerDeser
    {
        private  System.Xml.Serialization.XmlSerializer _serializer;

        private void Initialize()
        {
            if (!base.JustInitialized) return;
            _serializer = new System.Xml.Serialization.XmlSerializer(_primaryType, _secondaryTypes.ToArray());
            JustInitialized = false;
        }
       #region ISerDeser Members

        public override string Name {get { return "MS XmlSerializer"; } }
        public override string Serialize(object serializable)
        {
            Initialize();
            using (var sw = new StringWriter())
            {
                _serializer.Serialize(sw,serializable);
                return sw.ToString();
            }
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            using (var sr = new StringReader(serialized))
            {
                return  _serializer.Deserialize(sr);
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
                return  _serializer.Deserialize(inputStream);
        }
        #endregion
    }
}