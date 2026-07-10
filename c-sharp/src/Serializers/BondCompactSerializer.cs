using System;
using System.IO;
using Bond;
using Bond.IO.Unsafe;
using Bond.Protocols;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class BondCompactSerializer : BondSerDeserBase
    {
        private Deserializer<CompactBinaryReader<InputBuffer>> _deserializer;
        private Deserializer<CompactBinaryReader<InputStream>> _deserializerStream;
        private Serializer<CompactBinaryWriter<OutputBuffer>> _serializer;
        private Serializer<CompactBinaryWriter<OutputStream>> _serializerStream;

        private void Ensure()
        {
            if (!JustInitialized) return;
            var t = _bondType ?? _primaryType;
            _serializer = new Serializer<CompactBinaryWriter<OutputBuffer>>(t);
            _deserializer = new Deserializer<CompactBinaryReader<InputBuffer>>(t);
            _serializerStream = new Serializer<CompactBinaryWriter<OutputStream>>(t);
            _deserializerStream = new Deserializer<CompactBinaryReader<InputStream>>(t);
            JustInitialized = false;
        }

        public override string Name => "MS Bond Compact";

        public override string Serialize(object serializable)
        {
            Ensure();
            var output = new OutputBuffer(2 * 1024);
            var writer = new CompactBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize(Payload(serializable), writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public override object Deserialize(string serialized)
        {
            Ensure();
            var bytes = Convert.FromBase64String(serialized);
            var input = new InputBuffer(bytes);
            var reader = new CompactBinaryReader<InputBuffer>(input);
            return _deserializer.Deserialize(reader);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Ensure();
            var output = new OutputStream(outputStream);
            var writer = new CompactBinaryWriter<OutputStream>(output);
            _serializerStream.Serialize(Payload(serializable), writer);
            output.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            Ensure();
            inputStream.Seek(0, SeekOrigin.Begin);
            var input = new InputStream(inputStream);
            var reader = new CompactBinaryReader<InputStream>(input);
            return _deserializerStream.Deserialize(reader);
        }
    }
}
