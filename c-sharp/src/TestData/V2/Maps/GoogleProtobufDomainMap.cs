using System;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using Google.Protobuf;
using Domain = GLD.SerializerBenchmark.TestData.V2;
using Wire = Benchmark.V2;

namespace GLD.SerializerBenchmark.TestData.V2.Maps
{
    internal sealed class GoogleProtobufDomainMap : IDomainNativeMap
    {
        public DomainNativeBinding Resolve(Type domainRootType)
        {
            var native = WireClrType(domainRootType);
            return new DomainNativeBinding
            {
                NativeRoot = native,
                ToNative = ToWire,
                ToDomain = o => FromWire((IMessage)o)
            };
        }

        static Type WireClrType(Type domain) => domain.Name switch
        {
            nameof(Domain.Message) => typeof(Wire.Message),
            nameof(Domain.Document) => typeof(Wire.Document),
            nameof(Domain.Telemetry) => typeof(Wire.Telemetry),
            nameof(Domain.Strings) => typeof(Wire.Strings),
            nameof(Domain.Event) => typeof(Wire.Event),
            nameof(Domain.BatchMessage) => typeof(Wire.BatchMessage),
            nameof(Domain.BatchDocument) => typeof(Wire.BatchDocument),
            nameof(Domain.BatchTelemetry) => typeof(Wire.BatchTelemetry),
            nameof(Domain.BatchStrings) => typeof(Wire.BatchStrings),
            nameof(Domain.BatchEvent) => typeof(Wire.BatchEvent),
            _ => throw new NotSupportedException(domain.FullName)
        };

        static object ToWire(object data) => data switch
        {
            Domain.Message m => new Wire.Message
            {
                FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
                FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
            },
            Domain.Document d => ToDoc(d),
            Domain.Telemetry t => ToTel(t),
            Domain.Strings s => new Wire.Strings { Items = { s.Items ?? Enumerable.Empty<string>() } },
            Domain.Event e => ToEvt(e),
            Domain.BatchMessage b => new Wire.BatchMessage { Items = { b.Items.Select(x => (Wire.Message)ToWire(x)) } },
            Domain.BatchDocument b => new Wire.BatchDocument { Items = { b.Items.Select(ToDoc) } },
            Domain.BatchTelemetry b => new Wire.BatchTelemetry { Items = { b.Items.Select(ToTel) } },
            Domain.BatchStrings b => new Wire.BatchStrings
            {
                Items = { b.Items.Select(x => new Wire.Strings { Items = { x.Items ?? Enumerable.Empty<string>() } }) }
            },
            Domain.BatchEvent b => new Wire.BatchEvent { Items = { b.Items.Select(ToEvt) } },
            _ => throw new NotSupportedException(data?.GetType().FullName)
        };

        static Wire.Document ToDoc(Domain.Document d)
        {
            var doc = new Wire.Document
            {
                Id = d.Id ?? "",
                Status = d.Status,
                Meta = new Wire.DocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 }
            };
            foreach (var i in d.Items ?? Enumerable.Empty<Domain.DocumentItem>())
                doc.Items.Add(new Wire.DocumentItem { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor });
            return doc;
        }

        static Wire.Telemetry ToTel(Domain.Telemetry t)
        {
            var m = new Wire.Telemetry { Source = t.Source ?? "", Ts = t.Ts };
            m.Tags.AddRange(t.Tags ?? Enumerable.Empty<string>());
            m.Values.AddRange(t.Values ?? Enumerable.Empty<double>());
            return m;
        }

        static Wire.Event ToEvt(Domain.Event e)
        {
            var m = new Wire.Event
            {
                EventId = e.EventId ?? "", EventType = e.EventType ?? "",
                OccurredAt = e.OccurredAt, Producer = e.Producer ?? ""
            };
            foreach (var a in e.Attrs ?? Enumerable.Empty<Domain.EventAttr>())
                m.Attrs.Add(new Wire.EventAttr { Key = a.Key ?? "", Value = a.Value ?? "" });
            return m;
        }

        static object FromWire(IMessage msg) => msg switch
        {
            Wire.Message m => new Domain.Message
            {
                FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
                FString = m.FString, FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2
            },
            Wire.Document d => new Domain.Document
            {
                Id = d.Id, Status = d.Status,
                Meta = new Domain.DocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 },
                Items = d.Items.Select(i => new Domain.DocumentItem { Sku = i.Sku, Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList()
            },
            Wire.Telemetry t => new Domain.Telemetry
            {
                Source = t.Source, Ts = t.Ts, Tags = t.Tags.ToList(), Values = t.Values.ToList()
            },
            Wire.Strings s => new Domain.Strings { Items = s.Items.ToList() },
            Wire.Event e => new Domain.Event
            {
                EventId = e.EventId, EventType = e.EventType, OccurredAt = e.OccurredAt, Producer = e.Producer,
                Attrs = e.Attrs.Select(a => new Domain.EventAttr { Key = a.Key, Value = a.Value }).ToList()
            },
            Wire.BatchMessage b => new Domain.BatchMessage { Items = b.Items.Select(x => (Domain.Message)FromWire(x)).ToList() },
            Wire.BatchDocument b => new Domain.BatchDocument { Items = b.Items.Select(x => (Domain.Document)FromWire(x)).ToList() },
            Wire.BatchTelemetry b => new Domain.BatchTelemetry { Items = b.Items.Select(x => (Domain.Telemetry)FromWire(x)).ToList() },
            Wire.BatchStrings b => new Domain.BatchStrings { Items = b.Items.Select(x => (Domain.Strings)FromWire(x)).ToList() },
            Wire.BatchEvent b => new Domain.BatchEvent { Items = b.Items.Select(x => (Domain.Event)FromWire(x)).ToList() },
            _ => msg
        };
    }
}
