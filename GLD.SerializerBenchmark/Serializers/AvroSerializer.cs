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
        //private static Microsoft.Hadoop.Avro.AvroSerializer _serializer = Microsoft.Hadoop.Avro.AvroSerializer.Create<Person>();;
        #region ISerDeser Members

        public AvroSerializer(Type type)
        {
            // TODO: Hack! How to get a type of the person object? In XmlSerializer it works, not here!
            // The serialize is typed and type should be know upfront. 
            // The staic variable cannot be created.
            //_serializer =  Microsoft.Hadoop.Avro.AvroSerializer.Create<Person>();
        }

        public string Serialize<T>(object person)
        {
            var serializer =  Microsoft.Hadoop.Avro.AvroSerializer.Create<T>(); 
            using (var ms = new MemoryStream())
            {
                serializer.Serialize(ms, (T)person); 
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public T Deserialize<T>(string serialized)
        {
            var serializer =  Microsoft.Hadoop.Avro.AvroSerializer.Create<T>();
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return (T)serializer.Deserialize(stream); 
            }
        }

        #endregion
    }
}