///
/// See here https://github.com/Microsoft/bond/
/// >PM Install-Package Bond.CSharp
/// 
using System;
using System.IO;
using Bond;
using Bond.IO.Unsafe;
using Bond.Protocols;

namespace GLD.SerializerBenchmark
{
    internal class BondJsonSerializer : ISerDeser
    {
        private readonly Deserializer<SimpleJsonReader> _deserializer;
        private readonly Serializer<SimpleJsonWriter> _serializer;

        public BondJsonSerializer(Type personType)
        {
            _serializer = new Serializer<SimpleJsonWriter>(personType);
            _deserializer = new Deserializer<SimpleJsonReader>(personType);
        }

        #region ISerDeser Members

        public string Name {get { return "MS Bond Json"; } }

        public string Serialize<T>(object person)
        {
            using (var tw = new StringWriter())
            {
                var writer = new SimpleJsonWriter(tw);
                _serializer.Serialize((T) person, writer);
                return tw.ToString();
            }
        }

        public T Deserialize<T>(string serialized)
        {
            using (var tr = new StringReader(serialized))
            {
                var reader = new SimpleJsonReader(tr);
                return _deserializer.Deserialize<T>(reader);
            }
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
                var writer = new SimpleJsonWriter(outputStream);
                _serializer.Serialize((T) person, writer);
        }

   
        public T Deserialize<T>(Stream inputStream)
        {
                var reader = new SimpleJsonReader(inputStream);
                return _deserializer.Deserialize<T>(reader);
        }

        #endregion
    }
}