using System;
using System.IO;
using Bond;
using Bond.IO.Unsafe;
using Bond.Protocols;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BondFastSerializer : BondSerDeserBase
    {
        private Deserializer<FastBinaryReader<InputBuffer>> _deserializer;
        private Deserializer<FastBinaryReader<InputStream>> _deserializerStream;
        private Serializer<FastBinaryWriter<OutputBuffer>> _serializer;
        private Serializer<FastBinaryWriter<OutputStream>> _serializerStream;

        private void Ensure()
        {
            if (!JustInitialized) return;
            _serializer = new Serializer<FastBinaryWriter<OutputBuffer>>(_primaryType);
            _deserializer = new Deserializer<FastBinaryReader<InputBuffer>>(_primaryType);
            _serializerStream = new Serializer<FastBinaryWriter<OutputStream>>(_primaryType);
            _deserializerStream = new Deserializer<FastBinaryReader<InputStream>>(_primaryType);
            JustInitialized = false;
        }

        public override string Name => "MS Bond Fast";

        public override string Serialize(object serializable)
        {
            Ensure();
            var output = new OutputBuffer(2 * 1024);
            _serializer.Serialize(serializable, new FastBinaryWriter<OutputBuffer>(output));
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public override object Deserialize(string serialized)
        {
            Ensure();
            var input = new InputBuffer(Convert.FromBase64String(serialized));
            return _deserializer.Deserialize(new FastBinaryReader<InputBuffer>(input));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Ensure();
            var output = new OutputStream(outputStream);
            _serializerStream.Serialize(serializable, new FastBinaryWriter<OutputStream>(output));
            output.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            Ensure();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _deserializerStream.Deserialize(new FastBinaryReader<InputStream>(new InputStream(inputStream)));
        }
    }
}
