using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace GLD.SerializerBenchmark
{
    public class Comparer
    {
        public static bool Compare(object source, object target, out string errorText, Log log, bool trace = false)
        {
            var sourceElements = (Travers(source));
            var targetElements = (Travers(target));
            var isComparisonFailed = ElementCount(sourceElements) != ElementCount(targetElements);
            errorText = (isComparisonFailed)
                ? string.Format("Comparison Error: Element numbers of source and target test objects are not equal: [{0}] != [{1}]",
                    ElementCount(sourceElements), ElementCount(targetElements))
                : null;
            var isSizeInvalid = false;
            if (!isComparisonFailed)
            {
                isSizeInvalid = ValidateSize(log, out errorText);
            }

            return (!isComparisonFailed && !isSizeInvalid);
        }

        private static bool ValidateSize(Log log, out string errorText)
        {
            if (log.Size == 0)
            {
                errorText = string.Format("Validation Error: Seems serialization failed. Serialized object size = {0}.",
                    log.Size);
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

        private static string Travers(object o, string name = "", int depth = 15)
        {
            var visited = new HashSet<object>(new ReferenceEqualityComparer());
            return TraversInternal(o, name, depth, visited);
        }

        private static string TraversInternal(object o, string name, int depth, HashSet<object> visited)
        {
            try
            {
                var leafprefix = (string.IsNullOrWhiteSpace(name) ? name : name + " = ");

                if (null == o) return leafprefix + "null";

                var t = o.GetType();
                if (t == typeof(string) || t.IsValueType)
                    return leafprefix + o;

                if (visited.Contains(o) || depth-- < 1)
                    return leafprefix + "ref to " + t.Name;

                visited.Add(o);

                var sb = new StringBuilder();
                var enumerable = o as IEnumerable;
                if (enumerable != null)
                {
                    name = (name ?? "").TrimEnd('[', ']') + '[';
                    var elements = enumerable.Cast<object>().Select(e => TraversInternal(e, "", depth, visited)).ToList();
                    var arrayInOneLine = elements.Count + "] = {" + Environment.NewLine +
                                         string.Join("," + Environment.NewLine, elements) + '}';
                    if (!arrayInOneLine.Contains(Environment.NewLine))
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
                    sb.AppendLine(TraversInternal(f.GetValue(o), name + '.' + f.Name, depth, visited));
                foreach (var p in t.GetProperties())
                {
                    // Skip indexers
                    if (p.GetIndexParameters().Length > 0) continue;
                    sb.AppendLine(TraversInternal(p.GetValue(o, null), name + '.' + p.Name, depth, visited));
                }
                if (sb.Length == 0) return leafprefix + o;
                return sb.ToString().TrimEnd();
            }
            catch
            {
                return name + "???";
            }
        }

        private class ReferenceEqualityComparer : IEqualityComparer<object>
        {
            public new bool Equals(object x, object y) => ReferenceEquals(x, y);
            public int GetHashCode(object obj) => System.Runtime.CompilerServices.RuntimeHelpers.GetHashCode(obj);
        }
    }
}