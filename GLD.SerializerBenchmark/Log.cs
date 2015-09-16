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
        ///     Time of serialization in ticks.
        /// </summary>
        public long TimeSer { get; set; }

        /// <summary>
        ///     Time of deserialization in ticks.
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
        ///     Serialization Operations per second. One tick = 0.1 mcsec
        /// </summary>
        public double OpPerSecSer
        {
            get { return TimeSer > 0 ? 10000000/TimeSer : 0; }
        }

        /// <summary>
        ///     Deerialization Operations per second. One tick = 0.1 mcsec
        /// </summary>
        public double OpPerSecDeser
        {
            get { return TimeDeser > 0 ? 10000000/TimeDeser : 0; }
        }

        /// <summary>
        ///     Sum of Serialization and Deserialization Operations per second. One tick = 0.1 mcsec
        /// </summary>
        public double OpPerSecSerAndDeser
        {
            get { return (TimeSer + TimeDeser) > 0 ? 10000000/(TimeSer + TimeDeser) : 0; }
        }
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
        ///     <creationDateTime>.extension, and create a new file.
        /// </summary>
        /// <param name="logFileName">Is a file name.</param>
        private void InitializeStorage(string logFileName, string separator = "~")
        {
            if (File.Exists(logFileName))
                File.Move(logFileName, GetArchiveFileName(logFileName));

            _logFileStreamWriter = File.CreateText(logFileName);
            _separator = separator;
            var fileHeaderLine =
                "StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser";
            fileHeaderLine = fileHeaderLine.Replace(",", _separator);
            _logFileStreamWriter.WriteLine(fileHeaderLine);

            _logFileName = logFileName;
        }

        public void Write(Log log)
        {
            var line = string.Join(_separator,
                log.StringOrStream, log.TestDataName, log.Repetitions, log.RepetitionIndex, log.SerializerName,
                log.TimeSer, log.TimeDeser, log.Size, log.TimeSerAndDeser, log.OpPerSecSer,
                log.OpPerSecDeser, log.OpPerSecSerAndDeser
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
                var fields = line.Split(new[] {"~"}, StringSplitOptions.None);
                var log = new Log
                {
                    StringOrStream = fields[0],
                    TestDataName = fields[1],
                    Repetitions = fields[2].ToInt(),
                    RepetitionIndex = fields[3].ToInt(),
                    SerializerName = fields[4],
                    TimeSer = fields[5].ToInt64(),
                    TimeDeser = fields[6].ToInt64(),
                    Size = fields[7].ToInt()
                    //TimeSerAndDeser = fields[8].ToInt64(), // properties: without setters
                    //OpPerSecSer = fields[9].ToDouble(),
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
            if (!File.Exists(fileFullName)) return fileFullName + ".Archived.txt";
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