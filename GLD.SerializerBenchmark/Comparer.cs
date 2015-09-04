using System;
using System.Collections;
using System.Diagnostics;
using System.Linq;
using System.Text;

namespace GLD.SerializerBenchmark
{
    public class Comparer
    {
        /// <summary>
        ///  It compares two objects only by number of object elements. It is enough to catch errors in serialization+deserialization chain.
        /// It works with objects of different type.
        /// </summary>
        /// <param name="source"></param>
        /// <param name="target"></param>
        /// <param name="errorText">returns text of an error, otherwise returns null</param>
        /// <param name="log"></param>
        /// <param name="trace">If true, it output both object element names into Trace.</param>
        /// <returns>Returns true if number of element in source and target objects are equal, false otherwise.</returns>
        public static bool Compare(object source, object target, out string errorText, Log log, bool trace = false)
        {
            var sourceElements = (Travers(source));
            var targetElements = (Travers(target));
            var isComparisonFailed = ElementCount(sourceElements) != ElementCount(targetElements);
            errorText = (isComparisonFailed)
                ? 
                string.Format("Element numbers of source and target test objects are not equal: [{0}] != [{1}]",
                ElementCount(sourceElements), ElementCount(targetElements))
                : null;
            var isSizeInvalid = false;
            if (!isComparisonFailed) // validate size only if element count was successful:
            {
                isSizeInvalid = ValidateSize(log, out errorText);
            }

            if (trace && log.RepetitionIndex == 0 || isComparisonFailed || isSizeInvalid) // trace only for the first test repetion or for the errorText
            {
                //Trace.WriteLine(string.Format("\nTestData:{0}, Serializer: {1}, {2}, Repetition: {3}", log.TestDataName, log.SerializerName, log.StringOrStream, log.RepetitionIndex));
                //if (isComparisonFailed)
                //    Trace.WriteLine(new string('*', 80) + Environment.NewLine + errorText);
                //Trace.WriteLine("\nSource object ===========================================================");
                //Trace.Write(sourceElements);
                //Trace.WriteLine("\nTarget object ===========================================================");
                //Trace.Write(targetElements);
            }

            return (!isComparisonFailed && !isSizeInvalid);
        }

        private static bool ValidateSize(Log log, out string errorText)
        {
            if (log.Size < 5)
            {
                errorText = String.Format("Seems serialization failed. Serialized object size = {0} is too small.", log.Size);
                return true;
            }
            errorText = null;
            return false;
        }

        private static int ElementCount(string traversedObjectElementList)
        {
            return
                traversedObjectElementList.Split(new[] {Environment.NewLine}, StringSplitOptions.RemoveEmptyEntries)
                    .Length;
        }

        /// <summary>
        /// It compound names of members of object, including properties, arrays. It travers down the object tree and 
        /// gathers names of all properties, fields with some exclusions.
        /// </summary>
        /// <param name="o"></param>
        /// <param name="name"></param>
        /// <param name="depth"></param>
        /// <returns></returns>
        private static string Travers(object o, string name = "", int depth = 15)
        {
            try
            {
                var leafprefix = (string.IsNullOrWhiteSpace(name) ? name : name + " = ");

                if (null == o) return leafprefix + "null";

                var t = o.GetType();
                if (depth-- < 1 || t == typeof (string) || t.IsValueType)
                    return leafprefix + o;

                var sb = new StringBuilder();
                var enumerable = o as IEnumerable;
                if (enumerable != null)
                {
                    name = (name ?? "").TrimEnd('[', ']') + '[';
                    var elements = enumerable.Cast<object>().Select(e => Travers(e, "", depth)).ToList();
                    var arrayInOneLine = elements.Count + "] = {" + Environment.NewLine +
                                         string.Join("," + Environment.NewLine, elements) + '}';
                    if (!arrayInOneLine.Contains(Environment.NewLine)) // Single line?
                        return name + arrayInOneLine;
                    var i = 0;
                    foreach (var element in elements)
                    {
                        var lineheader = name + i++ + ']';
                        sb.Append(lineheader)
                            .AppendLine(element.Replace(Environment.NewLine, Environment.NewLine + lineheader));
                    }
                    return sb.ToString();
                }
                foreach (var f in t.GetFields())
                    sb.AppendLine(Travers(f.GetValue(o), name + '.' + f.Name, depth));
                foreach (var p in t.GetProperties())
                    sb.AppendLine(Travers(p.GetValue(o, null), name + '.' + p.Name, depth));
                if (sb.Length == 0) return leafprefix + o;
                return sb.ToString().TrimEnd();
            }
            catch
            {
                return name + "???";
            }
        }
    }
}