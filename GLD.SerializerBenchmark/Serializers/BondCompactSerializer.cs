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
    internal class BondCompactSerializer : ISerDeser
    {
        private readonly Deserializer<CompactBinaryReader<InputBuffer>> _deserializer;
        private readonly Deserializer<CompactBinaryReader<InputStream>> _deserializerStream;
        private readonly Serializer<CompactBinaryWriter<OutputBuffer>> _serializer;
        private readonly Serializer<CompactBinaryWriter<OutputStream>> _serializerStream;

        public BondCompactSerializer(Type personType)
        {
            _serializer = new Serializer<CompactBinaryWriter<OutputBuffer>>(personType);
            _deserializer = new Deserializer<CompactBinaryReader<InputBuffer>>(personType);
            _serializerStream = new Serializer<CompactBinaryWriter<OutputStream>>(personType);
            _deserializerStream = new Deserializer<CompactBinaryReader<InputStream>>(personType);
        }

        #region ISerDeser Members

        public string Name
        {
            get { return "MS Bond Compact"; }
        }

        public string Serialize<T>(object person)
        {
            var output = new OutputBuffer(2*1024);
            var writer = new CompactBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize((T) person, writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public T Deserialize<T>(string serialized)
        {
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new CompactBinaryReader<InputBuffer>(input);
            return (T) _deserializer.Deserialize(reader);
        }

        public void Serialize<T>(object person, Stream outputStream)
        {
            var output = new OutputStream(outputStream);
            var writer = new CompactBinaryWriter<OutputStream>(output);
            _serializerStream.Serialize(person, writer);
        }

        public T Deserialize<T>(Stream inputStream)
        {
            var input = new InputStream(inputStream);
            var reader = new CompactBinaryReader<InputStream>(input);
            return (T) _deserializerStream.Deserialize(reader);
        }

        #endregion
    }
}