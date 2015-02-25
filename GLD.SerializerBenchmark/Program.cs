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

            Tester.Tests(repetitions, new JsonNetSerializer(), "JsonNetSerializer");
            Tester.Tests(repetitions, new JsonNetStreamSerializer(), "JsonNetStreamSerializer");
            Tester.Tests(repetitions, new XmlSerializer(typeof(Person)), "XmlSerializer");
            Tester.Tests(repetitions, new BinarySerializer(), "BinarySerializer");
            Tester.Tests(repetitions, new MsgPackSerializer(), "MsgPackSerializer"); // TODO: DateTime format?
            // Tester.Tests(repetitions, new BondSerializer(typeof(Person)), "BondSerializer"); // TODO: It doesnt not yet. 
            Tester.Tests(repetitions, new ProtoBufSerializer(), "ProtoBufSerializer");
            Tester.Tests(repetitions, new AvroSerializer(), "AvroSerializer");
            Tester.Tests(repetitions, new JilSerializer(), "JilSerializer"); // TODO: DateTime format?
        }
    }
}