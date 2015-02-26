using System;
using System.Text;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    ///     It emulates the quazy-random generator trying to use lightweith, fast methods.
    /// </summary>
    internal class Randomizer
    {
        private const string PoolUpperCaseLetters = "QWERTYUIOPASDFGHJKLZXCVBNM"; // lenght = 26
        private const string PoolLowerCaseLetters = "qwertyuiopasdfghjklzxcvbnm"; // lenght = 26

        private const string PoolPunctuation = "                    ,,,,...!?--:;";
        // be aware of the JSON special sympols

        public static Random Rand = new Random();

        // lenght = 51

        //private static int UpperCaseLetterCounter;
        //private static int LowerCaseLetterCounter;
        //private static int DigitCounter;
        //private static int PunctuationCounter;
        //private static int WordLenghtCounter = 1;
        //private static int IdLenghtCounter = 1;
        //private static int PhraseLenghtCounter = 1;
        //private static int DateCounter = 0;

        public static string Name
        {
            get { return GetCapitalChar() + Word; }
        }

        public static string Word
        {
            get
            {
                var wordLenght = GetWordLenght();
                var sb = new StringBuilder(wordLenght);
                for (var i = 0; i < wordLenght; i++)
                    sb.Append(GetChar());
                return sb.ToString();
            }
        }

        public static string Id
        {
            get
            {
                var wordLenght = GetIdLenght();
                var sb = new StringBuilder(wordLenght);
                for (var i = 0; i < wordLenght; i++)
                    sb.Append(GetDigit());
                return sb.ToString();
            }
        }

        public static string Phrase
        {
            get
            {
                var phraseLenght = GetPhraseLenght();
                var sb = new StringBuilder(phraseLenght);
                sb.Append(Name);
                for (var i = 0; i < phraseLenght; i++)
                    sb.Append(Word + GetPunctuation());
                return sb.ToString();
            }
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

        private static int GetWordLenght()
        {
            return Rand.Next(1, 29);
        }

        private static int GetIdLenght()
        {
            return Rand.Next(1, 10);
        }

        private static int GetPhraseLenght()
        {
            return Rand.Next(1, 20);
        }
    }
}