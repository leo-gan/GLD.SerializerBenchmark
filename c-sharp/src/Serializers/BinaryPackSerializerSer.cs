using System;
using System.IO;
using BinaryPack;
using GLD.SerializerBenchmark.TestData.V2;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// BinaryPack official API: BinaryConverter.Serialize/Deserialize&lt;T&gt; on the domain model
    /// (no JSON envelope). Requires public get/set properties and parameterless ctor.
    /// https://github.com/Sergio0694/BinaryPack
    /// </summary>
    internal class BinaryPackSerializerSer : SerDeser
    {
        public override string Name => "BinaryPack";
        public override bool Supports(string testDataName) => true;

        public override string Serialize(object serializable)
            => Convert.ToBase64String(SerializeBytes(serializable));

        public override object Deserialize(string serialized)
            => DeserializeBytes(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
            => SerializeToStream(serializable, outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return DeserializeFromStream(inputStream);
        }

        static byte[] SerializeBytes(object serializable) => serializable switch
        {
            Message m => BinaryConverter.Serialize(m),
            Document d => BinaryConverter.Serialize(d),
            Telemetry t => BinaryConverter.Serialize(t),
            Strings s => BinaryConverter.Serialize(s),
            Event e => BinaryConverter.Serialize(e),
            BatchMessage b => BinaryConverter.Serialize(b),
            BatchDocument b => BinaryConverter.Serialize(b),
            BatchTelemetry b => BinaryConverter.Serialize(b),
            BatchStrings b => BinaryConverter.Serialize(b),
            BatchEvent b => BinaryConverter.Serialize(b),
            DocumentMeta m => BinaryConverter.Serialize(m),
            DocumentItem i => BinaryConverter.Serialize(i),
            EventAttr a => BinaryConverter.Serialize(a),
            _ => throw new NotSupportedException($"BinaryPack: unsupported type {serializable?.GetType()}"),
        };

        static void SerializeToStream(object serializable, Stream outputStream)
        {
            switch (serializable)
            {
                case Message m: BinaryConverter.Serialize(m, outputStream); break;
                case Document d: BinaryConverter.Serialize(d, outputStream); break;
                case Telemetry t: BinaryConverter.Serialize(t, outputStream); break;
                case Strings s: BinaryConverter.Serialize(s, outputStream); break;
                case Event e: BinaryConverter.Serialize(e, outputStream); break;
                case BatchMessage b: BinaryConverter.Serialize(b, outputStream); break;
                case BatchDocument b: BinaryConverter.Serialize(b, outputStream); break;
                case BatchTelemetry b: BinaryConverter.Serialize(b, outputStream); break;
                case BatchStrings b: BinaryConverter.Serialize(b, outputStream); break;
                case BatchEvent b: BinaryConverter.Serialize(b, outputStream); break;
                default:
                    var bytes = SerializeBytes(serializable);
                    outputStream.Write(bytes, 0, bytes.Length);
                    break;
            }
        }

        object DeserializeBytes(byte[] bytes)
        {
            if (_primaryType == typeof(Message)) return BinaryConverter.Deserialize<Message>(bytes);
            if (_primaryType == typeof(Document)) return BinaryConverter.Deserialize<Document>(bytes);
            if (_primaryType == typeof(Telemetry)) return BinaryConverter.Deserialize<Telemetry>(bytes);
            if (_primaryType == typeof(Strings)) return BinaryConverter.Deserialize<Strings>(bytes);
            if (_primaryType == typeof(Event)) return BinaryConverter.Deserialize<Event>(bytes);
            if (_primaryType == typeof(BatchMessage)) return BinaryConverter.Deserialize<BatchMessage>(bytes);
            if (_primaryType == typeof(BatchDocument)) return BinaryConverter.Deserialize<BatchDocument>(bytes);
            if (_primaryType == typeof(BatchTelemetry)) return BinaryConverter.Deserialize<BatchTelemetry>(bytes);
            if (_primaryType == typeof(BatchStrings)) return BinaryConverter.Deserialize<BatchStrings>(bytes);
            if (_primaryType == typeof(BatchEvent)) return BinaryConverter.Deserialize<BatchEvent>(bytes);
            throw new NotSupportedException($"BinaryPack: unsupported primary {_primaryType}");
        }

        object DeserializeFromStream(Stream inputStream)
        {
            if (_primaryType == typeof(Message)) return BinaryConverter.Deserialize<Message>(inputStream);
            if (_primaryType == typeof(Document)) return BinaryConverter.Deserialize<Document>(inputStream);
            if (_primaryType == typeof(Telemetry)) return BinaryConverter.Deserialize<Telemetry>(inputStream);
            if (_primaryType == typeof(Strings)) return BinaryConverter.Deserialize<Strings>(inputStream);
            if (_primaryType == typeof(Event)) return BinaryConverter.Deserialize<Event>(inputStream);
            if (_primaryType == typeof(BatchMessage)) return BinaryConverter.Deserialize<BatchMessage>(inputStream);
            if (_primaryType == typeof(BatchDocument)) return BinaryConverter.Deserialize<BatchDocument>(inputStream);
            if (_primaryType == typeof(BatchTelemetry)) return BinaryConverter.Deserialize<BatchTelemetry>(inputStream);
            if (_primaryType == typeof(BatchStrings)) return BinaryConverter.Deserialize<BatchStrings>(inputStream);
            if (_primaryType == typeof(BatchEvent)) return BinaryConverter.Deserialize<BatchEvent>(inputStream);
            throw new NotSupportedException($"BinaryPack: unsupported primary {_primaryType}");
        }
    }
}
