using System;
using System.Collections.Generic;
using System.Diagnostics;

namespace GLD.SerializerBenchmark
{
    internal class Tester
    {
        public static void Tests(int repetitions, ISerDeser serializer, string serializerName)
        {
            var sw = new Stopwatch();
            var times = new long[repetitions];
            var lenghts = new long[repetitions];
            for (int i = 0; i < repetitions; i++)
            {
                var original = new Person();
                sw.Start();
                string serialized = serializer.Serialize<Person>(original);
                lenghts[i] = serialized.Length;
                var processed = serializer.Deserialize<Person>(serialized);
                sw.Stop();
                Trace.WriteLine(serialized);
                times[i] = sw.ElapsedMilliseconds;
                Trace.WriteLine(sw.ElapsedMilliseconds);
                List<string> errors = original.Compare(processed);
                if (errors.Count <= 1) continue;
                foreach (string error in errors)
                {
                    Trace.WriteLine(error);
                    Console.WriteLine(error);
                }
            }

            // Calculate the total times discarding
            // the 5% min and 5% max test times
            double averageTime = AverageTime(times);
            // TODO: Utilize lenghts information
            string report = String.Format("{0}: Average time: {1:N2} ms", serializerName,
                averageTime);
            Console.WriteLine(report);
            Trace.WriteLine(report);
        }

        public static double AverageTime(long[] times)
        {
            if (times == null || times.Length == 0) return 0;

            Array.Sort(times);
            int repetitions = times.Length;
            long totalTime = 0;
            var discardCount = (int) Math.Round(repetitions*0.05);
            int count = repetitions - discardCount;
            for (int i = discardCount; i < count; i++)
                totalTime += times[i];

            return ((double) totalTime)/(count - discardCount);
        }
    }
}