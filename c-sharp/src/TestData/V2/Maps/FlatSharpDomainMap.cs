using System;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;

namespace GLD.SerializerBenchmark.TestData.V2.Maps
{
    /// <summary>Suite domain ↔ FlatSharp table contracts (Fs*).</summary>
    internal sealed class FlatSharpDomainMap : IDomainNativeMap
    {
        public DomainNativeBinding Resolve(Type domainRootType)
        {
            if (domainRootType == typeof(Message))
                return Bind(typeof(FsMessage), Array.Empty<Type>(),
                    o => ToFs((Message)o), o => FromFs((FsMessage)o));
            if (domainRootType == typeof(Document))
                return Bind(typeof(FsDocument), new[] { typeof(FsDocumentMeta), typeof(FsDocumentItem) },
                    o => ToFs((Document)o), o => FromFs((FsDocument)o));
            if (domainRootType == typeof(Telemetry))
                return Bind(typeof(FsTelemetry), Array.Empty<Type>(),
                    o => ToFs((Telemetry)o), o => FromFs((FsTelemetry)o));
            if (domainRootType == typeof(Strings))
                return Bind(typeof(FsStrings), Array.Empty<Type>(),
                    o => ToFs((Strings)o), o => FromFs((FsStrings)o));
            if (domainRootType == typeof(Event))
                return Bind(typeof(FsEvent), new[] { typeof(FsEventAttr) },
                    o => ToFs((Event)o), o => FromFs((FsEvent)o));
            if (domainRootType == typeof(BatchMessage))
                return Bind(typeof(FsBatchMessage), new[] { typeof(FsMessage) },
                    o => new FsBatchMessage { Items = ((BatchMessage)o).Items.Select(ToFs).ToList() },
                    o => new BatchMessage { Items = ((FsBatchMessage)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(BatchDocument))
                return Bind(typeof(FsBatchDocument), new[] { typeof(FsDocument), typeof(FsDocumentMeta), typeof(FsDocumentItem) },
                    o => new FsBatchDocument { Items = ((BatchDocument)o).Items.Select(ToFs).ToList() },
                    o => new BatchDocument { Items = ((FsBatchDocument)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(BatchTelemetry))
                return Bind(typeof(FsBatchTelemetry), new[] { typeof(FsTelemetry) },
                    o => new FsBatchTelemetry { Items = ((BatchTelemetry)o).Items.Select(ToFs).ToList() },
                    o => new BatchTelemetry { Items = ((FsBatchTelemetry)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(BatchStrings))
                return Bind(typeof(FsBatchStrings), new[] { typeof(FsStrings) },
                    o => new FsBatchStrings { Items = ((BatchStrings)o).Items.Select(ToFs).ToList() },
                    o => new BatchStrings { Items = ((FsBatchStrings)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(BatchEvent))
                return Bind(typeof(FsBatchEvent), new[] { typeof(FsEvent), typeof(FsEventAttr) },
                    o => new FsBatchEvent { Items = ((BatchEvent)o).Items.Select(ToFs).ToList() },
                    o => new BatchEvent { Items = ((FsBatchEvent)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(TableRow))
                return Bind(typeof(FsTable), Array.Empty<Type>(),
                    o => ToFs((TableRow)o), o => FromFs((FsTable)o));
            if (domainRootType == typeof(BatchTable))
                return Bind(typeof(FsBatchTable), new[] { typeof(FsTable) },
                    o => new FsBatchTable { Items = ((BatchTable)o).Items.Select(ToFs).ToList() },
                    o => new BatchTable { Items = ((FsBatchTable)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(NestedRow))
                return Bind(typeof(FsNestedRow), new[] { typeof(FsNestedMeta), typeof(FsNestedItem) },
                    o => ToFs((NestedRow)o), o => FromFs((FsNestedRow)o));
            if (domainRootType == typeof(BatchNestedRow))
                return Bind(typeof(FsBatchNestedRow), new[] { typeof(FsNestedRow), typeof(FsNestedMeta), typeof(FsNestedItem) },
                    o => new FsBatchNestedRow { Items = ((BatchNestedRow)o).Items.Select(ToFs).ToList() },
                    o => new BatchNestedRow { Items = ((FsBatchNestedRow)o).Items.Select(FromFs).ToList() });
            if (domainRootType == typeof(Signal))
                return Bind(typeof(FsSignal), new[] { typeof(FsSignalLeg) },
                    o => ToFs((Signal)o), o => FromFs((FsSignal)o));
            if (domainRootType == typeof(BatchSignal))
                return Bind(typeof(FsBatchSignal), new[] { typeof(FsSignal), typeof(FsSignalLeg) },
                    o => new FsBatchSignal { Items = ((BatchSignal)o).Items.Select(ToFs).ToList() },
                    o => new BatchSignal { Items = ((FsBatchSignal)o).Items.Select(FromFs).ToList() });
            throw new NotSupportedException($"FlatSharp map: {domainRootType}");
        }

        static DomainNativeBinding Bind(Type native, Type[] sec, Func<object, object> toN, Func<object, object> toD)
            => new DomainNativeBinding
            {
                NativeRoot = native,
                NativeSecondary = sec,
                ToNative = toN,
                ToDomain = toD
            };

        static FsMessage ToFs(Message m) => new FsMessage
        {
            FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
            FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
        };
        static Message FromFs(FsMessage m) => new Message
        {
            FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
            FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
        };
        static FsDocument ToFs(Document d) => new FsDocument
        {
            Id = d.Id ?? "", Status = d.Status,
            Meta = new FsDocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 },
            Items = (d.Items ?? new List<DocumentItem>()).Select(i => new FsDocumentItem
            { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList()
        };
        static Document FromFs(FsDocument d) => new Document
        {
            Id = d.Id ?? "", Status = d.Status,
            Meta = new DocumentMeta { Region = d.Meta?.Region ?? "", Version = d.Meta?.Version ?? 0 },
            Items = (d.Items ?? new List<FsDocumentItem>()).Select(i => new DocumentItem
            { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList()
        };
        static FsTelemetry ToFs(Telemetry t) => new FsTelemetry
        {
            Source = t.Source ?? "", Ts = t.Ts,
            Tags = t.Tags?.ToList() ?? new List<string>(),
            Values = t.Values?.ToList() ?? new List<double>()
        };
        static Telemetry FromFs(FsTelemetry t) => new Telemetry
        {
            Source = t.Source ?? "", Ts = t.Ts,
            Tags = t.Tags?.ToList() ?? new List<string>(),
            Values = t.Values?.ToList() ?? new List<double>()
        };
        static FsStrings ToFs(Strings s) => new FsStrings { Items = s.Items?.ToList() ?? new List<string>() };
        static Strings FromFs(FsStrings s) => new Strings { Items = s.Items?.ToList() ?? new List<string>() };
        static FsEvent ToFs(Event e) => new FsEvent
        {
            EventId = e.EventId ?? "", EventType = e.EventType ?? "", OccurredAt = e.OccurredAt,
            Producer = e.Producer ?? "",
            Attrs = (e.Attrs ?? new List<EventAttr>()).Select(a => new FsEventAttr
            { Key = a.Key ?? "", Value = a.Value ?? "" }).ToList()
        };
        static Event FromFs(FsEvent e) => new Event
        {
            EventId = e.EventId ?? "", EventType = e.EventType ?? "", OccurredAt = e.OccurredAt,
            Producer = e.Producer ?? "",
            Attrs = (e.Attrs ?? new List<FsEventAttr>()).Select(a => new EventAttr
            { Key = a.Key ?? "", Value = a.Value ?? "" }).ToList()
        };

        static FsTable ToFs(TableRow row) => new FsTable
        {
            FFloat0 = row.FFloat0, FFloat1 = row.FFloat1, FFloat2 = row.FFloat2, FFloat3 = row.FFloat3,
            FFloat4 = row.FFloat4, FFloat5 = row.FFloat5, FFloat6 = row.FFloat6, FFloat7 = row.FFloat7,
            FFloat8 = row.FFloat8, FFloat9 = row.FFloat9, FFloat10 = row.FFloat10, FFloat11 = row.FFloat11,
            FFloat12 = row.FFloat12, FFloat13 = row.FFloat13, FFloat14 = row.FFloat14, FFloat15 = row.FFloat15,
            FInt0 = row.FInt0, FInt1 = row.FInt1, FInt2 = row.FInt2, FInt3 = row.FInt3,
            FStr0 = row.FStr0 ?? "", FStr1 = row.FStr1 ?? "",
        };
        static TableRow FromFs(FsTable row) => new TableRow
        {
            FFloat0 = row.FFloat0, FFloat1 = row.FFloat1, FFloat2 = row.FFloat2, FFloat3 = row.FFloat3,
            FFloat4 = row.FFloat4, FFloat5 = row.FFloat5, FFloat6 = row.FFloat6, FFloat7 = row.FFloat7,
            FFloat8 = row.FFloat8, FFloat9 = row.FFloat9, FFloat10 = row.FFloat10, FFloat11 = row.FFloat11,
            FFloat12 = row.FFloat12, FFloat13 = row.FFloat13, FFloat14 = row.FFloat14, FFloat15 = row.FFloat15,
            FInt0 = row.FInt0, FInt1 = row.FInt1, FInt2 = row.FInt2, FInt3 = row.FInt3,
            FStr0 = row.FStr0 ?? "", FStr1 = row.FStr1 ?? "",
        };
        static FsNestedRow ToFs(NestedRow row) => new FsNestedRow
        {
            Id = row.Id ?? "", Status = row.Status,
            Meta = new FsNestedMeta { Region = row.Meta?.Region ?? "", Version = row.Meta?.Version ?? 0 },
            Items = (row.Items ?? new List<NestedItem>()).Select(i => new FsNestedItem
            { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList(),
        };
        static NestedRow FromFs(FsNestedRow row) => new NestedRow
        {
            Id = row.Id ?? "", Status = row.Status,
            Meta = new NestedMeta { Region = row.Meta?.Region ?? "", Version = row.Meta?.Version ?? 0 },
            Items = (row.Items ?? new List<FsNestedItem>()).Select(i => new NestedItem
            { Sku = i.Sku ?? "", Qty = i.Qty, PriceMinor = i.PriceMinor }).ToList(),
        };
        static FsSignal ToFs(Signal s) => new FsSignal
        {
            Seq = s.Seq, Ts = s.Ts, PriceMantissa = s.PriceMantissa,
            Qty = s.Qty, Flags = s.Flags, Symbol = s.Symbol ?? "", Venue = s.Venue ?? "",
            Legs = (s.Legs ?? new List<SignalLeg>()).Select(l => new FsSignalLeg
            { LegId = l.LegId, LegQty = l.LegQty, LegPad = l.LegPad }).ToList(),
        };
        static Signal FromFs(FsSignal s) => new Signal
        {
            Seq = s.Seq, Ts = s.Ts, PriceMantissa = s.PriceMantissa,
            Qty = s.Qty, Flags = s.Flags, Symbol = s.Symbol ?? "", Venue = s.Venue ?? "",
            Legs = (s.Legs ?? new List<FsSignalLeg>()).Select(l => new SignalLeg
            { LegId = l.LegId, LegQty = l.LegQty, LegPad = l.LegPad }).ToList(),
        };
    }
}
