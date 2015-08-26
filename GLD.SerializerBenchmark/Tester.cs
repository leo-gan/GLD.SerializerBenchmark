using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

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
        public static void TestsOnData(List<ISerDeser> serializers, List<ITestDataDescription> testDataDescriptions,
            int repetitions)
        {
            Report.Repetitions(repetitions);
            // initialize all serializers 
            foreach (var testDataDescription in testDataDescriptions)
            {
                Report.TestDataHeader(testDataDescription);
                // initialize serializers for every data type.
                foreach (var serializer in serializers)
                    serializer.Initialize(testDataDescription.DataType, testDataDescription.SecondaryDataTypes);
                TestsOnRepetition(serializers, testDataDescription, repetitions, false);
                TestsOnRepetition(serializers, testDataDescription, repetitions, true);
            }
        }

        public static void TestsOnRepetition(List<ISerDeser> serializers,
            ITestDataDescription testDataDescription, int repetitions, bool streaming)
        {
            var aborts = new List<string>();
            var measurements = new Dictionary<string, Measurements[]>();
            foreach (var serializer in serializers)
                measurements[serializer.Name] = new Measurements[repetitions];
            var original = testDataDescription; // the same data for all serializers
            Report.StringOrStream(streaming);
            //Report.TestDataHeader(testDataDescription.Key);
            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();

            for (var i = 0; i < repetitions; i++)
                TestOnSerializer(serializers, original, i, measurements, aborts, streaming);
            Report.AllResults(measurements, aborts);
        }

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestDataDescription original, int repetition,
            Dictionary<string, Measurements[]> measurements, List<string> aborts, bool streaming)
        {
            foreach (var serializer in serializers)
                measurements[serializer.Name][repetition] = streaming
                    ? SingleTestOnStream(serializer, original, aborts)
                    : SingleTest(serializer, original, aborts);

            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static Measurements SingleTest(ISerDeser serializer, ITestDataDescription original,
            List<string> aborts)
        {
            var measurement = new Measurements();
            var errors = new List<string> {serializer.Name};
            string serialized = null;
            object processed = null;

            var sw = Stopwatch.StartNew();
            try
            {
                serialized = serializer.Serialize(original.Data);
                measurement.Size = serialized.Length;
                measurement.TimeSer = sw.ElapsedTicks;

                processed = serializer.Deserialize(serialized);
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

            string error;
            if (!Comparer.Compare(original.Data, processed, out error, true))
                errors.Add(error);
            Report.Errors(errors);

            return measurement;
        }

        private static Measurements SingleTestOnStream(ISerDeser serializer, ITestDataDescription original,
            List<string> aborts)
        {
            var measurement = new Measurements();
            var errors = new List<string> {serializer.Name};
            Stream serializedStream = new MemoryStream();
            object processed = null;

            var sw = Stopwatch.StartNew();
            try
            {
                serializer.Serialize(original.Data, serializedStream);
                measurement.Size = (int) serializedStream.Length;
                measurement.TimeSer = sw.ElapsedTicks;

                serializedStream.Position = 0;
                processed = serializer.Deserialize(serializedStream);
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
            if (!Comparer.Compare(original.Data, processed, out error, true))
                errors.Add(error);
            Report.Errors(errors);

            return measurement;
        }
    }
}