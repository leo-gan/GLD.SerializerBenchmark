using System;
using System.Collections.Generic;

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

            var repetitions = int.Parse(args[0]);
            Console.WriteLine("Repetitions: " + repetitions);
            var serializers = new Dictionary<string, ISerDeser>
            {
                {"JsonNetSerializer",new JsonNetSerializer()},
                {"JsonNetStreamSerializer",new JsonNetStreamSerializer()},
                {"XmlSerializer",new XmlSerializer(typeof (Person))},
                {"BinarySerializer",new BinarySerializer()},
                {"MsgPackSerializer", new MsgPackSerializer()},  // TODO: DateTime format?
                //{"BondSerializer", new BondSerializer(typeof(Person))}, // TODO: It doesnt not yet. 
                {"ProtoBufSerializer", new ProtoBufSerializer()},
                {"AvroSerializer", new AvroSerializer()},
                {"JilSerializer", new JilSerializer()},  // TODO: DateTime format?
                {"ServiceStackTypeSerializer", new ServiceStackTypeSerializer()},  // TODO: DateTime format?
                {"ServiceStackJsonSerializer", new ServiceStackJsonSerializer()},  // TODO: DateTime format?
                {"JsonFxSerializer", new JsonFxSerializer()},  // TODO: DateTime format?
            };

            Tester.Tests(repetitions, serializers);
        }
    }
}