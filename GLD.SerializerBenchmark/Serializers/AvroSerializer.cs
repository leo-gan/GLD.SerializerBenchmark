///
/// See here http://azure.microsoft.com/en-us/documentation/articles/hdinsight-dotnet-avro-serialization/
/// >PM Install-Package Microsoft.Hadoop.Avro
/// 

using System;
using System.IO;
using Microsoft.Hadoop.Avro;

namespace GLD.SerializerBenchmark
{
    internal class AvroSerializer : ISerDeser
    {
        private readonly IAvroSerializer<Person> _serializer = Microsoft.Hadoop.Avro.AvroSerializer.Create<Person>();

        #region ISerDeser Members

        public AvroSerializer(Type type)
        {
        }

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, (Person)person); 
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T) ((object) _serializer.Deserialize(stream));
            }
        }

        #endregion
    }
}