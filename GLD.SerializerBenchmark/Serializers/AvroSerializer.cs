///
/// See here http://azure.microsoft.com/en-us/documentation/articles/hdinsight-dotnet-avro-serialization/
/// >PM Install-Package Microsoft.Hadoop.Avro
/// 

using System;
using System.IO;
using Microsoft.Hadoop.Avro;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class AvroSerializer : SerDeser
    {
        // TODO: For some reason it is impossible to pass generic T type to serializer. 
        private readonly IAvroSerializer<object> _serializer;

        public AvroSerializer()
        {
            _serializer = Microsoft.Hadoop.Avro.AvroSerializer.Create<object>();
        }
        #region ISerDeser Members

        public override string Name
        {
            get { return "MS Avro"; }
        }

        public override string Serialize(object serializable)
        {
            using (var ms = new MemoryStream())
            {
                _serializer.Serialize(ms, serializable);
                ms.Flush();
                ms.Position = 0;
                return Convert.ToBase64String(ms.ToArray());
            }
        }

        public override object Deserialize(string serialized)
        {
            var b = Convert.FromBase64String(serialized);
            using (var stream = new MemoryStream(b))
            {
                stream.Seek(0, SeekOrigin.Begin);
                return _serializer.Deserialize(stream);
            }
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            _serializer.Serialize(outputStream, serializable);
        }

        public override object Deserialize(Stream inputStream)
        {
            return _serializer.Deserialize(inputStream);
        }

        #endregion
    }
}