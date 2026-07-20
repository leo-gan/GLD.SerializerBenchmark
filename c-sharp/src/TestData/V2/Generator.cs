// make_one for Data Model v2 — aligned with python data_v2/generator.py
using System;
using System.Collections.Generic;
using System.Text.Json;

namespace GLD.SerializerBenchmark.TestData.V2
{
    public static class Generator
    {
        const long BaseTsMs = 1_704_067_200_000L; // 2024-01-01T00:00:00Z

        public static object MakeOne(string typeId, JsonElement typeConfig, int seed, int instanceIndex = 0)
        {
            var rng = new Rng(MixSeed((ulong)seed, typeId, instanceIndex));
            return typeId switch
            {
                "message" => MakeMessage(rng, typeConfig),
                "document" => MakeDocument(rng, typeConfig),
                "telemetry" => MakeTelemetry(rng, typeConfig),
                "strings" => MakeStrings(rng, typeConfig),
                "event" => MakeEvent(rng, typeConfig),
                _ => throw new ArgumentException($"unknown type_id: {typeId}")
            };
        }

        public static (object data, Type dataType, List<Type> secondary) BuildPayload(
            string typeId, JsonElement typeConfig, int n, int seed)
        {
            if (n < 1) n = 1;
            switch (typeId)
            {
                case "message":
                {
                    var list = new List<Message>(n);
                    for (int i = 0; i < n; i++) list.Add((Message)MakeOne(typeId, typeConfig, seed, i));
                    if (n == 1) return (list[0], typeof(Message), new List<Type>());
                    return (new BatchMessage { Items = list }, typeof(BatchMessage), new List<Type> { typeof(Message) });
                }
                case "event":
                {
                    var list = new List<Event>(n);
                    for (int i = 0; i < n; i++) list.Add((Event)MakeOne(typeId, typeConfig, seed, i));
                    if (n == 1) return (list[0], typeof(Event), new List<Type> { typeof(EventAttr) });
                    return (new BatchEvent { Items = list }, typeof(BatchEvent),
                        new List<Type> { typeof(Event), typeof(EventAttr) });
                }
                case "document":
                {
                    var list = new List<Document>(n);
                    for (int i = 0; i < n; i++) list.Add((Document)MakeOne(typeId, typeConfig, seed, i));
                    var sec = new List<Type> { typeof(DocumentMeta), typeof(DocumentItem) };
                    if (n == 1) return (list[0], typeof(Document), sec);
                    sec.Insert(0, typeof(Document));
                    return (new BatchDocument { Items = list }, typeof(BatchDocument), sec);
                }
                case "telemetry":
                {
                    var list = new List<Telemetry>(n);
                    for (int i = 0; i < n; i++) list.Add((Telemetry)MakeOne(typeId, typeConfig, seed, i));
                    if (n == 1) return (list[0], typeof(Telemetry), new List<Type>());
                    return (new BatchTelemetry { Items = list }, typeof(BatchTelemetry),
                        new List<Type> { typeof(Telemetry) });
                }
                case "strings":
                {
                    var list = new List<Strings>(n);
                    for (int i = 0; i < n; i++) list.Add((Strings)MakeOne(typeId, typeConfig, seed, i));
                    if (n == 1) return (list[0], typeof(Strings), new List<Type>());
                    return (new BatchStrings { Items = list }, typeof(BatchStrings),
                        new List<Type> { typeof(Strings) });
                }
                default:
                    throw new ArgumentException($"unknown type_id: {typeId}");
            }
        }

        static Message MakeMessage(Rng r, JsonElement cfg)
        {
            var (lo, hi) = IRange(cfg);
            var (smin, smax) = SLen(cfg);
            return new Message
            {
                FBool = r.NextBool(),
                FInt32 = r.NextInt(lo, Math.Min(hi, int.MaxValue)),
                FInt64 = r.NextInt(lo, hi),
                FFloat64 = r.NextF64() * 1000.0,
                FString = r.Word(smin, smax),
                FBool2 = r.NextBool(),
                FInt322 = r.NextInt(lo, Math.Min(hi, int.MaxValue)),
                FString2 = r.Word(smin, smax),
            };
        }

        static Document MakeDocument(Rng r, JsonElement cfg)
        {
            int children = GetInt(cfg, "children", 8);
            var (smin, smax) = SLen(cfg);
            var items = new List<DocumentItem>(children);
            for (int i = 0; i < children; i++)
                items.Add(new DocumentItem
                {
                    Sku = r.Word(smin, smax),
                    Qty = r.NextInt(1, 100),
                    PriceMinor = r.NextInt(0, 100_000),
                });
            return new Document
            {
                Id = r.Word(8, 12),
                Status = r.NextInt(0, 5),
                Meta = new DocumentMeta { Region = r.Word(2, 4), Version = r.NextInt(1, 10) },
                Items = items,
            };
        }

        static Telemetry MakeTelemetry(Rng r, JsonElement cfg)
        {
            int points = GetInt(cfg, "points", 32);
            int tagCount = GetInt(cfg, "tag_count", 2);
            var (smin, smax) = SLen(cfg);
            var tags = new List<string>(tagCount);
            for (int i = 0; i < tagCount; i++) tags.Add(r.Word(smin, smax));
            var values = new List<double>(points);
            var numberType = GetString(cfg, "number_type", "float64");
            for (int i = 0; i < points; i++)
                values.Add(numberType == "int64" ? r.NextInt(0, 10_000) : r.NextF64() * 100.0);
            return new Telemetry
            {
                Source = r.Word(smin, smax),
                Ts = BaseTsMs + r.NextInt(0, 86_400_000),
                Tags = tags,
                Values = values,
            };
        }

        static Strings MakeStrings(Rng r, JsonElement cfg)
        {
            int count = GetInt(cfg, "count", 32);
            var (smin, smax) = SLen(cfg);
            double dup = GetDouble(cfg, "duplication", 0.1);
            var pool = new List<string>();
            var items = new List<string>(count);
            for (int i = 0; i < count; i++)
            {
                if (pool.Count > 0 && r.NextF64() < dup)
                    items.Add(pool[r.NextInt(0, pool.Count - 1)]);
                else
                {
                    var w = r.Word(smin, smax);
                    pool.Add(w);
                    items.Add(w);
                }
            }
            return new Strings { Items = items };
        }

        static Event MakeEvent(Rng r, JsonElement cfg)
        {
            int attrCount = GetInt(cfg, "attr_count", 4);
            var (smin, smax) = SLen(cfg);
            var attrs = new List<EventAttr>(attrCount);
            for (int i = 0; i < attrCount; i++)
                attrs.Add(new EventAttr { Key = r.Word(smin, smax), Value = r.Word(smin, smax) });
            return new Event
            {
                EventId = r.Word(8, 12),
                EventType = r.Word(smin, smax),
                OccurredAt = BaseTsMs + r.NextInt(0, 86_400_000),
                Producer = r.Word(smin, smax),
                Attrs = attrs,
            };
        }

        static (int min, int max) SLen(JsonElement cfg)
        {
            int min = 3, max = 16;
            if (cfg.ValueKind == JsonValueKind.Object && cfg.TryGetProperty("string_len", out var sl) &&
                sl.ValueKind == JsonValueKind.Object)
            {
                if (sl.TryGetProperty("min", out var a)) min = a.GetInt32();
                if (sl.TryGetProperty("max", out var b)) max = b.GetInt32();
            }
            return (min, max);
        }

        static (int min, int max) IRange(JsonElement cfg)
        {
            int min = 0, max = 1_000_000;
            if (cfg.ValueKind == JsonValueKind.Object && cfg.TryGetProperty("int_range", out var ir) &&
                ir.ValueKind == JsonValueKind.Object)
            {
                if (ir.TryGetProperty("min", out var a)) min = a.GetInt32();
                if (ir.TryGetProperty("max", out var b)) max = b.GetInt32();
            }
            return (min, max);
        }

        static int GetInt(JsonElement cfg, string name, int def) =>
            cfg.ValueKind == JsonValueKind.Object && cfg.TryGetProperty(name, out var p) && p.TryGetInt32(out var v)
                ? v : def;

        static double GetDouble(JsonElement cfg, string name, double def) =>
            cfg.ValueKind == JsonValueKind.Object && cfg.TryGetProperty(name, out var p) && p.TryGetDouble(out var v)
                ? v : def;

        static string GetString(JsonElement cfg, string name, string def) =>
            cfg.ValueKind == JsonValueKind.Object && cfg.TryGetProperty(name, out var p) && p.ValueKind == JsonValueKind.String
                ? p.GetString() ?? def : def;

        static ulong MixSeed(ulong seed, string typeId, int idx)
        {
            ulong h = seed;
            foreach (var ch in typeId) h = (h ^ ch) * 0x100000001B3UL;
            h ^= (ulong)idx * 0x9E3779B97F4A7C15UL;
            return h == 0 ? 1UL : h;
        }

        /// <summary>
        /// Deterministic xorshift64* (within-language only). Zero seed uses
        /// floor(2^64/φ)=0x9E3779B97F4A7C15 (golden ratio; nothing-up-my-sleeve).
        /// </summary>
        sealed class Rng
        {
            ulong _state;
            public Rng(ulong seed) { _state = seed == 0 ? 0x9E3779B97F4A7C15UL : seed; }
            public ulong NextU64()
            {
                var x = _state;
                x ^= x << 13; x ^= x >> 7; x ^= x << 17;
                _state = x;
                return x;
            }
            public int NextInt(int lo, int hi)
            {
                if (hi <= lo) return lo;
                return lo + (int)(NextU64() % (ulong)(hi - lo + 1));
            }
            public bool NextBool() => (NextU64() & 1) == 1;
            public double NextF64() => (NextU64() >> 11) * (1.0 / (1UL << 53));
            public string Word(int minL, int maxL)
            {
                int n = NextInt(minL, maxL);
                const string a = "abcdefghijklmnopqrstuvwxyz";
                var chars = new char[n];
                for (int i = 0; i < n; i++) chars[i] = a[(int)(NextU64() % 26)];
                return new string(chars);
            }
        }
    }
}
