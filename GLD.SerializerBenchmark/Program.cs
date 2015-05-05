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
                {"MS Avro", new AvroSerializer(typeof(Person))}, 
                {"MS Binary",new BinarySerializer()},
                {"BondSerializer", new BondSerializer(typeof(Person))}, // TODO: It does not debugged yet. 
                {"MS DataContract", new DataContractSerializerSerializer(typeof(Person))},  
                {"MS DataContractJson", new DataContractJsonSerializer(typeof(Person))},  
                {"MS JavaScript", new JavaScriptSerializer()},  // TODO: DateTime format?
                {"MS NetDataContract", new NetDataContractSerializer(typeof(Person))},  
                {"MS XmlSerializer",new XmlSerializer(typeof (Person))},
                {"fastJson", new FastJsonSerializer()},  // TODO: DateTime format?
                {"Jil", new JilSerializer()},  // TODO: DateTime format?
                {"JsonFx", new JsonFxSerializer()},  // TODO: DateTime format?
                {"Json.Net (Helper)",new JsonNetSerializer()},
                {"Json.Net (Stream)",new JsonNetStreamSerializer()},
                {"MsgPack", new MsgPackSerializer()},  // TODO: DateTime format?
                {"NetSerializer", new NetSerializerSerializer(typeof(Person))},  
                {"ProtoBuf", new ProtoBufSerializer()},
                {"SharpSerializer", new SharpSerializer()},   // TODO: DateTime format?
                {"ServiceStack Json", new ServiceStackJsonSerializer()},  // TODO: DateTime format?
                {"ServiceStack Type", new ServiceStackTypeSerializer()},  // TODO: DateTime format?
           };

            Tester.Tests(repetitions, serializers);
        }
    }
}