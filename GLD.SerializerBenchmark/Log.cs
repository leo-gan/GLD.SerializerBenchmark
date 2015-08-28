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
        /// It used for saving an error text, if this error happend.
        /// </summary>
        public string Note { get; set; }

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
            get { return TimeSer > 0 ? 10000000/TimeSer : 0;}
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
        private StreamWriter logFileStreamWriter;

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
        /// <param name="fileName">Is a file name.</param>
        private void InitializeStorage(string fileName)
        {
            if (File.Exists(fileName))
                File.Move(fileName, GetArchiveFileName(fileName));

            logFileStreamWriter = File.CreateText(fileName);

            const string fileHeaderLine = "StringOrStream, TestDataName, Repetitions, RepetitionIndex, SerializerName, TimeSer, TimeDeser, Size, TimeSerAndDeser, OpPerSecSer, OpPerSecDeser, OpPerSecSerAndDeser, Note";
            logFileStreamWriter.WriteLine(fileHeaderLine);
        }

        public void Write(Log log)
        {
            var line = string.Join("~", log.StringOrStream, log.TestDataName, log.Repetitions,log.RepetitionIndex, log.SerializerName,
                log.TimeSer, log.TimeDeser, log.Size, log.TimeSerAndDeser, log.OpPerSecSer,
                log.OpPerSecDeser,
                log.OpPerSecSerAndDeser, 
                log.Note
                );
            logFileStreamWriter.WriteLine(line);
        }

        public List<Log> ReadAll(string fileFullName )
        {
            var lines = File.ReadAllLines(fileFullName);
            var logs = new List<Log>();
            foreach (var line in lines)
            {
                var fields = line.Split(new[]{'~'}, StringSplitOptions.RemoveEmptyEntries);
                var log = new Log()
                {
                    StringOrStream = fields[0],
                    TestDataName = fields[1],
                    Repetitions = fields[2].ToInt(),
                    RepetitionIndex = fields[3].ToInt(),
                    SerializerName = fields[4],
                    TimeSer = fields[5].ToInt64(),
                    TimeDeser = fields[6].ToInt64(),
                    //TimeSerAndDeser = fields[7].ToInt64(), // properties: without setters
                    //OpPerSecSer = fields[8].ToDouble(),
                    //OpPerSecDeser = fields[9].ToDouble(),
                    //OpPerSecSerAndDeser = fields[10].ToDouble(),
                    Note = fields[11],
                };
                logs.Add(log);
            }
            return logs;
        }

        private void CloseStorage()
        {
            logFileStreamWriter.Close();
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