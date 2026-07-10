using System;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;

namespace GLD.SerializerBenchmark.TestData.V2.Maps
{
    /// <summary>
    /// Suite domain ↔ CsvHelper row lists. Only flat-ish types (message/event/strings).
    /// </summary>
    internal sealed class CsvHelperDomainMap : IDomainNativeMap
    {
        public DomainNativeBinding Resolve(Type domainRootType)
        {
            if (domainRootType == typeof(Message))
                return B(typeof(List<CsvFlatRow>),
                    o => new List<CsvFlatRow> { MapMsg((Message)o) },
                    o => UnmapMsg(((List<CsvFlatRow>)o)[0]));
            if (domainRootType == typeof(BatchMessage))
                return B(typeof(List<CsvFlatRow>),
                    o => ((BatchMessage)o).Items.Select(MapMsg).ToList(),
                    o => new BatchMessage { Items = ((List<CsvFlatRow>)o).Select(UnmapMsg).ToList() });
            if (domainRootType == typeof(Event))
                return B(typeof(List<CsvEventRow>),
                    o => new List<CsvEventRow> { MapEvt((Event)o) },
                    o => UnmapEvt(((List<CsvEventRow>)o)[0]));
            if (domainRootType == typeof(BatchEvent))
                return B(typeof(List<CsvEventRow>),
                    o => ((BatchEvent)o).Items.Select(MapEvt).ToList(),
                    o => new BatchEvent { Items = ((List<CsvEventRow>)o).Select(UnmapEvt).ToList() });
            if (domainRootType == typeof(Strings))
                return B(typeof(List<CsvStringRow>),
                    o => new List<CsvStringRow> { MapStr((Strings)o) },
                    o => UnmapStr(((List<CsvStringRow>)o)[0]));
            if (domainRootType == typeof(BatchStrings))
                return B(typeof(List<CsvStringRow>),
                    o => ((BatchStrings)o).Items.Select(MapStr).ToList(),
                    o => new BatchStrings { Items = ((List<CsvStringRow>)o).Select(UnmapStr).ToList() });
            throw new NotSupportedException($"CsvHelper map: {domainRootType.Name}");
        }

        static DomainNativeBinding B(Type native, Func<object, object> toN, Func<object, object> toD)
            => new DomainNativeBinding { NativeRoot = native, ToNative = toN, ToDomain = toD };

        static CsvFlatRow MapMsg(Message m) => new CsvFlatRow
        {
            FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
            FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
        };
        static Message UnmapMsg(CsvFlatRow r) => new Message
        {
            FBool = r.FBool, FInt32 = r.FInt32, FInt64 = r.FInt64, FFloat64 = r.FFloat64,
            FString = r.FString ?? "", FBool2 = r.FBool2, FInt322 = r.FInt322, FString2 = r.FString2 ?? ""
        };
        static CsvEventRow MapEvt(Event e) => new CsvEventRow
        {
            EventId = e.EventId ?? "", EventType = e.EventType ?? "", OccurredAt = e.OccurredAt,
            Producer = e.Producer ?? "",
            Attrs = string.Join(";", (e.Attrs ?? new List<EventAttr>()).Select(a => $"{a.Key}={a.Value}"))
        };
        static Event UnmapEvt(CsvEventRow r) => new Event
        {
            EventId = r.EventId ?? "", EventType = r.EventType ?? "", OccurredAt = r.OccurredAt,
            Producer = r.Producer ?? "",
            Attrs = string.IsNullOrEmpty(r.Attrs)
                ? new List<EventAttr>()
                : r.Attrs.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries).Select(p =>
                {
                    var i = p.IndexOf('=');
                    return i < 0
                        ? new EventAttr { Key = p, Value = "" }
                        : new EventAttr { Key = p.Substring(0, i), Value = p.Substring(i + 1) };
                }).ToList()
        };
        static CsvStringRow MapStr(Strings s) => new CsvStringRow
        {
            Items = string.Join("\u001f", s.Items ?? new List<string>())
        };
        static Strings UnmapStr(CsvStringRow r) => new Strings
        {
            Items = string.IsNullOrEmpty(r.Items)
                ? new List<string>()
                : r.Items.Split('\u001f').ToList()
        };
    }
}
