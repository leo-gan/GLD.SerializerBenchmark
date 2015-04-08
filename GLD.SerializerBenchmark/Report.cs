using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace GLD.SerializerBenchmark
{
    internal static class Report
    {
        public static void AllResults(Dictionary<string, Measurements[]> measurements)
        {
            Header();
            foreach (var oneTestMeasurments in measurements)
                SingleResult(oneTestMeasurments);
        }

        public static void TimeAndDocument(string name, long timeTicks, string document)
        {
            Trace.WriteLine(name + ": " + timeTicks + " ticks Document: " + document);
        }

        public static void Errors(List<string> errors)
        {
            if (errors.Count <= 1) return;
            foreach (string error in errors)
            {
                Trace.WriteLine(error);
                //Console.WriteLine(error);
            }
        }

        private static void SingleResult(KeyValuePair<string, Measurements[]> oneTestMeasurements)
        {
            string report =
                String.Format("{0, -22} {1,7:N0} {2,7:N0} {3,7:N0} {4,9:N0} {5,10:N0} {6,9:N0}",
                    oneTestMeasurements.Key, AverageTime(oneTestMeasurements.Value, 10),
                    AverageTime(oneTestMeasurements.Value, 5),
                    AverageTime(oneTestMeasurements.Value), MinTime(oneTestMeasurements.Value),
                    MaxTime(oneTestMeasurements.Value), AverageSize(oneTestMeasurements.Value));

            Console.WriteLine(report);
            Trace.WriteLine(report);
        }

        private static void Header()
        {
            string header = "Serializer:     Time:  Avg-80%    -90%   -100%       Min        Max  Size: Avg\n"
                            +
                            "=============================================================================";
            Console.WriteLine(header);
            Trace.WriteLine(header);
        }

     

        private static double MaxTime(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return PrepareTimes(measurements).Max();
        }

        private static double MinTime(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return PrepareTimes(measurements).Min();
        }

        private static double AverageTime(Measurements[] measurements, int discardedPercent = 0)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            var times = PrepareTimes(measurements);

            Array.Sort(times);
            int repetitions = times.Length;
            long totalTime = 0;
            var discardCount = 0;
            if (discardedPercent != 0)
            {
                discardCount = (int) Math.Round(repetitions*(double) discardedPercent/100);
                if (discardCount == 0 && repetitions > 2) discardCount = 1;
            }
            int count = repetitions - discardCount;
            for (int i = discardCount; i < count; i++)
                totalTime += times[i];

            return ((double) totalTime)/(count - discardCount);
        }

        private static long[] PrepareTimes(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return null;
            var times = new long[measurements.Length];
            for (int i = 0; i < measurements.Length; i++)
                times[i] = measurements[i].Time;
            return times;
        }

        private static int AverageSize(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            long totalSizes = 0;
            for (int i = 0; i < measurements.Length; i++)
                totalSizes += measurements[i].Size;

            return (int) (totalSizes/measurements.Length);
        }
    }
}