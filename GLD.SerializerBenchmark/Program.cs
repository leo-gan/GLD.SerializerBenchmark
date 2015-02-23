using System;

namespace GLD.SerializerBenchmark
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            // Input:
            // SerializerName[Json.NET, Bond...] / Format[JSON, XML, Binary, Specific...] / 
            // Data [int, string, class...] / Quantity
            // Output: Avrg

            int repetitions = int.Parse(args[0]);
            Console.WriteLine("Repetions: " + repetitions);

            Tester.Tests(repetitions, new JsonNet(), "JsonNet");
            Tester.Tests(repetitions, new XmlSerializer(typeof(Person)), "XmlSerializer");
            Tester.Tests(repetitions, new BinarySerializer(), "BinarySerializer");
        }
    }
}