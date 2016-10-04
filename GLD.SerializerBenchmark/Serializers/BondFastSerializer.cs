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
    internal class BondFastSerializer : SerDeser
    {
        private Deserializer<FastBinaryReader<InputBuffer>> _deserializer;
        private Deserializer<FastBinaryReader<InputStream>> _deserializerStream;
        private Serializer<FastBinaryWriter<OutputBuffer>> _serializer;
        private Serializer<FastBinaryWriter<OutputStream>> _serializerStream;

        private void Initialize()
        {
            if (!JustInitialized) return;
            _serializer = new Serializer<FastBinaryWriter<OutputBuffer>>(_primaryType);
            _deserializer = new Deserializer<FastBinaryReader<InputBuffer>>(_primaryType);
            _serializerStream = new Serializer<FastBinaryWriter<OutputStream>>(_primaryType);
            _deserializerStream = new Deserializer<FastBinaryReader<InputStream>>(_primaryType);
            JustInitialized = false;
        }

        #region ISerDeser Members

        public override string Name
        {
            get { return "MS Bond Fast"; }
        }

        public override string Serialize(object serializable)
        {
            Initialize();
            var output = new OutputBuffer(2*1024);
            var writer = new FastBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize(serializable, writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public override object Deserialize(string serialized)
        {
            Initialize();
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new FastBinaryReader<InputBuffer>(input);
            return _deserializer.Deserialize(reader);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Initialize();
            //outputStream.Seek(0, SeekOrigin.Begin);
            var output = new OutputStream(outputStream);
            var writer = new FastBinaryWriter<OutputStream>(output);
            _serializerStream.Serialize(serializable, writer);
            output.Flush();
        }
                             
        public override object Deserialize(Stream inputStream)
        {
            Initialize();
            inputStream.Seek(0, SeekOrigin.Begin);
            var input = new InputStream(inputStream);
            var reader = new FastBinaryReader<InputStream>(input);
            return _deserializerStream.Deserialize(reader);
        }

        #endregion
    }
}