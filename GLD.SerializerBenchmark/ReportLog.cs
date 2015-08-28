using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NFX;

namespace GLD.SerializerBenchmark
{
    internal  static class ReportLog
    {
        public static void AllResults(List<Log> logs)
        {
            Header();
            var aggregatedResults = from l in logs
                group l by new
                {
                    l.StringOrStream,
                    l.TestDataName,
                    l.SerializerName,
                    l.Repetitions
                }
                into g
                select new AggregateResults
                {
                    StringOrStream = g.Key.StringOrStream,
                    TestDataName = g.Key.TestDataName,
                    SerializerName = g.Key.SerializerName,
                    Repetitions = g.Key.Repetitions,

                    OpPerSecDeserAver = g.Average(g => g.OpPerSecDeser),
                    OpPerSecDeserMin = g.Min(g => g.OpPerSecDeser),
                    OpPerSecDeserMax = g.Max(g => g.OpPerSecDeser),

                    OpPerSecSerAver = g.Average(g => g.OpPerSecSer),
                    OpPerSecSerMin = g.Min(g => g.OpPerSecSer),
                    OpPerSecSerMax = g.Max(g => g.OpPerSecSer),

                    OpPerSecSerAndDeserAver = g.Average(g => g.OpPerSecSerAndDeser),
                    OpPerSecSerAndDeserMin = g.Min(g => g.OpPerSecSerAndDeser),
                    OpPerSecSerAndDeserMax = g.Max(g => g.OpPerSecSerAndDeser),

                    SizeAver = g.Average(g => g.Size),
                };
        }
    }

    internal class AggregateResults
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

        public  double OpPerSecDeserAver { get; set; }
        public double OpPerSecDeserMin { get; set; }
        public double OpPerSecDeserMax { get; set; }

        public  double OpPerSecSerAndDeserAver { get; set; }
        public double OpPerSecSerAndDeserMin { get; set; }
        public double OpPerSecSerAndDeserMax { get; set; }

        public int SizeAver { get; set; }

        public string Note { get; set; }
    }
}
