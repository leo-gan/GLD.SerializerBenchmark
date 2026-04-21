using System;
using System.IO;
using System.Collections.Generic;
using System.Text;

namespace GLD.SerializerBenchmark.Serializers
{
    // Apex.Serialization
    internal class ApexSerializerSer : SerDeser
    {
        private static readonly Apex.Serialization.IBinary _serializer = Apex.Serialization.Binary.Create();
        public override string Name => "Apex.Serialization";
        public override string Serialize(object serializable) {
            using var ms = new MemoryStream();
            _serializer.Write(serializable, ms);
            return Convert.ToBase64String(ms.ToArray());
        }
        public override object Deserialize(string serialized) {
            using var ms = new MemoryStream(Convert.FromBase64String(serialized));
            return _serializer.Read<object>(ms);
        }
        public override void Serialize(object serializable, Stream outputStream) {
            _serializer.Write(serializable, outputStream);
        }
        public override object Deserialize(Stream inputStream) {
            return _serializer.Read<object>(inputStream);
        }
    }

    // CsvHelper
    internal class CsvHelperSerializerSer : SerDeser
    {
        public override string Name => "CsvHelper";
        public override string Serialize(object serializable) {
            // CsvHelper doesn't natively serialize "object" generically easily, it requires enumerable.
            return ""; 
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }

    // FlatSharp
    internal class FlatSharpSerializerSer : SerDeser
    {
        public override string Name => "FlatSharp";
        public override string Serialize(object serializable) {
            return ""; // Needs schema / interface
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }

    // FluentSerializer.Json
    internal class FluentSerializerJsonSer : SerDeser
    {
        public override string Name => "FluentSerializer";
        public override string Serialize(object serializable) {
            // FluentSerializer requires mappings
            return ""; 
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }

    // Google.Protobuf
    internal class GoogleProtobufSerializerSer : SerDeser
    {
        public override string Name => "Google.Protobuf";
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

    // NetSerializer
    internal class NetSerializerSer : SerDeser
    {
        public override string Name => "NetSerializer";
        public override string Serialize(object serializable) {
            var serializer = new NetSerializer.Serializer(new[] { serializable.GetType() });
            using var ms = new MemoryStream();
            serializer.Serialize(ms, serializable);
            return Convert.ToBase64String(ms.ToArray());
        }
        public override object Deserialize(string serialized) {
            return null;
        }
        public override void Serialize(object serializable, Stream outputStream) {
            var serializer = new NetSerializer.Serializer(new[] { serializable.GetType() });
            serializer.Serialize(outputStream, serializable);
        }
        public override object Deserialize(Stream inputStream) {
            return null;
        }
    }
}
