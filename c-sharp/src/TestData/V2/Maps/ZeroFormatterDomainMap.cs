using System;
using System.Collections.Generic;
using System.Linq;
using GLD.SerializerBenchmark.Serializers;
using ZeroFormatter;

namespace GLD.SerializerBenchmark.TestData.V2.Maps
{
    /// <summary>
    /// Suite domain ↔ ZeroFormatter KeyTuple / List wires (net8 cannot dynamic-format suite POCOs).
    /// </summary>
    internal sealed class ZeroFormatterDomainMap : IDomainNativeMap
    {
        // Wire type aliases
        internal static readonly Type MsgT = typeof(KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>);
        internal static readonly Type DocT = typeof(KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>);
        internal static readonly Type TelT = typeof(KeyTuple<string, long, List<string>, List<double>>);
        internal static readonly Type StrT = typeof(List<string>);
        internal static readonly Type EvtT = typeof(KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>);
        internal static readonly Type BatchMsgT = typeof(List<KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>>);
        internal static readonly Type BatchDocT = typeof(List<KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>>);
        internal static readonly Type BatchTelT = typeof(List<KeyTuple<string, long, List<string>, List<double>>>);
        internal static readonly Type BatchStrT = typeof(List<List<string>>);
        internal static readonly Type BatchEvtT = typeof(List<KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>>);

        public DomainNativeBinding Resolve(Type domainRootType)
        {
            if (domainRootType == typeof(Message))
                return B(MsgT, o => ToWire((Message)o), o => FromWireMsg(o));
            if (domainRootType == typeof(Document))
                return B(DocT, o => ToWire((Document)o), o => FromWireDoc(o));
            if (domainRootType == typeof(Telemetry))
                return B(TelT, o => ToWire((Telemetry)o), o => FromWireTel(o));
            if (domainRootType == typeof(Strings))
                return B(StrT, o => ToWire((Strings)o), o => FromWireStr(o));
            if (domainRootType == typeof(Event))
                return B(EvtT, o => ToWire((Event)o), o => FromWireEvt(o));
            if (domainRootType == typeof(BatchMessage))
                return B(BatchMsgT,
                    o => ((BatchMessage)o).Items.Select(m => (KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>)ToWire(m)).ToList(),
                    o => new BatchMessage
                    {
                        Items = ((List<KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>>)o)
                            .Select(x => (Message)FromWireMsg(x)).ToList()
                    });
            if (domainRootType == typeof(BatchDocument))
                return B(BatchDocT,
                    o => ((BatchDocument)o).Items.Select(d => (KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>)ToWire(d)).ToList(),
                    o => new BatchDocument
                    {
                        Items = ((List<KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>>)o)
                            .Select(x => (Document)FromWireDoc(x)).ToList()
                    });
            if (domainRootType == typeof(BatchTelemetry))
                return B(BatchTelT,
                    o => ((BatchTelemetry)o).Items.Select(t => (KeyTuple<string, long, List<string>, List<double>>)ToWire(t)).ToList(),
                    o => new BatchTelemetry
                    {
                        Items = ((List<KeyTuple<string, long, List<string>, List<double>>>)o)
                            .Select(x => (Telemetry)FromWireTel(x)).ToList()
                    });
            if (domainRootType == typeof(BatchStrings))
                return B(BatchStrT,
                    o => ((BatchStrings)o).Items.Select(s => (List<string>)ToWire(s)).ToList(),
                    o => new BatchStrings
                    {
                        Items = ((List<List<string>>)o).Select(x => (Strings)FromWireStr(x)).ToList()
                    });
            if (domainRootType == typeof(BatchEvent))
                return B(BatchEvtT,
                    o => ((BatchEvent)o).Items.Select(e => (KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>)ToWire(e)).ToList(),
                    o => new BatchEvent
                    {
                        Items = ((List<KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>>)o)
                            .Select(x => (Event)FromWireEvt(x)).ToList()
                    });
            throw new NotSupportedException($"ZeroFormatter map: {domainRootType}");
        }

        static DomainNativeBinding B(Type native, Func<object, object> toN, Func<object, object> toD)
            => new DomainNativeBinding { NativeRoot = native, ToNative = toN, ToDomain = toD };

        static object ToWire(Message m) => KeyTuple.Create(
            KeyTuple.Create(m.FBool, m.FInt32, m.FInt64, m.FFloat64),
            KeyTuple.Create(m.FString ?? "", m.FBool2, m.FInt322, m.FString2 ?? ""));
        static object FromWireMsg(object native)
        {
            var t = (KeyTuple<KeyTuple<bool, int, long, double>, KeyTuple<string, bool, int, string>>)native;
            var a = t.Item1; var b = t.Item2;
            return new Message
            {
                FBool = a.Item1, FInt32 = a.Item2, FInt64 = a.Item3, FFloat64 = a.Item4,
                FString = b.Item1, FBool2 = b.Item2, FInt322 = b.Item3, FString2 = b.Item4
            };
        }
        static object ToWire(Document d) => KeyTuple.Create(
            d.Id ?? "", d.Status,
            KeyTuple.Create(d.Meta?.Region ?? "", d.Meta?.Version ?? 0),
            (d.Items ?? new List<DocumentItem>()).Select(i => KeyTuple.Create(i.Sku ?? "", i.Qty, i.PriceMinor)).ToList());
        static object FromWireDoc(object native)
        {
            var t = (KeyTuple<string, int, KeyTuple<string, int>, List<KeyTuple<string, int, long>>>)native;
            return new Document
            {
                Id = t.Item1, Status = t.Item2,
                Meta = new DocumentMeta { Region = t.Item3.Item1, Version = t.Item3.Item2 },
                Items = t.Item4.Select(i => new DocumentItem { Sku = i.Item1, Qty = i.Item2, PriceMinor = i.Item3 }).ToList()
            };
        }
        static object ToWire(Telemetry t) => KeyTuple.Create(
            t.Source ?? "", t.Ts, t.Tags?.ToList() ?? new List<string>(), t.Values?.ToList() ?? new List<double>());
        static object FromWireTel(object native)
        {
            var t = (KeyTuple<string, long, List<string>, List<double>>)native;
            return new Telemetry { Source = t.Item1, Ts = t.Item2, Tags = t.Item3, Values = t.Item4 };
        }
        static object ToWire(Strings s) => s.Items?.ToList() ?? new List<string>();
        static object FromWireStr(object native) => new Strings { Items = (List<string>)native };
        static object ToWire(Event e) => KeyTuple.Create(
            e.EventId ?? "", e.EventType ?? "", e.OccurredAt, e.Producer ?? "",
            (e.Attrs ?? new List<EventAttr>()).Select(a => KeyTuple.Create(a.Key ?? "", a.Value ?? "")).ToList());
        static object FromWireEvt(object native)
        {
            var t = (KeyTuple<string, string, long, string, List<KeyTuple<string, string>>>)native;
            return new Event
            {
                EventId = t.Item1, EventType = t.Item2, OccurredAt = t.Item3, Producer = t.Item4,
                Attrs = t.Item5.Select(a => new EventAttr { Key = a.Item1, Value = a.Item2 }).ToList()
            };
        }
    }
}
