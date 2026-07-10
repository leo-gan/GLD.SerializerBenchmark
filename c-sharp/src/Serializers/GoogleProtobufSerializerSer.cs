using System;
using System.IO;
using Google.Protobuf;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark.Serializers
{
    internal class GoogleProtobufSerializerSer : SerDeser
    {
        private IMessage _native;
        private MessageParser _parser;

        public override string Name => "Google.Protobuf";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            var mt = ProtobufPayloadConverter.MessageTypeFor(serializablePrimaryType);
            var parserProp = mt.GetProperty("Parser", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
            _parser = (MessageParser)parserProp.GetValue(null);
            _native = null;
        }

        public override void PrepareData(object data)
        {
            _native = ProtobufPayloadConverter.ToMessage(data);
        }

        public override object ToDomain(object decoded) =>
            ProtobufPayloadConverter.FromMessage((IMessage)decoded);

        public override string Serialize(object serializable)
        {
            var msg = _native ?? ProtobufPayloadConverter.ToMessage(serializable);
            return Convert.ToBase64String(msg.ToByteArray());
        }

        public override object Deserialize(string serialized)
        {
            return _parser.ParseFrom(Convert.FromBase64String(serialized));
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            var msg = _native ?? ProtobufPayloadConverter.ToMessage(serializable);
            msg.WriteTo(outputStream);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _parser.ParseFrom(inputStream);
        }
    }
}
