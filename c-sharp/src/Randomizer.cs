using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using Newtonsoft.Json;

namespace GLD.SerializerBenchmark
{
    public class StringOptions
    {
        public int MinWordLength { get; set; }
        public int MaxWordLength { get; set; }
        public int MinPhraseLength { get; set; }
        public int MaxPhraseLength { get; set; }
        public int MinIdLength { get; set; }
        public int MaxIdLength { get; set; }
        public double DuplicationFactor { get; set; }
    }

    public class CollectionOptions
    {
        public int PersonPoliceRecordsCount { get; set; }
        public int TelemetryMeasurementsCount { get; set; }
        public int StringArrayCount { get; set; }
        public int EdiClaimsCount { get; set; }
        public int EdiLinesPerClaimCount { get; set; }
    }

    public class TestDataConfig
    {
        public StringOptions StringOptions { get; set; }
        public CollectionOptions CollectionOptions { get; set; }
        public int RandomSeed { get; set; }
    }

    /// <summary>
    ///     It emulates the quazy-random generator trying to use lightweith, fast methods.
    /// </summary>
    internal class Randomizer
    {
        private const string PoolUpperCaseLetters = "QWERTYUIOPASDFGHJKLZXCVBNM"; // lenght = 26
        private const string PoolLowerCaseLetters = "qwertyuiopasdfghjklzxcvbnm"; // lenght = 26

        private const string PoolPunctuation = "                    ,,,,...!?--:;";

        public static Random Rand = new Random();
        public static TestDataConfig Settings { get; private set; }
        private static List<string> _stringPool = new List<string>();

        static Randomizer()
        {
            var configPath = FindConfigPath();
            if (File.Exists(configPath))
            {
                try
                {
                    Settings = JsonConvert.DeserializeObject<TestDataConfig>(File.ReadAllText(configPath));
                    Rand = new Random(Settings.RandomSeed);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error loading config from {configPath}: {ex.Message}");
                    LoadDefaultSettings();
                }
            }
            else
            {
                LoadDefaultSettings();
            }
        }

        private static string FindConfigPath()
        {
            var paths = new[]
            {
                "../../../../schemas/test_data_config.json",
                "../../../schemas/test_data_config.json",
                "../../schemas/test_data_config.json",
                "schemas/test_data_config.json",
                "../schemas/test_data_config.json"
            };

            foreach (var path in paths)
            {
                var fullPath = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, path));
                if (File.Exists(fullPath)) return fullPath;
            }
            return "schemas/test_data_config.json";
        }

        private static void LoadDefaultSettings()
        {
            Settings = new TestDataConfig
            {
                StringOptions = new StringOptions
                {
                    MinWordLength = 3, MaxWordLength = 10,
                    MinPhraseLength = 2, MaxPhraseLength = 6,
                    MinIdLength = 8, MaxIdLength = 12,
                    DuplicationFactor = 0.1
                },
                CollectionOptions = new CollectionOptions
                {
                    PersonPoliceRecordsCount = 5,
                    TelemetryMeasurementsCount = 100,
                    StringArrayCount = 100,
                    EdiClaimsCount = 5,
                    EdiLinesPerClaimCount = 3
                },
                RandomSeed = 42
            };
            Rand = new Random(Settings.RandomSeed);
        }

        public static string Name
        {
            get { return TryGetDuplicate() ?? (GetCapitalChar() + Word); }
        }

        public static string Word
        {
            get
            {
                var s = TryGetDuplicate();
                if (s != null) return s;

                var wordLength = Rand.Next(Settings.StringOptions.MinWordLength, Settings.StringOptions.MaxWordLength + 1);
                var sb = new StringBuilder(wordLength);
                for (var i = 0; i < wordLength; i++)
                    sb.Append(GetChar());
                
                s = sb.ToString();
                AddToPool(s);
                return s;
            }
        }

        public static string Id
        {
            get
            {
                var s = TryGetDuplicate();
                if (s != null) return s;

                var length = Rand.Next(Settings.StringOptions.MinIdLength, Settings.StringOptions.MaxIdLength + 1);
                var sb = new StringBuilder(length);
                for (var i = 0; i < length; i++)
                    sb.Append(GetDigit());
                
                s = sb.ToString();
                AddToPool(s);
                return s;
            }
        }

        public static string Phrase
        {
            get
            {
                var s = TryGetDuplicate();
                if (s != null) return s;

                var phraseLength = Rand.Next(Settings.StringOptions.MinPhraseLength, Settings.StringOptions.MaxPhraseLength + 1);
                var sb = new StringBuilder();
                sb.Append(Name);
                for (var i = 0; i < phraseLength; i++)
                    sb.Append(" " + Word + GetPunctuation());
                
                s = sb.ToString();
                AddToPool(s);
                return s;
            }
        }

        private static string TryGetDuplicate()
        {
            if (_stringPool.Count > 0 && Rand.NextDouble() < Settings.StringOptions.DuplicationFactor)
            {
                return _stringPool[Rand.Next(_stringPool.Count)];
            }
            return null;
        }

        private static void AddToPool(string s)
        {
            if (_stringPool.Count < 1000) // Keep pool size reasonable
                _stringPool.Add(s);
            else
                _stringPool[Rand.Next(_stringPool.Count)] = s;
        }

        public static DateTime GetDate(DateTime startDT, DateTime stopDT)
        {
            return startDT.AddDays(Rand.Next((stopDT - startDT).Days));
        }

        private static char GetCapitalChar()
        {
            return PoolUpperCaseLetters[Rand.Next(PoolUpperCaseLetters.Length)];
        }

        private static char GetChar()
        {
            return PoolLowerCaseLetters[Rand.Next(PoolLowerCaseLetters.Length)];
        }

        private static char GetPunctuation()
        {
            return PoolPunctuation[Rand.Next(PoolPunctuation.Length)];
        }

        private static char GetDigit()
        {
            return Rand.Next(0, 9).ToString()[0];
        }
    }
}