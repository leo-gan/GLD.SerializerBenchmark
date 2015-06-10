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
        public static void Tests(int repetitions, Dictionary<string, ISerDeser> serializers, Dictionary<string, ITestData> testData)
        {
            Report.Repetitions(repetitions);
            foreach (var testDataItem in testData)
                TestsOnData(repetitions, serializers, testDataItem);
        }

        public static void TestsOnData(int repetitions, Dictionary<string, ISerDeser> serializers, KeyValuePair<string, ITestData> testDataItem)
        {
            var measurements = new Dictionary<string, Measurements[]>();
            foreach (var serializer in serializers)
                measurements[serializer.Key] = new Measurements[repetitions];
            var original = testDataItem.Value.Generate(); // the same data for all serializers
            Report.TestDataHeader(testDataItem.Key);
            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
            for (var i = 0; i < repetitions; i++)
                TestOnSerializer(serializers, original, measurements, i);
            Report.AllResults(measurements);
        }

        private static void TestOnSerializer(Dictionary<string, ISerDeser> serializers, ITestData original, Dictionary<string, Measurements[]> measurements, int repetition)
        {
            foreach (var serializer in serializers)
            {
                SingleTest(serializer, original, measurements, repetition);
            }
            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static void SingleTest(KeyValuePair<string, ISerDeser> serializer, ITestData original, Dictionary<string, Measurements[]> measurements, int repetition)
        {
            var sw = Stopwatch.StartNew();
            var serialized = serializer.Value.Serialize<Person>(original);

            measurements[serializer.Key][repetition].Size = serialized.Length;

            var processed = serializer.Value.Deserialize<Person>(serialized);

            sw.Stop();
            measurements[serializer.Key][repetition].Time = sw.ElapsedTicks;
            Report.TimeAndDocument(serializer.Key, sw.ElapsedTicks, serialized);
            var errors = original.Compare(processed);
            errors[0] = serializer.Key + errors[0];
            Report.Errors(errors);
        }
    }
}