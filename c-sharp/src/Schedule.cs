using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    /// B-1 deterministic block_shuffle schedule (must match analysis golden vector).
    /// </summary>
    public static class Schedule
    {
        public static string NormalizeMode(string mode)
        {
            var m = (mode ?? "").Trim().ToLowerInvariant();
            if (m == "string" || m == "buffer") return "bytes";
            if (m == "stream") return "stream";
            return m;
        }

        public static ulong DeriveScheduleSeed(
            long baseSeed, string typeId, int instanceCount,
            string typeConfigHash, string mode, int rep)
        {
            var key = $"{baseSeed}|{typeId}|{instanceCount}|{typeConfigHash ?? ""}|{NormalizeMode(mode)}|{rep}";
            var digest = SHA256.HashData(Encoding.UTF8.GetBytes(key));
            ulong u = 0;
            for (var i = 7; i >= 0; i--)
                u = (u << 8) | digest[i]; // little-endian first 8 bytes
            return u;
        }

        public static List<T> FisherYates<T>(IList<T> items, ulong seed)
        {
            var arr = new List<T>(items);
            var rng = new SplitMix64(seed);
            for (var i = arr.Count - 1; i > 0; i--)
            {
                var j = (int)(rng.NextU64() % (ulong)(i + 1));
                (arr[i], arr[j]) = (arr[j], arr[i]);
            }
            return arr;
        }

        /// <summary>Golden vector: A,B,C @ seed 42 / message / 1 / abc / bytes / 0 → C,B,A</summary>
        public static List<string> GoldenPermutation()
        {
            var seed = DeriveScheduleSeed(42, "message", 1, "abc", "bytes", 0);
            return FisherYates(new[] { "A", "B", "C" }, seed);
        }

        public static string ResolveStrategy()
        {
            var env = (Environment.GetEnvironmentVariable("BENCHMARK_SCHEDULE") ?? "").Trim().ToLowerInvariant();
            if (env == "none" || env == "block_shuffle") return env;
            return "block_shuffle";
        }

        public static bool ResolveRecordRunOrder()
        {
            var env = (Environment.GetEnvironmentVariable("BENCHMARK_RECORD_RUN_ORDER") ?? "").Trim().ToLowerInvariant();
            if (env == "0" || env == "false" || env == "no") return false;
            return true;
        }

        private struct SplitMix64
        {
            private ulong _state;
            public SplitMix64(ulong seed) { _state = seed; }
            public ulong NextU64()
            {
                unchecked
                {
                    _state += 0x9E3779B97F4A7C15UL;
                    var z = _state;
                    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
                    z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
                    return z ^ (z >> 31);
                }
            }
        }
    }
}
