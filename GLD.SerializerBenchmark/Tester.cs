using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace GLD.SerializerBenchmark
{
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
            var wasError = new Dictionary<string, bool>();
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
                TestOnSerializer(serializers, original, errors, streaming, logStorage, log, wasError);
            }
        }

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestDataDescription original, List<Error> errors, bool streaming, LogStorage logStorage, Log log, Dictionary<string, bool> wasError)
        {
            foreach (var serializer in serializers)
            {
                if (wasError.ContainsKey(serializer.Name)) continue; 
                var isRepeatedError = false;
                SingleTest(serializer, original, errors, streaming, log,
                    logStorage, out isRepeatedError);
                if (isRepeatedError) wasError[serializer.Name] = true;
            }

            GC.Collect(); // it has very little impact on speed for repetitions < 100
            GC.WaitForFullGCComplete();
            GC.Collect();
        }

        private static void SingleTest(ISerDeser serializer, ITestDataDescription original, List<Error> errors,
            bool streaming, Log log, LogStorage logStorage, out bool isRepeatedError)
        {
            isRepeatedError = false;
            //var measurement = new Measurement();
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
                    log.Size = (int) serializedStream.Length;
                }
                else
                {
                    serializedString = serializer.Serialize(original.Data);
                    log.Size = serializedString.Length;
                }
                serSuccessful = true;
                log.TimeSer = sw.ElapsedTicks;

                processed = streaming
                    ? serializer.Deserialize(serializedStream)
                    : serializer.Deserialize(serializedString);
                log.TimeDeser = sw.ElapsedTicks - log.TimeSer;
            }
            catch (Exception ex)
            {
                error.ErrorText = (serSuccessful ? "Deserialization" : "Serialization") + " Exception: " + ex.Message;
                isRepeatedError = !error.TryAddTo(errors);
                return;
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
        }
    }
}