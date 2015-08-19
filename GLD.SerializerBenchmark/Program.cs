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
                {"Person (nested objects and an array)", new Person()}
            };
            var serializers = new List<ISerDeser>
            {
                new AvroSerializer(typeof (Person)),
                new BinarySerializer(),
                new BondSerializer(typeof (Person)),
                new BondJsonSerializer(typeof (Person)),
                new DataContractSerializerSerializer(typeof (Person),
                    new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                new DataContractJsonSerializer(typeof (Person),
                    new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                new JavaScriptSerializer(), // TODO: DateTime format?
                new XmlSerializer(typeof (Person), new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                new ApJsonSerializer(), // TODO: DateTime format?
                new FastJsonSerializer(), // TODO: DateTime format?
                new JilSerializer(), // TODO: DateTime format?
                new JsonFxSerializer(), // TODO: DateTime format?
                new JsonNetSerializer(),
                new JsonNetStreamSerializer(),
                new HaveBoxJSON(), // TODO: DateTime format?
                new MessageSharkSer(),
                new MsgPackSerializer(), // TODO: DateTime format?
                new NetJSONSer(), // TODO: DateTime format?
                new NetSerializerSerializer(new[]
                {typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                new SlimSerializer(new[] {typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                new ProtoBufSerializer(),
                new SharpSerializer(), // TODO: DateTime format?
                new ServiceStackJsonSerializer(), // TODO: DateTime format?
                new ServiceStackTypeSerializer(), // TODO: DateTime format?
                new SalarBoisSerializer()
            };

            Tester.Tests(repetitions, serializers, testData);
        }
    }
}