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
            nameof(Domain.TableRow) => typeof(Wire.Table),
            nameof(Domain.BatchTable) => typeof(Wire.BatchTable),
            nameof(Domain.NestedRow) => typeof(Wire.NestedRow),
            nameof(Domain.BatchNestedRow) => typeof(Wire.BatchNestedRow),
            nameof(Domain.Signal) => typeof(Wire.Signal),
            nameof(Domain.BatchSignal) => typeof(Wire.BatchSignal),
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
            Domain.TableRow row => ToTable(row),
            Domain.BatchTable b => new Wire.BatchTable { Items = { b.Items.Select(ToTable) } },
            Domain.NestedRow row => ToNested(row),
            Domain.BatchNestedRow b => new Wire.BatchNestedRow { Items = { b.Items.Select(ToNested) } },
            Domain.Signal s => ToSignal(s),
            Domain.BatchSignal b => new Wire.BatchSignal { Items = { b.Items.Select(ToSignal) } },
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
            Wire.Table row => FromTable(row),
            Wire.BatchTable b => new Domain.BatchTable { Items = b.Items.Select(FromTable).ToList() },
            Wire.NestedRow row => FromNested(row),
            Wire.BatchNestedRow b => new Domain.BatchNestedRow { Items = b.Items.Select(FromNested).ToList() },
            Wire.Signal s => FromSignal(s),
            Wire.BatchSignal b => new Domain.BatchSignal { Items = b.Items.Select(FromSignal).ToList() },
            _ => msg
        };

        static Wire.Table ToTable(Domain.TableRow row) => new Wire.Table
        {
            FFloat0 = row.FFloat0, FFloat1 = row.FFloat1, FFloat2 = row.FFloat2, FFloat3 = row.FFloat3,
            FFloat4 = row.FFloat4, FFloat5 = row.FFloat5, FFloat6 = row.FFloat6, FFloat7 = row.FFloat7,
            FFloat8 = row.FFloat8, FFloat9 = row.FFloat9, FFloat10 = row.FFloat10, FFloat11 = row.FFloat11,
            FFloat12 = row.FFloat12, FFloat13 = row.FFloat13, FFloat14 = row.FFloat14, FFloat15 = row.FFloat15,
            FInt0 = row.FInt0, FInt1 = row.FInt1, FInt2 = row.FInt2, FInt3 = row.FInt3,
            FStr0 = row.FStr0 ?? "", FStr1 = row.FStr1 ?? "",
        };

        static Domain.TableRow FromTable(Wire.Table row) => new Domain.TableRow
        {
            FFloat0 = row.FFloat0, FFloat1 = row.FFloat1, FFloat2 = row.FFloat2, FFloat3 = row.FFloat3,
            FFloat4 = row.FFloat4, FFloat5 = row.FFloat5, FFloat6 = row.FFloat6, FFloat7 = row.FFloat7,
            FFloat8 = row.FFloat8, FFloat9 = row.FFloat9, FFloat10 = row.FFloat10, FFloat11 = row.FFloat11,
            FFloat12 = row.FFloat12, FFloat13 = row.FFloat13, FFloat14 = row.FFloat14, FFloat15 = row.FFloat15,
            FInt0 = row.FInt0, FInt1 = row.FInt1, FInt2 = row.FInt2, FInt3 = row.FInt3,
            FStr0 = row.FStr0 ?? "", FStr1 = row.FStr1 ?? "",
        };

        static Wire.NestedRow ToNested(Domain.NestedRow row)
        {
            var m = new Wire.NestedRow
            {
                Id = row.Id ?? "",
                Status = row.Status,
                Meta = new Wire.NestedMeta { Region = row.Meta?.Region ?? "", Version = row.Meta?.Version ?? 0 },
            };
            foreach (var i in row.Items ?? Enumerable.Empty<Domain.NestedItem>())
                m.Items.Add(new Wire.NestedItem { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor });
            return m;
        }

        static Domain.NestedRow FromNested(Wire.NestedRow row) => new Domain.NestedRow
        {
            Id = row.Id ?? "",
            Status = row.Status,
            Meta = new Domain.NestedMeta { Region = row.Meta?.Region ?? "", Version = row.Meta?.Version ?? 0 },
            Items = row.Items.Select(i => new Domain.NestedItem { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList(),
        };

        static Wire.Signal ToSignal(Domain.Signal s)
        {
            var m = new Wire.Signal
            {
                Seq = s.Seq, Ts = s.Ts, PriceMantissa = s.PriceMantissa,
                Qty = s.Qty, Flags = s.Flags, Symbol = s.Symbol ?? "", Venue = s.Venue ?? "",
            };
            foreach (var leg in s.Legs ?? Enumerable.Empty<Domain.SignalLeg>())
                m.Legs.Add(new Wire.SignalLeg { LegId = leg.LegId, LegQty = leg.LegQty, LegPad = leg.LegPad });
            return m;
        }

        static Domain.Signal FromSignal(Wire.Signal s) => new Domain.Signal
        {
            Seq = s.Seq, Ts = s.Ts, PriceMantissa = s.PriceMantissa,
            Qty = s.Qty, Flags = s.Flags, Symbol = s.Symbol ?? "", Venue = s.Venue ?? "",
            Legs = s.Legs.Select(l => new Domain.SignalLeg { LegId = l.LegId, LegQty = l.LegQty, LegPad = l.LegPad }).ToList(),
        };
    }
}
