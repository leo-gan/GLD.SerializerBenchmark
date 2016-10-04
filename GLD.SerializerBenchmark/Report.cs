using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;

namespace GLD.SerializerBenchmark
{
    internal static class Report
    {
        public static void AllResults(int repetitions, LogStorage logStorage, List<Error> errors)
        {
            HeaderRepetitions(repetitions);
            logStorage.CloseStorage(); // close file if it is still opened for writing.
            var logs = logStorage.ReadAll();

            var aggregatedResults = logs
                .Select(a => a)
                .Where(w => w.RepetitionIndex != 0) // do not include a warm up in aggregation
                .GroupBy(a => new {a.Repetitions, a.TestDataName, a.SerializerName, a.StringOrStream})
                .Select(g =>
                    new AggregateLogs
                    {
                        StringOrStream = g.Key.StringOrStream,
                        TestDataName = g.Key.TestDataName,
                        SerializerName = g.Key.SerializerName,
                        Repetitions = g.Key.Repetitions,
                        OpPerSecDeserAver = g.Average(kg => kg.OpPerSecDeser),
                        //OpPerSecDeserMin = g.Min(kg => kg.OpPerSecDeser),
                        //OpPerSecDeserMax = g.Max(kg => kg.OpPerSecDeser),
                        OpPerSecSerAver = g.Average(kg => kg.OpPerSecSer),
                        //OpPerSecSerMin = g.Min(kg => kg.OpPerSecSer),
                        //OpPerSecSerMax = g.Max(kg => kg.OpPerSecSer),
                        OpPerSecSerAndDeserAver = g.Average(kg => kg.OpPerSecSerAndDeser),
                        //OpPerSecSerAndDeserMin = g.Min(kg => kg.OpPerSecSerAndDeser),
                        //OpPerSecSerAndDeserMax = g.Max(kg => kg.OpPerSecSerAndDeser),
                        SizeAver = (int) g.Average(kg => kg.Size)
                    });
            Aggregated(aggregatedResults, errors);
        }

        private static void Aggregated(IEnumerable<AggregateLogs> aggregatedResults, List<Error> errors)
        {
            var testDataNames = aggregatedResults
                .Select(res => res.TestDataName)
                .Distinct()
                .ToList();

            // for each Test Data type
            foreach (var testDataName in testDataNames)
            {
                OnTestData(testDataName, aggregatedResults, errors);
                OnTestDataErrors(testDataName, errors);
            }
        }

        private static void OnTestData(string testDataName, IEnumerable<AggregateLogs> aggregatedResults,
            List<Error> errors)
        {
            HeaderTestData(testDataName);

            //var serNames = aggregatedResults.Select(res => res.SerializerName).Distinct().ToList();
            //// for each serializer
            //foreach (var serName in serNames)
            //{
            //    var serResult =
            //        aggregatedResults.Select(a => a)
            //            .Where(a => a.SerializerName == serName && a.TestDataName == testDataName);
            //    OnAggregator(serResult);
            //}
            var serResult = aggregatedResults
                .Where(a => a.TestDataName == testDataName)
                .OrderByDescending(a => a.OpPerSecSerAndDeserAver);
            foreach (var oneSer in serResult)
                OnAggregator(oneSer);
        }

        private static void OnAggregator(AggregateLogs serResult)
        {
            if (serResult == null) return;

            const string formatString = "{0, -21} {1, -6}   {2,12:N0} {3,10:N0} {4,10:N0} {5,10:N0}";
            var stringAggregator = string.Format(formatString,
                serResult.SerializerName, serResult.StringOrStream,
                serResult.OpPerSecSerAver, serResult.OpPerSecDeserAver, serResult.OpPerSecSerAndDeserAver,
                serResult.SizeAver);

            OutputEverywhere(stringAggregator);
        }

        private static void HeaderTestData(string testDataName)
        {
            var header =
                string.Format(
                    "\nTest Data: {0}\nSerializer:               Ops/sec Avg:  Ser      Deser   Ser+Deser  Size: Avg\n"
                    + new string('=', 79), testDataName);
            OutputEverywhere(header);
        }

        private static void OnTestDataErrors(string testDataName, List<Error> errors)
        {
            if (errors == null) return;
            if (errors.Count == 0) return;

            var testDataErrors =
                errors.Select(a => a)
                    .Where(b => b.TestDataName == testDataName)
                    .OrderBy(sr => sr.SerializerName)
                    .ToList();
            if (testDataErrors.Count == 0) return;
            HeaderErrors(testDataName);
            foreach (var error in testDataErrors)
            {
                var line = string.Format("{0, -21} -{1, -6}s \n\t{2}",
                    error.SerializerName, error.StringOrStream, error.ErrorText);
                OutputEverywhere(line);
            }
        }

        private static void HeaderRepetitions(int repetitions)
        {
            var header = string.Format("\n\nTests performed {0} times for each TestData + Serializer pair\n",
                repetitions)
                         + new string('#', 80);
            OutputEverywhere(header);
        }

        private static void HeaderErrors(string testDataName)
        {
            var line = string.Format("\nErrors in {0}\n"
                                     + new string('.', 80), testDataName);
            OutputEverywhere(line);
        }

        private static void OutputEverywhere(string line)
        {
            Console.WriteLine(line);
            Trace.WriteLine(line);
        }
    }

    internal class AggregateLogs
    {
        public string StringOrStream { get; set; }

        public string TestDataName { get; set; }

        /// <summary>
        ///     A number of repetitions in a single Run
        /// </summary>
        public int Repetitions { get; set; }

        public string SerializerName { get; set; }

        public double OpPerSecSerAver { get; set; }
        public double OpPerSecSerMin { get; set; }
        public double OpPerSecSerMax { get; set; }

        public double OpPerSecDeserAver { get; set; }
        public double OpPerSecDeserMin { get; set; }
        public double OpPerSecDeserMax { get; set; }

        public double OpPerSecSerAndDeserAver { get; set; }
        public double OpPerSecSerAndDeserMin { get; set; }
        public double OpPerSecSerAndDeserMax { get; set; }

        public int SizeAver { get; set; }
    }
}