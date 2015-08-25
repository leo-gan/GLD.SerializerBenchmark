using System;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal class XmlSerializer : ISerDeser
    {
        private readonly System.Xml.Serialization.XmlSerializer _serializer;

        public XmlSerializer(Type person, Type[] extraTypes)
        {
            _serializer = new System.Xml.Serialization.XmlSerializer(person, extraTypes);
        }

        #region ISerDeser Members

        public string Name {get { return "MS XmlSerializer"; } }

        public string Serialize<T>(object person)
        {
            using (var sw = new StringWriter())
            {
                _serializer.Serialize(sw, (T)person);
                return sw.ToString();
            }
        }

        public T Deserialize<T>(string serialized)
        {
            using (var sr = new StringReader(serialized))
            {
                return (T) _serializer.Deserialize(sr);
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
                _serializer.Serialize(outputStream, (T)person);
        }

 
        public T Deserialize<T>(Stream inputStream)
        {
                return (T) _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}