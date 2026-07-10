using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using FlatSharp;
using FlatSharp.Attributes;
using GLD.SerializerBenchmark.TestData.V2;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// FlatSharp official path: [FlatBufferTable] models + FlatBufferSerializer.Serialize/Parse.
    /// PrepareData maps suite V2 domain → FlatSharp tables (untimed); timed path is pure FlatSharp.
    /// https://github.com/jamescourtney/FlatSharp
    /// </summary>
    internal class FlatSharpSerializerSer : SerDeser
    {
        private readonly FlatBufferSerializer _serializer = FlatBufferSerializer.Default;
        private object _native; // FlatSharp table root

        public override string Name => "FlatSharp";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data) => _native = ToWire(data);

        public override object ToDomain(object decoded) => FromWire(decoded);

        public override string Serialize(object serializable)
        {
            var root = _native ?? ToWire(serializable);
            return Convert.ToBase64String(SerializeBytes(root));
        }

        public override object Deserialize(string serialized)
            => ParseBytes(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
        {
            var bytes = SerializeBytes(_native ?? ToWire(serializable));
            outputStream.Write(bytes, 0, bytes.Length);
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var ms = new MemoryStream();
            inputStream.CopyTo(ms);
            return ParseBytes(ms.ToArray());
        }

        byte[] SerializeBytes(object root)
        {
            // FlatSharp API: GetMaxSize + Serialize into pre-sized buffer.
            int max = root switch
            {
                FsMessage m => _serializer.GetMaxSize(m),
                FsDocument d => _serializer.GetMaxSize(d),
                FsTelemetry t => _serializer.GetMaxSize(t),
                FsStrings s => _serializer.GetMaxSize(s),
                FsEvent e => _serializer.GetMaxSize(e),
                FsBatchMessage b => _serializer.GetMaxSize(b),
                FsBatchDocument b => _serializer.GetMaxSize(b),
                FsBatchTelemetry b => _serializer.GetMaxSize(b),
                FsBatchStrings b => _serializer.GetMaxSize(b),
                FsBatchEvent b => _serializer.GetMaxSize(b),
                _ => throw new NotSupportedException($"FlatSharp root {root?.GetType()}")
            };
            var buf = new byte[max];
            int len = root switch
            {
                FsMessage m => _serializer.Serialize(m, buf),
                FsDocument d => _serializer.Serialize(d, buf),
                FsTelemetry t => _serializer.Serialize(t, buf),
                FsStrings s => _serializer.Serialize(s, buf),
                FsEvent e => _serializer.Serialize(e, buf),
                FsBatchMessage b => _serializer.Serialize(b, buf),
                FsBatchDocument b => _serializer.Serialize(b, buf),
                FsBatchTelemetry b => _serializer.Serialize(b, buf),
                FsBatchStrings b => _serializer.Serialize(b, buf),
                FsBatchEvent b => _serializer.Serialize(b, buf),
                _ => throw new NotSupportedException($"FlatSharp root {root?.GetType()}")
            };
            if (len == buf.Length) return buf;
            var exact = new byte[len];
            Buffer.BlockCopy(buf, 0, exact, 0, len);
            return exact;
        }

        object ParseBytes(byte[] bytes)
        {
            if (_primaryType == typeof(Message) || _primaryType == typeof(FsMessage))
                return _serializer.Parse<FsMessage>(bytes);
            if (_primaryType == typeof(Document)) return _serializer.Parse<FsDocument>(bytes);
            if (_primaryType == typeof(Telemetry)) return _serializer.Parse<FsTelemetry>(bytes);
            if (_primaryType == typeof(Strings)) return _serializer.Parse<FsStrings>(bytes);
            if (_primaryType == typeof(Event)) return _serializer.Parse<FsEvent>(bytes);
            if (_primaryType == typeof(BatchMessage)) return _serializer.Parse<FsBatchMessage>(bytes);
            if (_primaryType == typeof(BatchDocument)) return _serializer.Parse<FsBatchDocument>(bytes);
            if (_primaryType == typeof(BatchTelemetry)) return _serializer.Parse<FsBatchTelemetry>(bytes);
            if (_primaryType == typeof(BatchStrings)) return _serializer.Parse<FsBatchStrings>(bytes);
            if (_primaryType == typeof(BatchEvent)) return _serializer.Parse<FsBatchEvent>(bytes);
            throw new NotSupportedException($"FlatSharp primary {_primaryType}");
        }

        static object ToWire(object data) => data switch
        {
            Message m => new FsMessage
            {
                FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
                FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
            },
            Document d => new FsDocument
            {
                Id = d.Id ?? "", Status = d.Status,
                Meta = new FsDocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 },
                Items = (d.Items ?? new List<DocumentItem>()).Select(i => new FsDocumentItem
                {
                    Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor
                }).ToList()
            },
            Telemetry t => new FsTelemetry
            {
                Source = t.Source ?? "", Ts = t.Ts,
                Tags = t.Tags?.ToList() ?? new List<string>(),
                Values = t.Values?.ToList() ?? new List<double>()
            },
            Strings s => new FsStrings { Items = s.Items?.ToList() ?? new List<string>() },
            Event e => new FsEvent
            {
                EventId = e.EventId ?? "", EventType = e.EventType ?? "", OccurredAt = e.OccurredAt,
                Producer = e.Producer ?? "",
                Attrs = (e.Attrs ?? new List<EventAttr>()).Select(a => new FsEventAttr
                {
                    Key = a.Key ?? "", Value = a.Value ?? ""
                }).ToList()
            },
            BatchMessage b => new FsBatchMessage { Items = b.Items.Select(x => (FsMessage)ToWire(x)).ToList() },
            BatchDocument b => new FsBatchDocument { Items = b.Items.Select(x => (FsDocument)ToWire(x)).ToList() },
            BatchTelemetry b => new FsBatchTelemetry { Items = b.Items.Select(x => (FsTelemetry)ToWire(x)).ToList() },
            BatchStrings b => new FsBatchStrings { Items = b.Items.Select(x => (FsStrings)ToWire(x)).ToList() },
            BatchEvent b => new FsBatchEvent { Items = b.Items.Select(x => (FsEvent)ToWire(x)).ToList() },
            _ => throw new NotSupportedException($"FlatSharp ToWire {data?.GetType()}")
        };

        object FromWire(object native) => native switch
        {
            FsMessage m => new Message
            {
                FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
                FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
            },
            FsDocument d => new Document
            {
                Id = d.Id ?? "", Status = d.Status,
                Meta = new DocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 },
                Items = (d.Items ?? new List<FsDocumentItem>()).Select(i => new DocumentItem
                {
                    Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor
                }).ToList()
            },
            FsTelemetry t => new Telemetry
            {
                Source = t.Source ?? "", Ts = t.Ts,
                Tags = t.Tags?.ToList() ?? new List<string>(),
                Values = t.Values?.ToList() ?? new List<double>()
            },
            FsStrings s => new Strings { Items = s.Items?.ToList() ?? new List<string>() },
            FsEvent e => new Event
            {
                EventId = e.EventId ?? "", EventType = e.EventType ?? "", OccurredAt = e.OccurredAt,
                Producer = e.Producer ?? "",
                Attrs = (e.Attrs ?? new List<FsEventAttr>()).Select(a => new EventAttr
                {
                    Key = a.Key ?? "", Value = a.Value ?? ""
                }).ToList()
            },
            FsBatchMessage b => new BatchMessage
            {
                Items = (b.Items ?? new List<FsMessage>()).Select(x => (Message)FromWire(x)).ToList()
            },
            FsBatchDocument b => new BatchDocument
            {
                Items = (b.Items ?? new List<FsDocument>()).Select(x => (Document)FromWire(x)).ToList()
            },
            FsBatchTelemetry b => new BatchTelemetry
            {
                Items = (b.Items ?? new List<FsTelemetry>()).Select(x => (Telemetry)FromWire(x)).ToList()
            },
            FsBatchStrings b => new BatchStrings
            {
                Items = (b.Items ?? new List<FsStrings>()).Select(x => (Strings)FromWire(x)).ToList()
            },
            FsBatchEvent b => new BatchEvent
            {
                Items = (b.Items ?? new List<FsEvent>()).Select(x => (Event)FromWire(x)).ToList()
            },
            _ => native
        };

        // ---- FlatSharp table models (virtual props required by FlatSharp) ----
    }
}
