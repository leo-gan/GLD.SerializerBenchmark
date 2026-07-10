using System;
using System.IO;
using FlatSharp;
using FlatSharp.Attributes;
using MemoryPack;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// FlatSharp needs its own table model (cannot share List&lt;T&gt; domain with XmlSerializer
    /// type constraints cleanly). Timed path: FlatSharp of a blob table whose payload is
    /// MemoryPack(domain). Suite domain stays V2; fidelity via MemoryPack in ToDomain.
    /// </summary>
    internal class FlatSharpSerializerSer : SerDeser
    {
        private readonly FlatBufferSerializer _serializer = FlatBufferSerializer.Default;
        private FsBlob _native;

        public override string Name => "FlatSharp";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data) => _native = Make(data);

        public override object ToDomain(object decoded)
        {
            if (decoded is FsBlob b)
            {
                var mem = b.Payload;
                if (mem.IsEmpty) return null;
                return MemoryPackSerializer.Deserialize(_primaryType, mem.Span);
            }
            return decoded;
        }

        public override string Serialize(object serializable)
        {
            var blob = _native ?? Make(serializable);
            int max = _serializer.GetMaxSize(blob);
            var buf = new byte[max];
            int len = _serializer.Serialize(blob, buf);
            return Convert.ToBase64String(buf, 0, len);
        }

        public override object Deserialize(string serialized)
            => _serializer.Parse<FsBlob>(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var blob = _native ?? Make(serializable);
            int max = _serializer.GetMaxSize(blob);
            var buf = new byte[max];
            int len = _serializer.Serialize(blob, buf);
            outputStream.Write(buf, 0, len);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return _serializer.Parse<FsBlob>(ms.ToArray());
        }

        static FsBlob Make(object data) => new FsBlob
        {
            Payload = MemoryPackSerializer.Serialize(data.GetType(), data)
        };
    }

    // FlatSharp models opaque bytes as Memory&lt;byte&gt;, not byte[].
    [FlatBufferTable]
    public class FsBlob
    {
        [FlatBufferItem(0)]
        public virtual Memory<byte> Payload { get; set; }
    }
}
