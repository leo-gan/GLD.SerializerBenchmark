using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace GLD.SerializerBenchmark
{
    internal struct Measurement
    {
        public int Size;
        public long TimeSer;
        public long TimeDeser;
        public long Time { get { return (TimeDeser - TimeSer) > 0 ? TimeDeser - TimeSer : 0; } }
    }

    internal class Tester
    {
        public static void TestsOnData(List<ISerDeser> serializers, List<ITestDataDescription> testDataDescriptions,
            int repetitions)
        {
            var logStorage = new LogStorage("SerializerBenchmark_Log.csv");

            Report.Repetitions(repetitions);
            // initialize all serializers 
            foreach (var testDataDescription in testDataDescriptions)
            {
                Report.TestDataHeader(testDataDescription);
                // initialize serializers for every data type.
                foreach (var serializer in serializers)
                    serializer.Initialize(testDataDescription.DataType, testDataDescription.SecondaryDataTypes);
                TestsOnRepetition(serializers, testDataDescription, repetitions, false, logStorage);
                TestsOnRepetition(serializers, testDataDescription, repetitions, true, logStorage);
            }
        }

        public static void TestsOnRepetition(List<ISerDeser> serializers, ITestDataDescription testDataDescription, int repetitions, bool streaming, LogStorage logStorage)
        {
            var aborts = new List<string>();
            var measurements = new Dictionary<string, Measurement[]>();
            foreach (var serializer in serializers)
                measurements[serializer.Name] = new Measurement[repetitions];
            var original = testDataDescription; // the same data for all serializers
            Report.StringOrStream(streaming);
            //Report.TestDataHeader(testDataDescription.Key);
            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();

            for (var i = 0; i < repetitions; i++)
            {
                var log = new Log
                {
                    Run = 1,
                    TestDataName = original.Name,
                    Repetitions = repetitions,
                    RepetitionIndex = i,
                    StringOrStream = streaming ? "Stream" : "string"
                };
                TestOnSerializer(serializers, original, i, measurements, aborts, streaming, logStorage, log);
            }
            Report.AllResults(measurements, aborts);
        }

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestDataDescription original, int repetition, Dictionary<string, Measurement[]> measurements, List<string> aborts, bool streaming, LogStorage logStorage, Log log)
        {
            foreach (var serializer in serializers)
                measurements[serializer.Name][repetition] = SingleTest(serializer, original, aborts, streaming, log, logStorage);

            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static Measurement SingleTest(ISerDeser serializer, ITestDataDescription original, List<string> aborts, bool streaming, Log log, LogStorage logStorage)
        {
            var measurement = new Measurement();
            var errors = new List<string> {serializer.Name};
            string serializedString = null;
            Stream serializedStream = new MemoryStream();
            object processed;
            log.SerializerName = serializer.Name;

            var sw = Stopwatch.StartNew();
            try
            {
                if (streaming)
                {
                    serializer.Serialize(original.Data, serializedStream);
                    measurement.Size = (int) serializedStream.Length;
                }
                else
                {
                    serializedString = serializer.Serialize(original.Data);
                    measurement.Size = serializedString.Length;
                }
                measurement.TimeSer = sw.ElapsedTicks;
                log.Size = measurement.Size;
                log.TimeSer = measurement.TimeSer;

                processed = streaming
                    ? serializer.Deserialize(serializedStream)
                    : serializer.Deserialize(serializedString);
                measurement.TimeDeser = sw.ElapsedTicks - measurement.TimeSer;
                log.TimeDeser = measurement.TimeDeser;
            }
            catch (Exception ex)
            {
                aborts.Add(Environment.NewLine + serializer.Name + ":\n\t" + ex.Message);
                return measurement;
            }
            sw.Stop();

            Report.TimeAndDocument(serializer.Name, measurement.Time, serializedString);
            logStorage.Store(log);

            string error;
            if (!Comparer.Compare(original.Data, processed, out error, true))
                errors.Add(error);
            Report.Errors(errors);

            return measurement;
        }

        //private static Measurement SingleTestOnStream(ISerDeser serializer, ITestDataDescription original,
        //    List<string> aborts, Log log)
        //{
        //    var measurement = new Measurement();
        //    var errors = new List<string> {serializer.Name};
        //    Stream serializedStream = new MemoryStream();
        //    object processed = null;

        //    var sw = Stopwatch.StartNew();
        //    try
        //    {
        //        serializer.Serialize(original.Data, serializedStream);
        //        measurement.Size = (int) serializedStream.Length;
        //        measurement.TimeSer = sw.ElapsedTicks;
        //        log.Size = measurement.Size;
        //        log.TimeSer = measurement.TimeSer;

        //        serializedStream.Position = 0;
        //        processed = serializer.Deserialize(serializedStream);
        //        measurement.Time = sw.ElapsedTicks;
        //        measurement.TimeDeser = measurement.Time - measurement.TimeSer;
        //    }
        //    catch (Exception ex)
        //    {
        //        aborts.Add(Environment.NewLine + serializer.Name + ":\n\t" + ex.Message);
        //        return measurement;
        //    }
        //    sw.Stop();

        //    //Report.TimeAndDocument(serializer.Name, measurement.Time, serializedStream);
        //    string error;
        //    if (!Comparer.Compare(original.Data, processed, out error, true))
        //        errors.Add(error);
        //    Report.Errors(errors);

        //    return measurement;
        //}
    }
}