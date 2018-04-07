using System.Collections.Generic;
using System.Linq;
using System.IO;


namespace GLD.SerializerBenchmark
{
    /// <summary>
    ///     It used for several cases:
    ///     - when exception is thrown by ser or deser operation
    ///     - when original object was serialized -> deserialized in target object and original object is not equal target
    ///     object.
    /// </summary>
    public class Error
    {
        public string StringOrStream { get; set; }

        public string TestDataName { get; set; }
        public string SerializerName { get; set; }

        /// <summary>
        ///     Each run started with fresh object initializing.
        /// </summary>
        public int Run { get; set; }

        /// <summary>
        ///     A current sequence number of a repetition in a single Run.
        /// </summary>
        public int Repetition { get; set; }

        public string ErrorText { get; set; }

        /// <summary>
        ///     It adds a current error to the error list. If this error is also existed in this list, do not add error.
        ///     It returns true if error is added, false otherwise.
        /// </summary>
        /// <param name="errors">A list of existed errors.</param>
        /// <returns>true if error is added</returns>
        public bool TryAddTo(List<Error> errors)
        {
            var isExisted = errors.Any(error =>
                StringOrStream == error.StringOrStream
                && TestDataName == error.TestDataName
                && SerializerName == error.SerializerName
                && ErrorText == error.ErrorText);
            if (!isExisted) errors.Add(this);
            return isExisted;
        }

        public static string TryGetErrorText(List<Error> errors, string testDataName, string serializerName,
            string stringOrStream)
        {
            var error =
                errors.FirstOrDefault(
                    er =>
                        er.TestDataName == testDataName && er.SerializerName == serializerName &&
                        er.StringOrStream == stringOrStream);
            return error != null ? error.ErrorText : null;
        }

        public static void SaveErrors(List<Error> errors, string fileName)
        {
            if (File.Exists(fileName))
                File.Move(fileName, Error.GetArchiveFileName(fileName));

            var fileStreamWriter = File.CreateText(fileName);
            var header = string.Join("\t", new[] {"SerializerName","StringOrStream","ErrorText" });
            fileStreamWriter.WriteLine(header);
            foreach (var er in errors)
                fileStreamWriter.WriteLine(string.Join("\t", new[] { er.SerializerName, er.StringOrStream, er.ErrorText }));
            fileStreamWriter.Close();
        }

        private static string GetArchiveFileName(string fileFullName)
        {
            if (!File.Exists(fileFullName)) return fileFullName + ".Archived.tsv";
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