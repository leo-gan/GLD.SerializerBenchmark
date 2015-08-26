using System.Collections.Generic;
using System.Runtime.Serialization.Json;
using GLD.SerializerBenchmark.Serializers;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark
{
    internal class Program
    {
        private static void Main(string[] args)
        {
            var repetitions = int.Parse(args[0]);

            var testDataDescriptions = new List<ITestDataDescription>
            {
                new IntDescription(),
                new StringArrayDescription(),
                new SimleObjectDescription(),
                new TelemetryDescription(),
                new PersonDescription(),
                new EDI_X12_835Description(),
                // new TestData.NoAtributes.EDI_X12_835Description(),
            };
            var serializers = new List<ISerDeser>
            {
                //new AvroSerializer(),  TODO: For some reason it is impossible to pass generic T type to serializer.
                new BinarySerializer(),
                new BondCompactSerializer(),
                new BondFastSerializer(),
                new BondJsonSerializer(),
                new DataContractSerializerSerializer(),
                new DataContractJsonSer(),
                //new JavaScriptSerializer(), // TODO: DateTime format?
                //new XmlSerializer(typeof (Person), new[] {typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                new ApJsonSerializer(), // TODO: DateTime format?
                new FastJsonSerializer(), // TODO: DateTime format?
                //new JilSerializer(), // TODO: DateTime format?
                //new JsonFxSerializer(), // TODO: DateTime format?
                //new JsonNetHelperSerializer(),
                //new JsonNetSerializer(),
                new HaveBoxJSONSerializer(), // TODO: DateTime format?
                //new MessageSharkSer(),
                //new MsgPackSerializer(), // TODO: DateTime format?
                ////new NetJSONSer(), // TODO: DateTime format?
                //new NetSerializerSerializer(new[]
                //{typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                //new NfxJsonSerializer(new[] {typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                //new NfxSlimSerializer(new[] {typeof (Person), typeof (Gender), typeof (Passport), typeof (PoliceRecord)}),
                //new ProtoBufSerializer(),
                //new SharpSerializer(), // TODO: DateTime format?
                //new ServiceStackJsonSerializer(), // TODO: DateTime format?
                //new ServiceStackTypeSerializer(), // TODO: DateTime format?
                //new SalarBoisSerializer()
            };

            Tester.TestsOnData(serializers, testDataDescriptions, repetitions);
        }
    }
}