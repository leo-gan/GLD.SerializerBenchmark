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

        public long Time
        {
            get { return (TimeDeser + TimeSer) > 0 ? TimeDeser + TimeSer : 0; }
        }
    }

    internal class Tester
    {
        public static void Tests(List<ISerDeser> serializers, List<ITestDataDescription> testDataDescriptions,
            int repetitions)
        {
            var logStorage = new LogStorage("SerializerBenchmark_Log.csv");
            var errors = new List<Error>();

            // initialize all serializers 
            foreach (var testDataDescription in testDataDescriptions)
                TestOnData(testDataDescription, repetitions, serializers, logStorage, errors);

            Report.AllResults(repetitions, logStorage, errors);
        }

        private static void TestOnData(ITestDataDescription testDataDescription, int repetitions,
            List<ISerDeser> serializers, LogStorage logStorage, List<Error> errors)
        {
            // initialize serializers for every data type.
            foreach (var serializer in serializers)
                serializer.Initialize(testDataDescription.DataType, testDataDescription.SecondaryDataTypes);
            TestsOnRepetition(testDataDescription, false, repetitions, serializers, logStorage, errors);
            TestsOnRepetition(testDataDescription, true, repetitions, serializers, logStorage, errors);
        }

        public static void TestsOnRepetition(ITestDataDescription testDataDescription, bool streaming, int repetitions,
            List<ISerDeser> serializers, LogStorage logStorage, List<Error> errors)
        {
            var measurements = new Dictionary<string, Measurement[]>();
            var wasError = new Dictionary<string, bool>();
            foreach (var serializer in serializers)
            {
                measurements[serializer.Name] = new Measurement[repetitions];
                wasError[serializer.Name] = false;
            }
            var original = testDataDescription; // the same data for all serializers
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
                TestOnSerializer(serializers, original, i, measurements, errors, streaming, logStorage, log);
            }
        }

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestDataDescription original, int repetition,
            Dictionary<string, Measurement[]> measurements, List<Error> errors, bool streaming, LogStorage logStorage,
            Log log)
        {
            foreach (var serializer in serializers)
            {
                var isRepeatedError = false;
                measurements[serializer.Name][repetition] = SingleTest(serializer, original, errors, streaming, log,
                    logStorage, out isRepeatedError);
                if (isRepeatedError) break;
            }

            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static Measurement SingleTest(ISerDeser serializer, ITestDataDescription original, List<Error> errors,
            bool streaming, Log log, LogStorage logStorage, out bool isRepeatedError)
        {
            isRepeatedError = false;
            var measurement = new Measurement();
            string serializedString = null;
            Stream serializedStream = new MemoryStream();
            object processed;
            log.SerializerName = serializer.Name;

            var sw = Stopwatch.StartNew();
            var serSuccessful = false;
            var error = new Error
            {
                StringOrStream = log.StringOrStream,
                TestDataName = log.TestDataName,
                SerializerName = log.SerializerName,
                Run = log.Run,
                Repetition = log.RepetitionIndex
            };
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
                serSuccessful = true;
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
                error.ErrorText = (serSuccessful ? "Deserialization" : "Serialization") + " Exception: " + ex.Message;
                isRepeatedError = !error.TryAddTo(errors);
                return measurement;
            }
            sw.Stop();

            string errorText;
            // write log if comparison is true
            if (Comparer.Compare(original.Data, processed, out errorText, log, false))
                logStorage.Write(log);
            else // write error, if comparison false
            {
                error.ErrorText = errorText;
                isRepeatedError = !error.TryAddTo(errors); // if it false adding, that means an error repeated.
            }

            return measurement;
        }
    }
}