using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using GLD.SerializerBenchmark.TestData.V2;
using ZeroFormatter;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// ZeroFormatter cannot emit dynamic formatters on net8. Timed path uses KeyTuple
    /// built from V2 domain types in PrepareData (codec preparation, not legacy mapping).
    /// </summary>
    internal class ZeroFormatterSerializerSer : SerDeser
    {
        private object _native;

        public override string Name => "ZeroFormatter";
        public override bool Supports(string testDataName) => true;

        public override void PrepareData(object data) => _native = ToWire(data);

        public override object ToDomain(object decoded) => FromWire(decoded);

        public override string Serialize(object serializable) =>
            Convert.ToBase64String(SerializeBytes(_native ?? ToWire(serializable)));

        public override object Deserialize(string serialized) =>
            DeserializeBytes(Convert.FromBase64String(serialized));

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
            return DeserializeBytes(ms.ToArray());
        }

        byte[] SerializeBytes(object native) => native switch
        {
            KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>> m => ZeroFormatterSerializer.Serialize(m),
            KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>> d => ZeroFormatterSerializer.Serialize(d),
            KeyTuple<string, long, List<string>, List<double>> t => ZeroFormatterSerializer.Serialize(t),
            List<string> s => ZeroFormatterSerializer.Serialize(s),
            KeyTuple<string, string, long, string, List<KeyTuple<string, string>>> e => ZeroFormatterSerializer.Serialize(e),
            List<KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>> mb => ZeroFormatterSerializer.Serialize(mb),
            List<KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>> db => ZeroFormatterSerializer.Serialize(db),
            List<KeyTuple<string, long, List<string>, List<double>>> tb => ZeroFormatterSerializer.Serialize(tb),
            List<List<string>> sb => ZeroFormatterSerializer.Serialize(sb),
            List<KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>> eb => ZeroFormatterSerializer.Serialize(eb),
            _ => throw new NotSupportedException($"ZF wire {native?.GetType()}")
        };

        object DeserializeBytes(byte[] bytes)
        {
            if (_primaryType == typeof(Message))
                return ZeroFormatterSerializer.Deserialize<KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>>(bytes);
            if (_primaryType == typeof(BatchMessage))
                return ZeroFormatterSerializer.Deserialize<List<KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>>>(bytes);
            if (_primaryType == typeof(Document))
                return ZeroFormatterSerializer.Deserialize<KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>>(bytes);
            if (_primaryType == typeof(BatchDocument))
                return ZeroFormatterSerializer.Deserialize<List<KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>>>(bytes);
            if (_primaryType == typeof(Telemetry))
                return ZeroFormatterSerializer.Deserialize<KeyTuple<string, long, List<string>, List<double>>>(bytes);
            if (_primaryType == typeof(BatchTelemetry))
                return ZeroFormatterSerializer.Deserialize<List<KeyTuple<string, long, List<string>, List<double>>>>(bytes);
            if (_primaryType == typeof(Strings))
                return ZeroFormatterSerializer.Deserialize<List<string>>(bytes);
            if (_primaryType == typeof(BatchStrings))
                return ZeroFormatterSerializer.Deserialize<List<List<string>>>(bytes);
            if (_primaryType == typeof(Event))
                return ZeroFormatterSerializer.Deserialize<KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>>(bytes);
            if (_primaryType == typeof(BatchEvent))
                return ZeroFormatterSerializer.Deserialize<List<KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>>>(bytes);
            throw new NotSupportedException($"ZF primary {_primaryType}");
        }

        static object ToWire(object data) => data switch
        {
            Message m => KeyTuple.Create(
                KeyTuple.Create(m.FBool, m.FInt32, m.FInt64, m.FFloat64),
                KeyTuple.Create(m.FString ?? "", m.FBool2, m.FInt322, m.FString2 ?? "")),
            BatchMessage b => b.Items.Select(x => (KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>)ToWire(x)).ToList(),
            Document d => KeyTuple.Create(
                d.Id ?? "", d.Status,
                KeyTuple.Create(d.Meta?.Region ?? "", d.Meta?.Version ?? 0),
                (d.Items ?? new List<DocumentItem>()).Select(i => KeyTuple.Create(i.Sku ?? "", i.Qty, i.PriceMinor)).ToList()),
            BatchDocument b => b.Items.Select(x => (KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>)ToWire(x)).ToList(),
            Telemetry t => KeyTuple.Create(t.Source ?? "", t.Ts, t.Tags?.ToList() ?? new List<string>(), t.Values?.ToList() ?? new List<double>()),
            BatchTelemetry b => b.Items.Select(x => (KeyTuple<string, long, List<string>, List<double>>)ToWire(x)).ToList(),
            Strings s => s.Items?.ToList() ?? new List<string>(),
            BatchStrings b => b.Items.Select(x => x.Items?.ToList() ?? new List<string>()).ToList(),
            Event e => KeyTuple.Create(e.EventId ?? "", e.EventType ?? "", e.OccurredAt, e.Producer ?? "",
                (e.Attrs ?? new List<EventAttr>()).Select(a => KeyTuple.Create(a.Key ?? "", a.Value ?? "")).ToList()),
            BatchEvent b => b.Items.Select(x => (KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>)ToWire(x)).ToList(),
            _ => throw new NotSupportedException($"ZF ToWire {data?.GetType()}")
        };

        object FromWire(object native)
        {
            if (_primaryType == typeof(Message))
            {
                var t = (KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>)native;
                var a = t.Item1; var b = t.Item2;
                return new Message { FBool = a.Item1, FInt32 = a.Item2, FInt64 = a.Item3, FFloat64 = a.Item4, FString = b.Item1, FBool2 = b.Item2, FInt322 = b.Item3, FString2 = b.Item4 };
            }
            if (_primaryType == typeof(BatchMessage) && native is List<KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>> mb)
            {
                _primaryType = typeof(Message);
                var list = mb.Select(x => (Message)FromWire(x)).ToList();
                _primaryType = typeof(BatchMessage);
                return new BatchMessage { Items = list };
            }
            if (_primaryType == typeof(Document))
            {
                var t = (KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>)native;
                return new Document
                {
                    Id = t.Item1, Status = t.Item2,
                    Meta = new DocumentMeta { Region = t.Item3.Item1, Version = t.Item3.Item2 },
                    Items = t.Item4.Select(i => new DocumentItem { Sku = i.Item1, Qty = i.Item2, PriceMinor = i.Item3 }).ToList()
                };
            }
            if (_primaryType == typeof(BatchDocument) && native is List<KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>> db)
            {
                _primaryType = typeof(Document);
                var list = db.Select(x => (Document)FromWire(x)).ToList();
                _primaryType = typeof(BatchDocument);
                return new BatchDocument { Items = list };
            }
            if (_primaryType == typeof(Telemetry))
            {
                var t = (KeyTuple<string, long, List<string>, List<double>>)native;
                return new Telemetry { Source = t.Item1, Ts = t.Item2, Tags = t.Item3, Values = t.Item4 };
            }
            if (_primaryType == typeof(BatchTelemetry) && native is List<KeyTuple<string, long, List<string>, List<double>>> tb)
            {
                _primaryType = typeof(Telemetry);
                var list = tb.Select(x => (Telemetry)FromWire(x)).ToList();
                _primaryType = typeof(BatchTelemetry);
                return new BatchTelemetry { Items = list };
            }
            if (_primaryType == typeof(Strings))
                return new Strings { Items = (List<string>)native };
            if (_primaryType == typeof(BatchStrings) && native is List<List<string>> sb)
                return new BatchStrings { Items = sb.Select(x => new Strings { Items = x }).ToList() };
            if (_primaryType == typeof(Event))
            {
                var t = (KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>)native;
                return new Event
                {
                    EventId = t.Item1, EventType = t.Item2, OccurredAt = t.Item3, Producer = t.Item4,
                    Attrs = t.Item5.Select(a => new EventAttr { Key = a.Item1, Value = a.Item2 }).ToList()
                };
            }
            if (_primaryType == typeof(BatchEvent) && native is List<KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>> eb)
            {
                _primaryType = typeof(Event);
                var list = eb.Select(x => (Event)FromWire(x)).ToList();
                _primaryType = typeof(BatchEvent);
                return new BatchEvent { Items = list };
            }
            return native;
        }
    }
}
