using System;
using System.Collections.Generic;
using System.IO;
using ServiceStack;

namespace GLD.SerializerBenchmark
{
    public class Log
    {
        /// <summary>
        ///     Using stream or sting as the serialized output and input.
        /// </summary>
        public string StringOrStream { get; set; }

        public string TestDataName { get; set; }

        /// <summary>
        ///     Each run started with fresh object initializing.
        /// </summary>
        public int Run { get; set; }

        /// <summary>
        ///     A number of repetitions in a single Run
        /// </summary>
        public int Repetitions { get; set; }

        /// <summary>
        ///     A sequence number of a repetition in a single Run.
        /// </summary>
        public int RepetitionIndex { get; set; }

        public string SerializerName { get; set; }

        /// <summary>
        ///     Time of serialization in nanoseconds.
        /// </summary>
        public long TimeSer { get; set; }

        /// <summary>
        ///     Time of deserialization in nanoseconds.
        /// </summary>
        public long TimeDeser { get; set; }

        /// <summary>
        ///     Seze of the serialized object in bytes.
        /// </summary>
        public int Size { get; set; }

        /// <summary>
        ///     Sum of TimeSer and TimeDeser.
        /// </summary>
        public long TimeSerAndDeser
        {
            get { return TimeSer + TimeDeser; }
        }

        /// <summary>
        ///     Serialization operations per second (from nanosecond duration).
        /// </summary>
        public double OpPerSecSer
        {
            get { return TimeSer > 0 ? 1_000_000_000.0 / TimeSer : 0; }
        }

        /// <summary>
        ///     Deserialization operations per second (from nanosecond duration).
        /// </summary>
        public double OpPerSecDeser
        {
            get { return TimeDeser > 0 ? 1_000_000_000.0 / TimeDeser : 0; }
        }

        /// <summary>
        ///     Combined serialize+deserialize operations per second (from nanosecond duration).
        /// </summary>
        public double OpPerSecSerAndDeser
        {
            get { return (TimeSer + TimeDeser) > 0 ? 1_000_000_000.0 / (TimeSer + TimeDeser) : 0; }
        }

        /// <summary>Harness language id for multi-language CSV schema.</summary>
        public string Language { get { return "csharp"; } }

        /// <summary>Peak memory if measured; 0 when not tracked.</summary>
        public long MemoryPeakBytes { get; set; }

        /// <summary>1.0 when round-trip fidelity passed (rows are only written on pass).</summary>
        public double FidelityScore { get; set; } = 1.0;

        /// <summary>Optional package/library version string.</summary>
        public string SerializerVersion { get; set; } = "";
    }

    public class LogStorage
    {
        private string _logFileName;
        private StreamWriter _logFileStreamWriter;
        private string _separator;

        public LogStorage(string logFileName)
        {
            InitializeStorage(logFileName);
        }

        ~LogStorage()
        {
            CloseStorage();
        }

        /// <summary>
        ///     By default it opens a file for writing. If this file is also existed, save it under "name.
        ///     creationDateTime.extension, and create a new file.
        /// </summary>
        /// <param name="logFileName">Is a file name.</param>
        private void InitializeStorage(string logFileName, string separator = ",")
        {
            if (File.Exists(logFileName))
                File.Move(logFileName, GetArchiveFileName(logFileName));

            _logFileStreamWriter = File.CreateText(logFileName);
            _logFileStreamWriter.AutoFlush = true;
            _separator = separator;
            var fileHeaderLine =
                "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName," +
                "TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser," +
                "MemoryPeakBytes,FidelityScore,SerializerVersion";
            fileHeaderLine = fileHeaderLine.Replace(",", _separator);
            _logFileStreamWriter.WriteLine(fileHeaderLine);

            _logFileName = logFileName;
        }

        public void Write(Log log)
        {
            var line = string.Join(_separator,
                log.Language, log.StringOrStream, log.TestDataName, log.Repetitions, log.RepetitionIndex,
                log.SerializerName, log.TimeSer, log.TimeDeser, log.Size, log.TimeSerAndDeser,
                log.OpPerSecSer, log.OpPerSecDeser, log.OpPerSecSerAndDeser,
                log.MemoryPeakBytes, log.FidelityScore.ToString("F2"),
                log.SerializerVersion ?? ""
                );
            _logFileStreamWriter.WriteLine(line);
        }

        public List<Log> ReadAll()
        {
            var lines = File.ReadAllLines(_logFileName);
            var logs = new List<Log>();
            for (var index = 1; index < lines.Length; index++) // first line is a title. Ignore it!
            {
                var line = lines[index];
                var fields = line.Split(new[] {_separator}, StringSplitOptions.None);
                // Schema: Language,StringOrStream,TestDataName,... (Language ignored on read)
                var log = new Log
                {
                    StringOrStream = fields[1],
                    TestDataName = fields[2],
                    Repetitions = fields[3].ToInt(),
                    RepetitionIndex = fields[4].ToInt(),
                    SerializerName = fields[5],
                    TimeSer = fields[6].ToInt64(),
                    TimeDeser = fields[7].ToInt64(),
                    Size = fields[8].ToInt()
                    //TimeSerAndDeser = fields[9]... // properties: without setters
                    //OpPerSecSer = fields[10]...
                    //OpPerSecDeser = fields[10].ToDouble(),
                    //OpPerSecSerAndDeser = fields[11].ToDouble(),
                };
                logs.Add(log);
            }
            return logs;
        }

        public void CloseStorage()
        {
            _logFileStreamWriter.Close();
        }

        private static string GetArchiveFileName(string fileFullName)
        {
            if (!File.Exists(fileFullName)) return fileFullName + ".Archived.csv";
            var fileName = Path.GetFileNameWithoutExtension(fileFullName);
            var fileExtension = Path.GetExtension(fileFullName);
            var fileCreationDate = File.GetLastWriteTime(fileFullName);
            var fileCreationDateTimeString = string.Format(".{0}-{1}-{2}_{3}{4}{5}.", fileCreationDate.Year,
                fileCreationDate.Month, fileCreationDate.Day,
                fileCreationDate.Hour, fileCreationDate.Minute, fileCreationDate.Second);
            return fileName + fileCreationDateTimeString + fileExtension;
        }
    }
}