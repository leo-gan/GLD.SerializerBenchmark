// Data Model v2 generators (within-language deterministic).
// Cross-language payload identity is not required.
// Wire via BENCHMARK_DATA_MODEL=v2 when the runner supports it.
using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark.TestData.V2
{
    public static class DataV2
    {
        const long BaseTsMs = 1704067200000L;

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

        static ulong MixSeed(ulong seed, string typeId, int idx)
        {
            ulong h = seed;
            foreach (var ch in typeId)
                h = (h ^ ch) * 0x100000001B3UL;
            h ^= (ulong)idx * 0x9E3779B97F4A7C15UL;
            return h == 0 ? 1UL : h;
        }

        public static object MakeOne(string typeId, int seed = 42, int instanceIndex = 0,
            int children = 8, int points = 32, int count = 32, int attrCount = 4)
        {
            var r = new Rng(MixSeed((ulong)seed, typeId, instanceIndex));
            switch (typeId)
            {
                case "message":
                    return new Dictionary<string, object> {
                        ["f_bool"] = r.NextBool(), ["f_int32"] = r.NextInt(0, 1_000_000),
                        ["f_int64"] = (long)r.NextInt(0, 1_000_000), ["f_float64"] = r.NextF64() * 1000,
                        ["f_string"] = r.Word(3, 16), ["f_bool_2"] = r.NextBool(),
                        ["f_int32_2"] = r.NextInt(0, 1_000_000), ["f_string_2"] = r.Word(3, 16),
                    };
                case "telemetry":
                {
                    var tags = new List<string>();
                    for (int i = 0; i < 2; i++) tags.Add(r.Word(3, 10));
                    var values = new List<double>();
                    for (int i = 0; i < points; i++) values.Add(r.NextF64() * 100);
                    return new Dictionary<string, object> {
                        ["source"] = r.Word(3, 10), ["ts"] = BaseTsMs + r.NextInt(0, 86400000),
                        ["tags"] = tags, ["values"] = values,
                    };
                }
                default:
                    throw new ArgumentException("unknown type_id: " + typeId);
            }
        }
    }
}
