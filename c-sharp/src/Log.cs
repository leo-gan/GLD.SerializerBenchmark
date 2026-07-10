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

        /// <summary>Batch cardinality for this cell (1 = single instance).</summary>
        public int DataTypeInstanceCount { get; set; } = 1;

        /// <summary>Hash of resolved type_config for this cell.</summary>
        public string TypeConfigHash { get; set; } = "";
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
            // SerializerVersion immediately follows SerializerName (installed package version).
            var fileHeaderLine =
                "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName," +
                "SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser," +
                "OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,DataTypeInstanceCount,TypeConfigHash";
            fileHeaderLine = fileHeaderLine.Replace(",", _separator);
            _logFileStreamWriter.WriteLine(fileHeaderLine);

            _logFileName = logFileName;
        }

        /// <summary>
        /// Append one raw measurement row. Includes warmup (<c>RepetitionIndex == 0</c>).
        /// Do not filter or post-process before calling — analysis owns warmup/outlier policy.
        /// </summary>
        public void Write(Log log)
        {
            var line = string.Join(_separator,
                log.Language, log.StringOrStream, log.TestDataName, log.Repetitions, log.RepetitionIndex,
                log.SerializerName, log.SerializerVersion ?? "",
                log.TimeSer, log.TimeDeser, log.Size, log.TimeSerAndDeser,
                log.OpPerSecSer, log.OpPerSecDeser, log.OpPerSecSerAndDeser,
                log.MemoryPeakBytes, log.FidelityScore.ToString("F2"),
                log.DataTypeInstanceCount > 0 ? log.DataTypeInstanceCount : 1,
                log.TypeConfigHash ?? ""
                );
            _logFileStreamWriter.WriteLine(line);
        }

        public List<Log> ReadAll()
        {
            var lines = File.ReadAllLines(_logFileName);
            var logs = new List<Log>();
            if (lines.Length == 0) return logs;

            // Support current schema (SerializerVersion after SerializerName) and legacy
            // (version at end / missing) by resolving indices from the header row.
            var header = lines[0].Split(new[] { _separator }, StringSplitOptions.None);
            int Idx(string name)
            {
                for (var i = 0; i < header.Length; i++)
                    if (string.Equals(header[i], name, StringComparison.OrdinalIgnoreCase))
                        return i;
                return -1;
            }

            var iStream = Idx("StringOrStream");
            var iData = Idx("TestDataName");
            var iReps = Idx("Repetitions");
            var iRepIdx = Idx("RepetitionIndex");
            var iName = Idx("SerializerName");
            var iVer = Idx("SerializerVersion");
            var iSer = Idx("TimeSer");
            var iDeser = Idx("TimeDeser");
            var iSize = Idx("Size");
            var iMem = Idx("MemoryPeakBytes");
            var iFid = Idx("FidelityScore");
            var iInst = Idx("DataTypeInstanceCount");
            var iHash = Idx("TypeConfigHash");

            // Legacy fixed layout fallback (pre-version-column reorder)
            if (iName < 0)
            {
                iStream = 1; iData = 2; iReps = 3; iRepIdx = 4; iName = 5;
                iSer = 6; iDeser = 7; iSize = 8;
            }

            long ParseLong(string[] fields, int i)
            {
                if (i < 0 || i >= fields.Length) return 0;
                long.TryParse(fields[i], System.Globalization.NumberStyles.Integer,
                    System.Globalization.CultureInfo.InvariantCulture, out var v);
                return v;
            }
            int ParseInt(string[] fields, int i)
            {
                if (i < 0 || i >= fields.Length) return 0;
                int.TryParse(fields[i], System.Globalization.NumberStyles.Integer,
                    System.Globalization.CultureInfo.InvariantCulture, out var v);
                return v;
            }
            string Field(string[] fields, int i) =>
                (i >= 0 && i < fields.Length) ? fields[i] : "";

            for (var index = 1; index < lines.Length; index++)
            {
                var fields = lines[index].Split(new[] { _separator }, StringSplitOptions.None);
                var log = new Log
                {
                    StringOrStream = Field(fields, iStream),
                    TestDataName = Field(fields, iData),
                    Repetitions = ParseInt(fields, iReps),
                    RepetitionIndex = ParseInt(fields, iRepIdx),
                    SerializerName = Field(fields, iName),
                    SerializerVersion = Field(fields, iVer),
                    TimeSer = ParseLong(fields, iSer),
                    TimeDeser = ParseLong(fields, iDeser),
                    Size = ParseInt(fields, iSize),
                    MemoryPeakBytes = ParseLong(fields, iMem),
                };
                if (iFid >= 0 && iFid < fields.Length &&
                    double.TryParse(fields[iFid], System.Globalization.NumberStyles.Float,
                        System.Globalization.CultureInfo.InvariantCulture, out var fid))
                    log.FidelityScore = fid;
                log.DataTypeInstanceCount = iInst >= 0 ? ParseInt(fields, iInst) : 1;
                if (log.DataTypeInstanceCount < 1) log.DataTypeInstanceCount = 1;
                log.TypeConfigHash = Field(fields, iHash);
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