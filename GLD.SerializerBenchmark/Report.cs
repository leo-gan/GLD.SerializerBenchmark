using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using Bond;

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
            foreach (var error in errors)
            {
                Trace.WriteLine(error);
                //Console.WriteLine(error);
            }
        }

        private static void SingleResult(KeyValuePair<string, Measurements[]> oneTestMeasurements)
        {
            var report =
                String.Format("{0, -20} {1,7:N0} {2,7:N0} {3,6:N0} {4,9:N0} {5,10:N0} {6,6:N0}",
                    oneTestMeasurements.Key,
                    //AverageTime(oneTestMeasurements.Value, 20),
                    AverageTime(oneTestMeasurements.Value, 10),
                    AverageTime(oneTestMeasurements.Value),
                    MinTime(oneTestMeasurements.Value),
                    P99Time(oneTestMeasurements.Value),
                    MaxTime(oneTestMeasurements.Value),
                    AverageSize(oneTestMeasurements.Value));

            Console.WriteLine(report);
            Trace.WriteLine(report);
        }

        private static void Header()
        {
            const string header = "Serializer:    Time: Avg-90%   -100%    Min    99st%      Max  Size: Avg\n"
                                  +
                                  "======================================++=================================";
            Console.WriteLine(header);
            Trace.WriteLine(header);
        }

        private static double P99Time(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return BottomPercent(measurements, 1).Select(m => m.Time).LastOrDefault();
        }
     

        private static double MaxTime(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return measurements.Max(m => m.Time);
        }

        private static double MinTime(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return measurements.Min(m => m.Time);
        }

        private static IEnumerable<Measurements> BottomPercent(Measurements[] measurements, int discardedPercent)
        {
            if (discardedPercent == 0) return measurements;
            var take = (int)Math.Round(measurements.Length * (100 - discardedPercent) / 100.0);
            return measurements.OrderBy(m => m.Time).Take(take);
        }

        private static double AverageTime(Measurements[] measurements, int discardedPercent = 0)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return BottomPercent(measurements, discardedPercent).Average(m => m.Time);
        }

        private static int AverageSize(Measurements[] measurements)
        {
            if (measurements == null || measurements.Length == 0) return 0;
            return (int)measurements.Average(m => m.Size);
        }
    }
}