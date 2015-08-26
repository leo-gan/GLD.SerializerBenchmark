///
/// See here https://github.com/Microsoft/bond/
/// >PM Install-Package Microsoft.Hadoop.Avro
/// 

using System;
using System.IO;
using Bond;
using Bond.IO.Unsafe;
using Bond.Protocols;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BondCompactSerializer : SerDeser
    {
        private  Deserializer<CompactBinaryReader<InputBuffer>> _deserializer;
        private  Deserializer<CompactBinaryReader<InputStream>> _deserializerStream;
        private  Serializer<CompactBinaryWriter<OutputBuffer>> _serializer;
        private  Serializer<CompactBinaryWriter<OutputStream>> _serializerStream;

        private void Initialize()
        {
            if (!JustInitialized) return;
            _serializer = new Serializer<CompactBinaryWriter<OutputBuffer>>(_primaryType);
            _deserializer = new Deserializer<CompactBinaryReader<InputBuffer>>(_primaryType);
            _serializerStream = new Serializer<CompactBinaryWriter<OutputStream>>(_primaryType);
            _deserializerStream = new Deserializer<CompactBinaryReader<InputStream>>(_primaryType);
            JustInitialized = false;
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "MS Bond Compact"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            var output = new OutputBuffer(2*1024);
            var writer = new CompactBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize(serializable, writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new CompactBinaryReader<InputBuffer>(input);
            return _deserializer.Deserialize(reader);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            var output = new OutputStream(outputStream);
            var writer = new CompactBinaryWriter<OutputStream>(output);
            _serializerStream.Serialize(serializable, writer);
        }

        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            var input = new InputStream(inputStream);
            var reader = new CompactBinaryReader<InputStream>(input);
            return _deserializerStream.Deserialize(reader);
        }

        #endregion
    }
}