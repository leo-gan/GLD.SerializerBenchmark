using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace GLD.SerializerBenchmark
{
    internal struct Measurements
    {
        public int Size;
        public long Time;
    }

    internal class Tester
    {
        public static void Tests(int repetitions, List<ISerDeser> serializers, Dictionary<string, ITestData> testData)
        {
            Report.Repetitions(repetitions);
            foreach (var testDataItem in testData)
                TestsOnData(repetitions, serializers, testDataItem);
        }

        public static void TestsOnData(int repetitions, List<ISerDeser> serializers,
            KeyValuePair<string, ITestData> testDataItem)
        {
            var aborts = new List<string>();
            var measurements = new Dictionary<string, Measurements[]>();
            foreach (var serializer in serializers)
                measurements[serializer.Name] = new Measurements[repetitions];
            var original = testDataItem.Value.Generate(); // the same data for all serializers
            Report.TestDataHeader(testDataItem.Key);
            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
            for (var i = 0; i < repetitions; i++)
                TestOnSerializer(serializers, original, measurements, i, aborts);
            Report.AllResults(measurements, aborts);
        }

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestData original,
            Dictionary<string, Measurements[]> measurements, int repetition, List<string> aborts)
        {
            foreach (var serializer in serializers)
                SingleTest(serializer, original, measurements, repetition, aborts);

            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static void SingleTest(ISerDeser serializer, ITestData original,
            Dictionary<string, Measurements[]> measurements, int repetition, List<string> aborts)
        {
            var errors = new List<string>();
            errors.Add(serializer.Name);
            string serialized = null;
            Person processed = null;

            var sw = Stopwatch.StartNew();
            try
            {
                serialized = serializer.Serialize<Person>(original);
                measurements[serializer.Name][repetition].Size = serialized.Length;

                processed = serializer.Deserialize<Person>(serialized);
            }
            catch (Exception ex)
            {
                aborts.Add("Serializer: " + serializer.Name + " Exception: \n\t" + ex.Message);
                return;
            }
            sw.Stop();

            measurements[serializer.Name][repetition].Time = sw.ElapsedTicks;
            Report.TimeAndDocument(serializer.Name, sw.ElapsedTicks, serialized);

            errors.AddRange(original.Compare(processed));
            Report.Errors(errors);
        }
    }
}