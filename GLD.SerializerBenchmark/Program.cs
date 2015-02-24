using System;

namespace GLD.SerializerBenchmark
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            // Input:
            // SerializerName[Json.NET, Bond...] / Format[JSON, XML, Binary, Specific...] / 
            // Data [int, string, class...] / TestRepetitions
            // Output: Average time per serialization + deserialization

            int repetitions = int.Parse(args[0]);
            Console.WriteLine("Repetitions: " + repetitions);

            Tester.Tests(repetitions, new JsonNet(), "JsonNet");
            Tester.Tests(repetitions, new JsonNetStream(), "JsonNetStream");
            Tester.Tests(repetitions, new XmlSerializer(typeof(Person)), "XmlSerializer");
            Tester.Tests(repetitions, new BinarySerializer(), "BinarySerializer");
            Tester.Tests(repetitions, new MsgPackSerializer(), "MsgPackSerializer");
        }
    }
}