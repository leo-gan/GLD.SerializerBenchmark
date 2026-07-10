using System;
using System.IO;
using System.Linq;
using Google.Protobuf;
using Domain = GLD.SerializerBenchmark.TestData.V2;
using Pb = Benchmark.V2;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Google.Protobuf needs IMessage. Domain is V2 models; PrepareData builds the
    /// matching generated message (same fields as models / benchmark_v2.proto).
    /// </summary>
    internal class GoogleProtobufSerializerSer : SerDeser
    {
        private IMessage _wire;
        private MessageParser _parser;

        public override string Name => "Google.Protobuf";
        public override bool Supports(string testDataName) => true;

        public override void Initialize(Type serializablePrimaryType, System.Collections.Generic.List<Type> serializableSecondaryTypes = null)
        {
            base.Initialize(serializablePrimaryType, serializableSecondaryTypes);
            var mt = WireClrType(serializablePrimaryType);
            _parser = (MessageParser)mt.GetProperty("Parser").GetValue(null);
            _wire = null;
        }

        public override void PrepareData(object data) => _wire = ToWire(data);
        public override object ToDomain(object decoded) => FromWire((IMessage)decoded);

        public override string Serialize(object serializable)
            => Convert.ToBase64String((_wire ?? ToWire(serializable)).ToByteArray());

        public override object Deserialize(string serialized)
            => _parser.ParseFrom(Convert.FromBase64String(serialized));

        public override void Serialize(object serializable, Stream outputStream)
            => (_wire ?? ToWire(serializable)).WriteTo(outputStream);

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            return _parser.ParseFrom(inputStream);
        }

        static Type WireClrType(Type domain) => domain.Name switch
        {
            nameof(Domain.Message) => typeof(Pb.Message),
            nameof(Domain.Document) => typeof(Pb.Document),
            nameof(Domain.Telemetry) => typeof(Pb.Telemetry),
            nameof(Domain.Strings) => typeof(Pb.Strings),
            nameof(Domain.Event) => typeof(Pb.Event),
            nameof(Domain.BatchMessage) => typeof(Pb.BatchMessage),
            nameof(Domain.BatchDocument) => typeof(Pb.BatchDocument),
            nameof(Domain.BatchTelemetry) => typeof(Pb.BatchTelemetry),
            nameof(Domain.BatchStrings) => typeof(Pb.BatchStrings),
            nameof(Domain.BatchEvent) => typeof(Pb.BatchEvent),
            _ => throw new NotSupportedException(domain.FullName)
        };

        static IMessage ToWire(object data) => data switch
        {
            Domain.Message m => new Pb.Message
            {
                FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
                FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
            },
            Domain.Document d => ToDoc(d),
            Domain.Telemetry t => ToTel(t),
            Domain.Strings s => new Pb.Strings { Items = { s.Items ?? Enumerable.Empty<string>() } },
            Domain.Event e => ToEvt(e),
            Domain.BatchMessage b => new Pb.BatchMessage { Items = { b.Items.Select(x => (Pb.Message)ToWire(x)) } },
            Domain.BatchDocument b => new Pb.BatchDocument { Items = { b.Items.Select(ToDoc) } },
            Domain.BatchTelemetry b => new Pb.BatchTelemetry { Items = { b.Items.Select(ToTel) } },
            Domain.BatchStrings b => new Pb.BatchStrings
            {
                Items = { b.Items.Select(x => new Pb.Strings { Items = { x.Items ?? Enumerable.Empty<string>() } }) }
            },
            Domain.BatchEvent b => new Pb.BatchEvent { Items = { b.Items.Select(ToEvt) } },
            _ => throw new NotSupportedException(data?.GetType().FullName)
        };

        static Pb.Document ToDoc(Domain.Document d)
        {
            var doc = new Pb.Document
            {
                Id = d.Id ?? "",
                Status = d.Status,
                Meta = new Pb.DocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 }
            };
            foreach (var i in d.Items ?? Enumerable.Empty<Domain.DocumentItem>())
                doc.Items.Add(new Pb.DocumentItem { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor });
            return doc;
        }

        static Pb.Telemetry ToTel(Domain.Telemetry t)
        {
            var m = new Pb.Telemetry { Source = t.Source ?? "", Ts = t.Ts };
            m.Tags.AddRange(t.Tags ?? Enumerable.Empty<string>());
            m.Values.AddRange(t.Values ?? Enumerable.Empty<double>());
            return m;
        }

        static Pb.Event ToEvt(Domain.Event e)
        {
            var m = new Pb.Event
            {
                EventId = e.EventId ?? "", EventType = e.EventType ?? "",
                OccurredAt = e.OccurredAt, Producer = e.Producer ?? ""
            };
            foreach (var a in e.Attrs ?? Enumerable.Empty<Domain.EventAttr>())
                m.Attrs.Add(new Pb.EventAttr { Key = a.Key ?? "", Value = a.Value ?? "" });
            return m;
        }

        object FromWire(IMessage msg) => msg switch
        {
            Pb.Message m => new Domain.Message
            {
                FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
                FString = m.FString, FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2
            },
            Pb.Document d => new Domain.Document
            {
                Id = d.Id, Status = d.Status,
                Meta = new Domain.DocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 },
                Items = d.Items.Select(i => new Domain.DocumentItem { Sku = i.Sku, Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList()
            },
            Pb.Telemetry t => new Domain.Telemetry
            {
                Source = t.Source, Ts = t.Ts, Tags = t.Tags.ToList(), Values = t.Values.ToList()
            },
            Pb.Strings s => new Domain.Strings { Items = s.Items.ToList() },
            Pb.Event e => new Domain.Event
            {
                EventId = e.EventId, EventType = e.EventType, OccurredAt = e.OccurredAt, Producer = e.Producer,
                Attrs = e.Attrs.Select(a => new Domain.EventAttr { Key = a.Key, Value = a.Value }).ToList()
            },
            Pb.BatchMessage b => new Domain.BatchMessage { Items = b.Items.Select(x => (Domain.Message)FromWire(x)).ToList() },
            Pb.BatchDocument b => new Domain.BatchDocument { Items = b.Items.Select(x => (Domain.Document)FromWire(x)).ToList() },
            Pb.BatchTelemetry b => new Domain.BatchTelemetry { Items = b.Items.Select(x => (Domain.Telemetry)FromWire(x)).ToList() },
            Pb.BatchStrings b => new Domain.BatchStrings { Items = b.Items.Select(x => (Domain.Strings)FromWire(x)).ToList() },
            Pb.BatchEvent b => new Domain.BatchEvent { Items = b.Items.Select(x => (Domain.Event)FromWire(x)).ToList() },
            _ => msg
        };
    }
}
