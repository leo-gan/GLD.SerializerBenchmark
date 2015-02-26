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
        public static void Tests(int repetitions, Dictionary<string, ISerDeser> serializers)
        {
            var measurements = new Dictionary<string, Measurements[]>();
            foreach (var serializer in serializers)
                measurements[serializer.Key] = new Measurements[repetitions];
            var original = new Person(); // the same data for all serializers
            for (int i = 0; i < repetitions; i++)
                foreach (var serializer in serializers)
                {
                    var sw = Stopwatch.StartNew();
                    string serialized = serializer.Value.Serialize<Person>(original);

                    measurements[serializer.Key][i].Size = serialized.Length;

                    var processed = serializer.Value.Deserialize<Person>(serialized);

                    sw.Stop();
                    measurements[serializer.Key][i].Time = sw.ElapsedTicks;
                    Trace.WriteLine(serialized);
                    Trace.WriteLine(sw.ElapsedTicks);
                    List<string> errors = original.Compare(processed);
                    errors[0] = serializer.Key + errors[0];
                    ReportErrors(errors);
                }
            ReportAllResults(measurements);
        }

        private static void ReportAllResults(Dictionary<string, Measurements[]> measurements)
        {
            foreach (var oneTestMeasurments in measurements)
                ReportTestResult(oneTestMeasurments);
        }

        private static void ReportTestResult(
            KeyValuePair<string, Measurements[]> oneTestMeasurements)
        {
            string report = String.Format("{0, -30}: Average: Time: {1,9:N0} ticks  Size: {2,7}",
                oneTestMeasurements.Key,
                AverageTime(oneTestMeasurements.Value), AverageSize(oneTestMeasurements.Value));

            Console.WriteLine(report);
            Trace.WriteLine(report);
        }

        private static void ReportErrors(List<string> errors)
        {
            // Calculate the total times discarding
            // the 5% min and 5% max test times
            if (errors.Count <= 1) return;
            foreach (string error in errors)
            {
                Trace.WriteLine(error);
                Console.WriteLine(error);
            }
        }

        public static double AverageTime(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            var times = new long[measurements.Length];
            for (int i = 0; i < measurements.Length; i++)
                times[i] = measurements[i].Time;

            Array.Sort(times);
            int repetitions = times.Length;
            long totalTime = 0;
            var discardCount = (int) Math.Round(repetitions*0.05);
            int count = repetitions - discardCount;
            for (int i = discardCount; i < count; i++)
                totalTime += times[i];

            return ((double) totalTime)/(count - discardCount);
        }

        public static int AverageSize(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            long totalSizes = 0;
            for (int i = 0; i < measurements.Length; i++)
                totalSizes += measurements[i].Size;

            return (int) (totalSizes/measurements.Length);
        }
    }
}