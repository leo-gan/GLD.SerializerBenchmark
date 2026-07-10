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
    }
}
