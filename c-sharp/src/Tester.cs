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
            Directory.CreateDirectory("logs/csharp");
            var logStorage = new LogStorage("logs/csharp/benchmark-log.csv");
            var errors = new List<Error>();

            foreach (var testDataDescription in testDataDescriptions)
            {
                Console.WriteLine($"\n[PROGRESS] Testing Data: {testDataDescription.Name} (Targeting {serializers.Count} serializers, {repetitions} reps)");
                TestOnData(testDataDescription, repetitions, serializers, logStorage, errors);
                Error.SaveErrors(errors, "logs/csharp/benchmark-errors.csv");
            }

            Report.AllResults(repetitions, logStorage, errors, serializers, testDataDescriptions);
            Console.WriteLine("\n[PROGRESS] Benchmark Complete. Results saved to logs/csharp/benchmark-log.csv");
        }

        private static void TestOnData(ITestDataDescription testDataDescription, int repetitions,
            List<ISerDeser> serializers, LogStorage logStorage, List<Error> errors)
        {
            foreach (var serializer in serializers)
            {
                Console.WriteLine($"[DEBUG] Initializing {serializer.Name}");
                serializer.Initialize(testDataDescription.DataType, testDataDescription.SecondaryDataTypes);
            }

            TestsOnRepetition(testDataDescription, false, repetitions, serializers, logStorage, errors);
            TestsOnRepetition(testDataDescription, true, repetitions, serializers, logStorage, errors);
        }

        public static void TestsOnRepetition(ITestDataDescription testDataDescription, bool streaming, int repetitions,
            List<ISerDeser> serializers, LogStorage logStorage, List<Error> errors)
        {
            var wasError = new Dictionary<string, bool>();
            var original = testDataDescription;

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

        private static void TestOnSerializer(List<ISerDeser> serializers, ITestDataDescription original,
            List<Error> errors, bool streaming, LogStorage logStorage, Log log, Dictionary<string, bool> wasError)
        {
            foreach (var serializer in serializers)
            {
                if (wasError.ContainsKey(serializer.Name)) continue;
                
                if (!serializer.Supports(original.Name)) continue;

                Console.WriteLine($"[DEBUG] Starting {serializer.Name} ({(streaming ? "Stream" : "string")})");
                SingleTest(serializer, original, errors, streaming, log,
                    logStorage, out bool isRepeatedError);
                if (isRepeatedError) wasError[serializer.Name] = true;
            }
        }

        private static void SingleTest(ISerDeser serializer, ITestDataDescription original, List<Error> errors,
            bool streaming, Log log, LogStorage logStorage, out bool isRepeatedError)
        {
            isRepeatedError = false;
            string serializedString = null;
            Stream serializedStream = new MemoryStream();
            object processed;
            log.SerializerName = serializer.Name;

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
                var sw = Stopwatch.StartNew();
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
                sw.Stop();
            }
            catch (Exception ex)
            {
                error.ErrorText = (serSuccessful ? "Deserialization" : "Serialization") + " " + ex.GetType().Name + ": " + ex.Message;
                isRepeatedError = !error.TryAddTo(errors);
                return;
            }

            string errorText;
            if (Comparer.Compare(original.Data, processed, out errorText, log, false))
            {
                logStorage.Write(log);
            }
            else 
            {
                error.ErrorText = errorText;
                isRepeatedError = !error.TryAddTo(errors);
            }
        }
    }
}