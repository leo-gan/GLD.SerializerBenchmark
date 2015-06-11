using System;
using System.Collections.Generic;

namespace GLD.SerializerBenchmark
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            var repetitions = int.Parse(args[0]);

            var testData = new Dictionary<string, ITestData>
            {
                {"Person (nested objects and an array)", new Person()}, 
            };
            var serializers = new Dictionary<string, ISerDeser>
            {
                {"MS Avro", new AvroSerializer(typeof (Person))},
                {"MS Binary", new BinarySerializer()},
                {"MS Bond", new BondSerializer(typeof (Person))},
                {"MS BondJson", new BondJsonSerializer(typeof (Person))},
                {"MS DataContract", new DataContractSerializerSerializer(typeof (Person), new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)})},
                {"MS DataContractJson", new DataContractJsonSerializer(typeof (Person), new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)})},
                {"MS JavaScript", new JavaScriptSerializer()}, // TODO: DateTime format?
                {"MS NetDataContract", new NetDataContractSerializer(typeof (Person), new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)})},
                {"MS XmlSerializer", new XmlSerializer(typeof (Person), new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)})},
                {"ApJson", new ApJsonSerializer()}, // TODO: DateTime format?
                {"fastJson", new FastJsonSerializer()}, // TODO: DateTime format?
                {"Jil", new JilSerializer()}, // TODO: DateTime format?
                {"JsonFx", new JsonFxSerializer()}, // TODO: DateTime format?
                {"Json.Net (Helper)", new JsonNetSerializer()},
                {"Json.Net (Stream)", new JsonNetStreamSerializer()},
                {"HaveBoxJSON", new HaveBoxJSON()}, // TODO: DateTime format?
                {"MessageShark", new MessageSharkSer()},
                {"MsgPack", new MsgPackSerializer()}, // TODO: DateTime format?
                {"NetJSON", new NetJSONSer()}, // TODO: DateTime format?
                {"NetSerializer", new NetSerializerSerializer(new[] {typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)})},
                {"NFX.SlimSerializer", new SlimSerializer(new[] {typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)}) },
                {"ProtoBuf", new ProtoBufSerializer()},
                {"SharpSerializer", new SharpSerializer()}, // TODO: DateTime format?
                {"ServiceStack Json", new ServiceStackJsonSerializer()}, // TODO: DateTime format?
                {"ServiceStack Type", new ServiceStackTypeSerializer()} // TODO: DateTime format?
            };

             Tester.Tests(repetitions, serializers, testData);
        }
    }
}