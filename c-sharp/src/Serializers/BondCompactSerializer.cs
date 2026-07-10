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
            _serializer = new Serializer<CompactBinaryWriter<OutputBuffer>>(_primaryType);
            _deserializer = new Deserializer<CompactBinaryReader<InputBuffer>>(_primaryType);
            _serializerStream = new Serializer<CompactBinaryWriter<OutputStream>>(_primaryType);
            _deserializerStream = new Deserializer<CompactBinaryReader<InputStream>>(_primaryType);
            JustInitialized = false;
        }

        public override string Name => "MS Bond Compact";

        public override string Serialize(object serializable)
        {
            Ensure();
            var output = new OutputBuffer(2 * 1024);
            var writer = new CompactBinaryWriter<OutputBuffer>(output);
            _serializer.Serialize(serializable, writer);
            return Convert.ToBase64String(output.Data.Array, output.Data.Offset, output.Data.Count);
        }

        public override object Deserialize(string serialized)
        {
            Ensure();
            var input = new InputBuffer(Convert.FromBase64String(serialized));
            return _deserializer.Deserialize(new CompactBinaryReader<InputBuffer>(input));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            Ensure();
            var output = new OutputStream(outputStream);
            _serializerStream.Serialize(serializable, new CompactBinaryWriter<OutputStream>(output));
            output.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            Ensure();
            inputStream.Seek(0, SeekOrigin.Begin);
            return _deserializerStream.Deserialize(new CompactBinaryReader<InputStream>(new InputStream(inputStream)));
        }
    }
}
