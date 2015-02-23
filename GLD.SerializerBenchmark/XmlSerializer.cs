using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class XmlSerializer : ISerDeser
    {
        private readonly System.Xml.Serialization.XmlSerializer _serializer;

        public XmlSerializer(Type person)
        {
            _serializer = new System.Xml.Serialization.XmlSerializer(person);
        }

        #region ISerDeser Members

        public string Serialize(object person)
        {
            using (var sw = new StringWriter())
            {
                _serializer.Serialize(sw, person);
                return sw.ToString();
            }
        }

        public T Deserialize<T>(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return (T)_serializer.Deserialize(sr);
            }
        }

        #endregion
    }
}