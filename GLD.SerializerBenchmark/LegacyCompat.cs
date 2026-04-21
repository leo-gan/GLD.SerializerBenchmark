using System;

namespace GLD.SerializerBenchmark
{
    // Emulate missing NFX extension methods
    public static class NfxEmulationExtensions
    {
        public static string Args(this string format, params object[] args)
        {
            return string.Format(format, args);
        }
    }

    // Emulate NFX classes used in TestData
    public class ExternalRandomGenerator
    {
        public static ExternalRandomGenerator Instance { get; } = new ExternalRandomGenerator();

        public int NextRandomInteger => Random.Shared.Next();
        public double NextRandomDouble => Random.Shared.NextDouble();
    }

    public class NaturalTextGenerator
    {
        public static string GenerateWord() => Randomizer.Word;
        public static string Generate(int length) => Randomizer.Phrase.Substring(0, Math.Min(length, Randomizer.Phrase.Length));
        public static string GenerateFullName() => Randomizer.Name + " " + Randomizer.Name;
        public static string GenerateFirstName() => Randomizer.Name;
        public static string GenerateAddressLine() => Random.Shared.Next(100, 9999) + " " + Randomizer.Name + " St";
        public static string GenerateUSCityStateZip() => Randomizer.Name + ", CA " + Random.Shared.Next(10000, 99999);
        public static string GenerateCityName() => Randomizer.Name;
        public static string GenerateEMail() => Randomizer.Word + "@example.com";
    }
}


namespace NFX.Parsing
{
    // Placeholder if needed
}
