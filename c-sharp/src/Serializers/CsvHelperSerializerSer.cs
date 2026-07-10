using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using CsvHelper;
using CsvHelper.Configuration;
using GLD.SerializerBenchmark.TestData.V2;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// CsvHelper is a tabular codec: nested suite graphs cannot be represented as columns
    /// without a projection. We project each root object to a single CSV row of scalar
    /// fields (type-specific), using the official CsvWriter/CsvReader WriteRecords/GetRecords API
    /// with a reused CsvConfiguration (CultureInfo.InvariantCulture).
    /// https://joshclose.github.io/CsvHelper/
    /// </summary>
    internal class CsvHelperSerializerSer : SerDeser
    {
        private static readonly CsvConfiguration Cfg = new CsvConfiguration(CultureInfo.InvariantCulture)
        {
            HasHeaderRecord = true,
            NewLine = "\n",
        };

        private object _rows; // List&lt;TRow&gt; prepared for the fixture

        public override string Name => "CsvHelper";
        // Nested graphs are not representable as honest multi-column CSV without lossy JSON.
        // Limit to message/event (flat-ish) where we map scalar columns.
        public override bool Supports(string testDataName)
            => testDataName is "message" or "event" or "strings";

        public override void PrepareData(object data) => _rows = ToRows(data);

        public override object ToDomain(object decoded) => FromRows(decoded);

        public override string Serialize(object serializable)
        {
            var rows = _rows ?? ToRows(serializable);
            using var w = new StringWriter();
            using var csv = new CsvWriter(w, Cfg);
            Write(csv, rows);
            return w.ToString();
        }

        public override object Deserialize(string serialized)
        {
            using var r = new StringReader(serialized);
            using var csv = new CsvReader(r, Cfg);
            return Read(csv);
        }

        public override void Serialize(object serializable, Stream outputStream)
        {
            using var w = new StreamWriter(outputStream, new UTF8Encoding(false), 1024, leaveOpen: true);
            using var csv = new CsvWriter(w, Cfg);
            Write(csv, _rows ?? ToRows(serializable));
            w.Flush();
        }

        public override object Deserialize(Stream inputStream)
        {
            inputStream.Seek(0, SeekOrigin.Begin);
            using var r = new StreamReader(inputStream, Encoding.UTF8, false, 1024, leaveOpen: true);
            using var csv = new CsvReader(r, Cfg);
            return Read(csv);
        }

        void Write(CsvWriter csv, object rows)
        {
            switch (rows)
            {
                case List<MessageRow> m: csv.WriteRecords(m); break;
                case List<EventRow> e: csv.WriteRecords(e); break;
                case List<StringRow> s: csv.WriteRecords(s); break;
                default: throw new NotSupportedException($"CsvHelper write {rows?.GetType()}");
            }
        }

        object Read(CsvReader csv)
        {
            if (_primaryType == typeof(Message) || _primaryType == typeof(BatchMessage))
                return csv.GetRecords<MessageRow>().ToList();
            if (_primaryType == typeof(Event) || _primaryType == typeof(BatchEvent))
                return csv.GetRecords<EventRow>().ToList();
            if (_primaryType == typeof(Strings) || _primaryType == typeof(BatchStrings))
                return csv.GetRecords<StringRow>().ToList();
            throw new NotSupportedException($"CsvHelper read {_primaryType}");
        }

        object ToRows(object data) => data switch
        {
            Message m => new List<MessageRow> { MapMsg(m) },
            BatchMessage b => b.Items.Select(MapMsg).ToList(),
            Event e => new List<EventRow> { MapEvt(e) },
            BatchEvent b => b.Items.Select(MapEvt).ToList(),
            // Flatten string list as one row with pipe-joined payload (tabular best-effort).
            Strings s => new List<StringRow> { new StringRow { Items = string.Join("\u001f", s.Items ?? new List<string>()) } },
            BatchStrings b => b.Items.Select(s => new StringRow
            {
                Items = string.Join("\u001f", s.Items ?? new List<string>())
            }).ToList(),
            _ => throw new NotSupportedException($"CsvHelper ToRows {data?.GetType()}")
        };

        object FromRows(object decoded)
        {
            if (decoded is List<MessageRow> mr)
            {
                if (_primaryType == typeof(Message)) return UnmapMsg(mr[0]);
                return new BatchMessage { Items = mr.Select(UnmapMsg).ToList() };
            }
            if (decoded is List<EventRow> er)
            {
                if (_primaryType == typeof(Event)) return UnmapEvt(er[0]);
                return new BatchEvent { Items = er.Select(UnmapEvt).ToList() };
            }
            if (decoded is List<StringRow> sr)
            {
                if (_primaryType == typeof(Strings))
                    return new Strings
                    {
                        Items = string.IsNullOrEmpty(sr[0].Items)
                            ? new List<string>()
                            : sr[0].Items.Split('\u001f').ToList()
                    };
                return new BatchStrings
                {
                    Items = sr.Select(r => new Strings
                    {
                        Items = string.IsNullOrEmpty(r.Items)
                            ? new List<string>()
                            : r.Items.Split('\u001f').ToList()
                    }).ToList()
                };
            }
            // CsvHelper may return IEnumerable
            if (decoded is IEnumerable en && decoded is not string)
            {
                var list = en.Cast<object>().ToList();
                if (list.Count > 0 && list[0] is MessageRow)
                    return FromRows(list.Cast<MessageRow>().ToList());
                if (list.Count > 0 && list[0] is EventRow)
                    return FromRows(list.Cast<EventRow>().ToList());
                if (list.Count > 0 && list[0] is StringRow)
                    return FromRows(list.Cast<StringRow>().ToList());
            }
            return decoded;
        }

        static MessageRow MapMsg(Message m) => new MessageRow
        {
            FBool = m.FBool, FInt32 = m.FInt32, FInt64 = m.FInt64, FFloat64 = m.FFloat64,
            FString = m.FString ?? "", FBool2 = m.FBool2, FInt322 = m.FInt322, FString2 = m.FString2 ?? ""
        };

        static Message UnmapMsg(MessageRow r) => new Message
        {
            FBool = r.FBool, FInt32 = r.FInt32, FInt64 = r.FInt64, FFloat64 = r.FFloat64,
            FString = r.FString ?? "", FBool2 = r.FBool2, FInt322 = r.FInt322, FString2 = r.FString2 ?? ""
        };

        // Attrs collapsed to "k=v;k=v" for single-row tabular representation.
        static EventRow MapEvt(Event e) => new EventRow
        {
            EventId = e.EventId ?? "", EventType = e.EventType ?? "", OccurredAt = e.OccurredAt,
            Producer = e.Producer ?? "",
            Attrs = string.Join(";", (e.Attrs ?? new List<EventAttr>()).Select(a => $"{a.Key}={a.Value}"))
        };

        static Event UnmapEvt(EventRow r) => new Event
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

        public class MessageRow
        {
            public bool FBool { get; set; }
            public int FInt32 { get; set; }
            public long FInt64 { get; set; }
            public double FFloat64 { get; set; }
            public string FString { get; set; }
            public bool FBool2 { get; set; }
            public int FInt322 { get; set; }
            public string FString2 { get; set; }
        }

        public class EventRow
        {
            public string EventId { get; set; }
            public string EventType { get; set; }
            public long OccurredAt { get; set; }
            public string Producer { get; set; }
            public string Attrs { get; set; }
        }

        public class StringRow
        {
            public string Items { get; set; }
        }
    }
}
