using System;

namespace GLD.SerializerBenchmark.TestData
{
    public static class BondTypeAlliasConverter
    {
        public static long Convert(DateTime value, long unused)
        {
            return value.ToBinary();
        }

        public static DateTime Convert(long value, DateTime unused)
        {
            return DateTime.FromBinary(value);
        }
    }
}