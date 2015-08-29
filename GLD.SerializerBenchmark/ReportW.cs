using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace GLD.SerializerBenchmark
{
    internal static class ReportW
    {

        public static void AllResults(Dictionary<string, Measurement[]> measurements, List<Error> aborts)
        {
            Header();
            foreach (var oneTestMeasurments in measurements)
                SingleResult(oneTestMeasurments);
            Aborts(aborts);
        }

        private static void Aborts(List<Error> aborts)
        {
            if (aborts.Count <= 1) return;

            const string abortHeader = "\nABORTS: some serializers throw exceptions *********************\n";
            OutputEverywhere(abortHeader);

            aborts = aborts.Select(abort => abort).Distinct().ToList();
            foreach (var abort in aborts)
                OutputEverywhere(abort.ErrorText);
        }

        public static void TimeAndDocument(string name, long timeTicks, string document)
        {
            Trace.WriteLine(Environment.NewLine + name + ": " + timeTicks + " ticks Document: " + document);
        }

        public static void Errors(List<string> errors)
        {
            if (errors.Count == 1) return;
            foreach (var error in errors)
                Trace.WriteLine(error);
        }

        public static void Repetitions(int repetitions)
        {
            var str = "Repetitions: " + repetitions;
            OutputEverywhere(str);
        }

        public static void TestDataHeader(ITestDataDescription testDataDescription)
        {
            var name = "\nTest Data: " + testDataDescription.Name + " ";
            var str = name + new string('>', 80  - name.Length) 
                + "\n\t" + testDataDescription.Description;
            OutputEverywhere(str);
        }

        private static void OutputEverywhere(string line)
        {
            Console.WriteLine(line);
            Trace.WriteLine(line);
        }

        public static void StringOrStream(bool streaming)
        {
            var name = "\nSerialize / Deserialize to/from " + (streaming ? "Stream " : "String ");
            var str = name + new string('.', 80 - name.Length);
            OutputEverywhere(str);
        }

        private static void SingleResult(KeyValuePair<string, Measurement[]> oneTestMeasurements)
        {
            var report =
                //string.Format("{0, -20} {1,7:N0} {2,7:N0} {3,6:N0} {4,9:N0} {5,10:N0} {6,6:N0}",
                string.Format("{0, -20} {1,7:N0} {2,7:N0} {3,6:N0} {4,10:N0} {5,6:N0}",
                    oneTestMeasurements.Key,
                    //AverageTime(oneTestMeasurements.Value, 20),
                    AverageTime(oneTestMeasurements.Value, 10),
                    AverageTime(oneTestMeasurements.Value),
                    MinTime(oneTestMeasurements.Value),
                    //P99Time(oneTestMeasurements.Value),
                    MaxTime(oneTestMeasurements.Value),
                    AverageSize(oneTestMeasurements.Value));

            OutputEverywhere(report);
        }

        private static void Header()
        {
            var header = "\nSerializer:    Time: Avg-90%   -100%    Min      Max  Size: Avg\n"
                         + new string('=', 64);
            OutputEverywhere(header);
        }

        private static double P99Time(Measurement[] measurement)
        {
            if (measurement == null || measurement.Length == 0) return 0;
            return BottomPercent(measurement, 1).Select(m => m.Time).LastOrDefault();
        }

        private static double MaxTime(Measurement[] measurement)
        {
            if (measurement == null || measurement.Length == 0) return 0;
            return measurement.Max(m => m.Time);
        }

        private static double MinTime(Measurement[] measurement)
        {
            if (measurement == null || measurement.Length == 0) return 0;
            return measurement.Min(m => m.Time);
        }

        private static IEnumerable<Measurement> BottomPercent(Measurement[] measurement, int discardedPercent)
        {
            if (discardedPercent == 0) return measurement;
            var take = (int) Math.Round(measurement.Length*(100 - discardedPercent)/100.0);
            return measurement.OrderBy(m => m.Time).Take(take);
        }

        private static double AverageTime(Measurement[] measurement, int discardedPercent = 0)
        {
            if (measurement == null || measurement.Length == 0) return 0;
            return BottomPercent(measurement, discardedPercent).Average(m => m.Time);
        }

        private static int AverageSize(Measurement[] measurement)
        {
            if (measurement == null || measurement.Length == 0) return 0;
            return (int) measurement.Average(m => m.Size);
        }
    }
}