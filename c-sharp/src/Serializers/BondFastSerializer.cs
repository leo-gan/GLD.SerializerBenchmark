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
            var t = _bondType ?? _primaryType;
            _serializer = new Serializer<FastBinaryWriter<OutputBuffer>>(t);
            _deserializer = new Deserializer<FastBinaryReader<InputBuffer>>(t);
            _serializerStream = new Serializer<FastBinaryWriter<OutputStream>>(t);
            _deserializerStream = new Deserializer<FastBinaryReader<InputStream>>(t);
            JustInitialized = false;
        }

        public override string Name => "MS Bond Fast";

        public override string Serialize(object serializable)
        {
            Ensure();
            var output = new OutputBuffer(2 * 1024);
            var writer = new FastBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize(Payload(serializable), writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public override object Deserialize(string serialized)
        {
            Ensure();
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new FastBinaryReader<InputBuffer>(input);
            return _deserializer.Deserialize(reader);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Ensure();
            var output = new OutputStream(outputStream);
            var writer = new FastBinaryWriter<OutputStream>(output);
            _serializerStream.Serialize(Payload(serializable), writer);
            output.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            Ensure();
            inputStream.Seek(0, SeekOrigin.Begin);
            var input = new InputStream(inputStream);
            var reader = new FastBinaryReader<InputStream>(input);
            return _deserializerStream.Deserialize(reader);
        }
    }
}
