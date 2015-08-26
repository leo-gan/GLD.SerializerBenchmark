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
        /// It compares two objects only by number of objct elements. It is enough to catch errors in serialization+deserialization chain.
        /// It works with objects of different type.
        /// </summary>
        /// <param name="source"></param>
        /// <param name="target"></param>
        /// <param name="error"></param>
        /// <param name="trace">If true, it output both object element names into Trace.</param>
        /// <returns></returns>
        public static bool Compare(object source, object target, out string error, bool trace = false)
        {
            var sourceElements = (Travers(source));
            var targetElements = (Travers(target));
            if (trace)
            {
                Trace.WriteLine("\nSource object ===========================================================");
                Trace.Write(sourceElements);
                Trace.WriteLine("\nTarget object ===========================================================");
                Trace.Write(targetElements);
            }
            var sourceElementCount = ElementCount(sourceElements);
            var targetElementCount = ElementCount(targetElements);
            error = (sourceElementCount != targetElementCount)
                ? string.Format("Element numbers of source and target documents are not equal: [{0}] != [{1}] ",
                    sourceElementCount, targetElementCount)
                : null;
            return sourceElementCount == targetElementCount;
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