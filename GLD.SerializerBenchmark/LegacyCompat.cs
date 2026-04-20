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
        private static readonly Random _rand = new Random();
        public static ExternalRandomGenerator Instance { get; } = new ExternalRandomGenerator();

        public int NextRandomInteger => _rand.Next();
        public double NextRandomDouble => _rand.NextDouble();
    }

    public class NaturalTextGenerator
    {
        private static readonly Random _rand = new Random();

        public static string GenerateWord() => Randomizer.Word;
        public static string Generate(int length) => Randomizer.Phrase.Substring(0, Math.Min(length, Randomizer.Phrase.Length));
        public static string GenerateFullName() => Randomizer.Name + " " + Randomizer.Name;
        public static string GenerateFirstName() => Randomizer.Name;
        public static string GenerateAddressLine() => _rand.Next(100, 9999) + " " + Randomizer.Name + " St";
        public static string GenerateUSCityStateZip() => Randomizer.Name + ", CA " + _rand.Next(10000, 99999);
        public static string GenerateCityName() => Randomizer.Name;
        public static string GenerateEMail() => Randomizer.Word + "@example.com";
    }
}


namespace NFX.Parsing
{
    // Placeholder if needed
}
