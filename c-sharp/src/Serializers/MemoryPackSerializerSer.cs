using System;
using System.IO;
using GLD.SerializerBenchmark.TestData.V2;
using MemoryPack;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// MemoryPack best practice: [MemoryPackable] models + generic Serialize/Deserialize&lt;T&gt;
    /// (source-generated path). Avoid Serialize(Type, object) when the concrete T is known.
    /// https://github.com/Cysharp/MemoryPack
    /// </summary>
    internal class MemoryPackSerializerSer : SerDeser
    {
        public override string Name => "MemoryPack";
        public override bool Supports(string testDataName) => true;

        public override string Serialize(object serializable)
            => Convert.ToBase64String(SerializeBytes(serializable));

        public override object Deserialize(string serialized)
            => DeserializeBytes(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = SerializeBytes(serializable);
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return DeserializeBytes(ms.ToArray());
        }

        static byte[] SerializeBytes(object serializable) => serializable switch
        {
            Message m => MemoryPackSerializer.Serialize(m),
            Document d => MemoryPackSerializer.Serialize(d),
            Telemetry t => MemoryPackSerializer.Serialize(t),
            Strings s => MemoryPackSerializer.Serialize(s),
            Event e => MemoryPackSerializer.Serialize(e),
            BatchMessage b => MemoryPackSerializer.Serialize(b),
            BatchDocument b => MemoryPackSerializer.Serialize(b),
            BatchTelemetry b => MemoryPackSerializer.Serialize(b),
            BatchStrings b => MemoryPackSerializer.Serialize(b),
            BatchEvent b => MemoryPackSerializer.Serialize(b),
            DocumentMeta m => MemoryPackSerializer.Serialize(m),
            DocumentItem i => MemoryPackSerializer.Serialize(i),
            EventAttr a => MemoryPackSerializer.Serialize(a),
            _ => MemoryPackSerializer.Serialize(serializable.GetType(), serializable),
        };

        object DeserializeBytes(byte[] bytes)
        {
            if (_primaryType == typeof(Message)) return MemoryPackSerializer.Deserialize<Message>(bytes);
            if (_primaryType == typeof(Document)) return MemoryPackSerializer.Deserialize<Document>(bytes);
            if (_primaryType == typeof(Telemetry)) return MemoryPackSerializer.Deserialize<Telemetry>(bytes);
            if (_primaryType == typeof(Strings)) return MemoryPackSerializer.Deserialize<Strings>(bytes);
            if (_primaryType == typeof(Event)) return MemoryPackSerializer.Deserialize<Event>(bytes);
            if (_primaryType == typeof(BatchMessage)) return MemoryPackSerializer.Deserialize<BatchMessage>(bytes);
            if (_primaryType == typeof(BatchDocument)) return MemoryPackSerializer.Deserialize<BatchDocument>(bytes);
            if (_primaryType == typeof(BatchTelemetry)) return MemoryPackSerializer.Deserialize<BatchTelemetry>(bytes);
            if (_primaryType == typeof(BatchStrings)) return MemoryPackSerializer.Deserialize<BatchStrings>(bytes);
            if (_primaryType == typeof(BatchEvent)) return MemoryPackSerializer.Deserialize<BatchEvent>(bytes);
            return MemoryPackSerializer.Deserialize(_primaryType, bytes);
        }
    }
}
