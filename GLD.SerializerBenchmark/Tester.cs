using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using GLD.SerializerBenchmark.TestData;

namespace GLD.SerializerBenchmark
{
    internal struct Measurements
    {
        public int Size;
        public long Time;
        public long TimeSer;
        public long TemeDeser;
    }

    internal class Tester
    {
        public static void Tests(int repetitions, List<ISerDeser> serializers, Dictionary<string, ITestData> testData)
        {
            Report.Repetitions(repetitions);
            foreach (var testDataItem in testData)
            {
                Report.TestDataHeader(testDataItem.Key);
                TestsOnData(repetitions, serializers, testDataItem, false);
                TestsOnData(repetitions, serializers, testDataItem, true);
            }
        }

        public static void TestsOnData(int repetitions, List<ISerDeser> serializers,
            KeyValuePair<string, ITestData> testDataItem, bool streaming)
        {
            var aborts = new List<string>();
            var measurements = new Dictionary<string, Measurements[]>();
            foreach (var serializer in serializers)
                measurements[serializer.Name] = new Measurements[repetitions];
            var original = testDataItem.Value.Generate(); // the same data for all serializers
            Report.StringOrStream(streaming);
            //Report.TestDataHeader(testDataItem.Key);
            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
            for (var i = 0; i < repetitions; i++)
                TestOnSerializer(serializers, original, measurements, i, aborts, streaming);
            Report.AllResults(measurements, aborts);
        }

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestData original,
            Dictionary<string, Measurements[]> measurements, int repetition, List<string> aborts, bool streaming)
        {
            foreach (var serializer in serializers)
                measurements[serializer.Name][repetition] = streaming
                    ? SingleTestOnStream(serializer, original, aborts)
                    : SingleTest(serializer, original, aborts);

            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static Measurements SingleTest(ISerDeser serializer, ITestData original,
            List<string> aborts)
        {
            var measurement = new Measurements();
            var errors = new List<string> {serializer.Name};
            string serialized = null;
            ITestData processed = null;

            var sw = Stopwatch.StartNew();
            try
            {
                serialized = serializer.Serialize<Person>(original);
                measurement.Size = serialized.Length;
                measurement.TimeSer = sw.ElapsedTicks;

                processed = serializer.Deserialize<Person>(serialized);
                measurement.Time = sw.ElapsedTicks;
                measurement.TemeDeser = measurement.Time - measurement.TimeSer;
            }
            catch (Exception ex)
            {
                aborts.Add(Environment.NewLine + serializer.Name + ":\n\t" + ex.Message);
                return measurement;
            }
            sw.Stop();

            Report.TimeAndDocument(serializer.Name, measurement.Time, serialized);

            errors.AddRange(original.Compare(processed));
            Report.Errors(errors);

            return measurement;
        }

        private static Measurements SingleTestOnStream(ISerDeser serializer, ITestData original,
            List<string> aborts)
        {
            var measurement = new Measurements();
            var errors = new List<string> {serializer.Name};
            Stream serializedStream = new MemoryStream();
            ITestData processed = null;

            var sw = Stopwatch.StartNew();
            try
            {
                serializer.Serialize<Person>(original, serializedStream);
                measurement.Size = (int) serializedStream.Length;
                measurement.TimeSer = sw.ElapsedTicks;

                serializedStream.Position = 0;
                processed = serializer.Deserialize<Person>(serializedStream);
                measurement.Time = sw.ElapsedTicks;
                measurement.TemeDeser = measurement.Time - measurement.TimeSer;
            }
            catch (Exception ex)
            {
                aborts.Add(Environment.NewLine + serializer.Name + ":\n\t" + ex.Message);
                return measurement;
            }
            sw.Stop();

            //Report.TimeAndDocument(serializer.Name, measurement.Time, serializedStream);
            string error;
            if (!Comparer.Compare(original, processed, out error, true))
                errors.Add(error);
            Report.Errors(errors);

            return measurement;
        }
    }
}