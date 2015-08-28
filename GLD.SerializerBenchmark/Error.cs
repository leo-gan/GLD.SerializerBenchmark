using System.Collections.Generic;
using System.Linq;

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
        /// It adds a current error to the error list. If this error is also existed in this list, do not add error.
        /// It returns true if error is added, false otherwise.
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
            return !isExisted;
       }

       
    }
}