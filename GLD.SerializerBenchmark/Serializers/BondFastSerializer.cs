///
/// See here https://github.com/Microsoft/bond/
/// >PM Install-Package Microsoft.Hadoop.Avro
/// 
using System;
using System.IO;
using Bond;
using Bond.IO.Unsafe;
using Bond.Protocols;

namespace GLD.SerializerBenchmark
{
    internal class BondFastSerializer : ISerDeser
    {
        private readonly Deserializer<FastBinaryReader<InputBuffer>> _deserializer;
        private readonly Serializer<FastBinaryWriter<OutputBuffer>> _serializer;
        private readonly Deserializer<FastBinaryReader<InputStream>> _deserializerStream;
        private readonly Serializer<FastBinaryWriter<OutputStream>> _serializerStream;

        public BondFastSerializer(Type personType)
        {
            _serializer = new Serializer<FastBinaryWriter<OutputBuffer>>(personType);
            _deserializer = new Deserializer<FastBinaryReader<InputBuffer>>(personType);
            _serializerStream = new Serializer<FastBinaryWriter<OutputStream>>(personType);
            _deserializerStream = new Deserializer<FastBinaryReader<InputStream>>(personType);
        }

        #region ISerDeser Members

        public string Name {get { return "MS Bond Fast"; } }

        public string Serialize<T>(object person)
        {
            var output = new OutputBuffer(2 * 1024);
            var writer = new FastBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize((T)person, writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public T Deserialize<T>(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new FastBinaryReader<InputBuffer>(input);
            return (T) _deserializer.Deserialize(reader);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
           var output = new OutputStream(outputStream);
            var writer = new FastBinaryWriter<OutputStream>(output);
            _serializerStream.Serialize(person, writer);
        }

  public T Deserialize<T>(Stream inputStream)
        {
            var input = new InputStream(inputStream);
            var reader = new FastBinaryReader<InputStream>(input);
            return (T) _deserializerStream.Deserialize(reader);
        }

        #endregion
    }
}