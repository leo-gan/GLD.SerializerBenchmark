using System;

namespace GLD.SerializerBenchmark.TestData
{
    /// <summary>
    /// Bond discovers this by type name <c>TypeAliasConverter</c> for [Type(typeof(long))] DateTime fields.
    /// </summary>
    public static class TypeAliasConverter
    {
        public static long Convert(DateTime value, long unused) => value.ToBinary();
        public static DateTime Convert(long value, DateTime unused) => DateTime.FromBinary(value);
    }
}
