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
                "table" or "table_project" => MakeTable(rng, typeConfig, seed, typeId),
                "nested_table" => MakeNestedTable(rng, typeConfig),
                "signal" => MakeSignal(rng, typeConfig),
                "grid" or "grid_window" => MakeGrid(rng, typeConfig, typeId == "grid_window"),
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
                case "table":
                case "table_project":
                {
                    var list = new List<TableRow>(n);
                    for (int i = 0; i < n; i++) list.Add((TableRow)MakeOne(typeId, typeConfig, seed, i));
                    if (n == 1) return (list[0], typeof(TableRow), new List<Type>());
                    return (new BatchTable { Items = list }, typeof(BatchTable), new List<Type> { typeof(TableRow) });
                }
                case "nested_table":
                {
                    var list = new List<NestedRow>(n);
                    for (int i = 0; i < n; i++) list.Add((NestedRow)MakeOne(typeId, typeConfig, seed, i));
                    var sec = new List<Type> { typeof(NestedMeta), typeof(NestedItem) };
                    if (n == 1) return (list[0], typeof(NestedRow), sec);
                    sec.Insert(0, typeof(NestedRow));
                    return (new BatchNestedRow { Items = list }, typeof(BatchNestedRow), sec);
                }
                case "signal":
                {
                    var list = new List<Signal>(n);
                    for (int i = 0; i < n; i++) list.Add((Signal)MakeOne(typeId, typeConfig, seed, i));
                    var sec = new List<Type> { typeof(SignalLeg) };
                    if (n == 1) return (list[0], typeof(Signal), sec);
                    sec.Insert(0, typeof(Signal));
                    return (new BatchSignal { Items = list }, typeof(BatchSignal), sec);
                }
                case "grid":
                case "grid_window":
                {
                    if (n != 1) throw new ArgumentException("grid N must be 1");
                    var grid = (Grid)MakeOne(typeId, typeConfig, seed, 0);
                    return (grid, typeof(Grid), new List<Type>());
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

        static TableRow MakeTable(Rng r, JsonElement cfg, int seed, string typeId)
        {
            var (lo, hi) = IRange(cfg);
            var (smin, smax) = SLen(cfg);
            double dup = GetDouble(cfg, "duplication", 0.5);
            var vocab = SharedVocab(seed, typeId, smin, smax);
            var floats = new double[16];
            for (int i = 0; i < 16; i++) floats[i] = r.NextF64() * 1000.0;
            var ints = new long[4];
            for (int i = 0; i < 4; i++) ints[i] = r.NextInt(lo, hi);
            return new TableRow
            {
                FFloat0 = floats[0], FFloat1 = floats[1], FFloat2 = floats[2], FFloat3 = floats[3],
                FFloat4 = floats[4], FFloat5 = floats[5], FFloat6 = floats[6], FFloat7 = floats[7],
                FFloat8 = floats[8], FFloat9 = floats[9], FFloat10 = floats[10], FFloat11 = floats[11],
                FFloat12 = floats[12], FFloat13 = floats[13], FFloat14 = floats[14], FFloat15 = floats[15],
                FInt0 = ints[0], FInt1 = ints[1], FInt2 = ints[2], FInt3 = ints[3],
                FStr0 = PickWord(r, vocab, dup, smin, smax),
                FStr1 = PickWord(r, vocab, dup, smin, smax),
            };
        }

        static List<string> SharedVocab(int seed, string typeId, int smin, int smax, int size = 32)
        {
            var vocabRng = new Rng(MixSeed((ulong)seed, typeId + "#vocab", 0));
            var vocab = new List<string>(size);
            for (int i = 0; i < size; i++) vocab.Add(vocabRng.Word(smin, smax));
            return vocab;
        }

        static string PickWord(Rng r, List<string> vocab, double duplication, int smin, int smax)
        {
            if (vocab.Count > 0 && r.NextF64() < duplication)
                return vocab[r.NextInt(0, vocab.Count - 1)];
            return r.Word(smin, smax);
        }

        static NestedRow MakeNestedTable(Rng r, JsonElement cfg)
        {
            int children = GetInt(cfg, "children", 4);
            var (smin, smax) = SLen(cfg, 3, 12);
            var items = new List<NestedItem>(children);
            for (int i = 0; i < children; i++)
                items.Add(new NestedItem
                {
                    Sku = r.Word(smin, smax),
                    Qty = r.NextInt(1, 100),
                    PriceMinor = r.NextInt(0, 100_000),
                });
            return new NestedRow
            {
                Id = r.Word(8, 12),
                Status = r.NextInt(0, 5),
                Meta = new NestedMeta { Region = r.Word(2, 4), Version = r.NextInt(1, 10) },
                Items = items,
            };
        }

        static Signal MakeSignal(Rng r, JsonElement cfg)
        {
            int groupCount = GetInt(cfg, "group_count", 4);
            var (smin, smax) = SLen(cfg);
            var legs = new List<SignalLeg>(groupCount);
            for (int i = 0; i < groupCount; i++)
                legs.Add(new SignalLeg
                {
                    LegId = r.NextInt(0, 1_000_000),
                    LegQty = r.NextInt(0, 10_000),
                    LegPad = 0,
                });
            return new Signal
            {
                Seq = r.NextInt(0, 1_000_000_000),
                Ts = BaseTsMs + r.NextInt(0, 86_400_000),
                PriceMantissa = r.NextInt(0, 1_000_000_000),
                Qty = r.NextInt(0, 10_000),
                Flags = r.NextInt(0, 65_535),
                Symbol = r.Word(smin, smax),
                Venue = r.Word(smin, smax),
                Legs = legs,
            };
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

        static Grid MakeGrid(Rng rng, JsonElement cfg, bool window)
        {
            var nx = GetInt(cfg, "nx", 512);
            var ny = GetInt(cfg, "ny", 512);
            var values = new double[nx * ny];
            for (var i = 0; i < values.Length; i++) values[i] = rng.NextF64();
            var grid = new Grid { Nx = nx, Ny = ny, Values = values };
            if (!window) return grid;
            JsonElement box = default;
            var has = cfg.ValueKind == JsonValueKind.Object && cfg.TryGetProperty("window", out box);
            grid.X0 = has ? GetInt(box, "x0", 128) : 128;
            grid.Y0 = has ? GetInt(box, "y0", 64) : 64;
            grid.Wx = has ? GetInt(box, "wx", 256) : 256;
            grid.Wy = has ? GetInt(box, "wy", 128) : 128;
            return grid;
        }

        static (int min, int max) SLen(JsonElement cfg, int defMin = 3, int defMax = 16)
        {
            int min = defMin, max = defMax;
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
