using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using Google.Protobuf;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Google.Protobuf on IMessage wires only. Domain mapping via injected map.
    /// https://github.com/protocolbuffers/protobuf
    /// </summary>
    internal class GoogleProtobufSerializerSer : MappedSerDeser
    {
        private MessageParser _parser;

        public GoogleProtobufSerializerSer(IDomainNativeMap map) : base(map) { }

        public override string Name => "Google.Protobuf";
        public override bool Supports(string testDataName) => true;

        protected override void OnNativeTypeReady(Type nativeRoot, List<Type> nativeSecondary)
        {
            var parserProp = nativeRoot.GetProperty("Parser", BindingFlags.Public | BindingFlags.Static);
            if (parserProp == null)
                throw new InvalidOperationException($"No Parser on {nativeRoot}");
            _parser = (MessageParser)parserProp.GetValue(null);
        }

        public override string Serialize(object serializable)
        {
            var msg = (IMessage)NativeOf(serializable);
            return Convert.ToBase64String(msg.ToByteArray());
        }

        public override object Deserialize(string serialized)
            => _parser.ParseFrom(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
            => ((IMessage)NativeOf(serializable)).WriteTo(outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _parser.ParseFrom(inputStream);
        }
    }
}
