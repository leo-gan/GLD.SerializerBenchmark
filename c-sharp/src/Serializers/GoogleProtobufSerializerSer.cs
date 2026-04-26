using System;
using System.IO;

namespace GLD.SerializerBenchmark.Serializers
{
    // Google.Protobuf
    internal class GoogleProtobufSerializerSer : SerDeser
    {
        public override string Name => "Google.Protobuf";

        public override bool Supports(string testDataName)
        {
            // Google.Protobuf requires proto definitions and generated code
            // Only types implementing IMessage are supported
            return false;
        }

        public override string Serialize(object serializable) {
            if (serializable is Google.Protobuf.IMessage message) {
                return Convert.ToBase64String(Google.Protobuf.MessageExtensions.ToByteArray(message));
            }
            return ""; 
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
            if (serializable is Google.Protobuf.IMessage message) {
                Google.Protobuf.MessageExtensions.WriteTo(message, outputStream);
            }
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
