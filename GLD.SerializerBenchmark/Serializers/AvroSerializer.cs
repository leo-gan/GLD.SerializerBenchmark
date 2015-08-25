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
        // TODO: There is a hack: FOr some reason it is impossible to pass generic T type. The Person type is patched into serializer code.
        private readonly IAvroSerializer<Person> _serializer = Microsoft.Hadoop.Avro.AvroSerializer.Create<Person>();

        #region ISerDeser Members

        public AvroSerializer(Type type)
        {
        }

        public string Name
        {
            get { return "MS Avro"; }
        }

        public string Serialize<T>(object person)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, (Person) person);
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

        public void Serialize<T>(object person, Stream outputStream)
        {
            _serializer.Serialize(outputStream, (Person) person);
        }

        public T Deserialize<T>(Stream inputStream)
        {
            return (T) ((object) _serializer.Deserialize(inputStream));
        }

        #endregion
    }
}