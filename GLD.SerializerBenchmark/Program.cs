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
                {"Avro", new AvroSerializer(typeof(Person))},
                {"BinarySerializer",new BinarySerializer()},
                //{"BondSerializer", new BondSerializer(typeof(Person))}, // TODO: It does not debugged yet. 
                {"DataContract", new DataContractSerializerSerializer(typeof(Person))},  
                {"DataContractJsonSer...", new DataContractJsonSerializer(typeof(Person))},  
                {"fastJson", new FastJsonSerializer()},  // TODO: DateTime format?
                {"JavaScriptSerializer", new JavaScriptSerializer()},  // TODO: DateTime format?
                {"Jil", new JilSerializer()},  // TODO: DateTime format?
                {"JsonFx", new JsonFxSerializer()},  // TODO: DateTime format?
                {"JsonNet",new JsonNetSerializer()},
                {"JsonNetStream",new JsonNetStreamSerializer()},
                {"MsgPack", new MsgPackSerializer()},  // TODO: DateTime format?
                {"NetSerializer", new NetSerializerSerializer(typeof(Person))},  
                {"ProtoBuf", new ProtoBufSerializer()},
                {"SharpSerializer", new SharpSerializer()},   // TODO: DateTime format?
                {"ServiceStackJson", new ServiceStackJsonSerializer()},  // TODO: DateTime format?
                {"ServiceStackType", new ServiceStackTypeSerializer()},  // TODO: DateTime format?
                {"XmlSerializer",new XmlSerializer(typeof (Person))},
           };

            Tester.Tests(repetitions, serializers);
        }
    }
}