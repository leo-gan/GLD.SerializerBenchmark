using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace GLD.SerializerBenchmark
{
    public class Comparer
    {
        /// <summary>
        /// Deep structural fidelity: compare full property/field traversal of source vs target
        /// (values and counts). Previous implementation only compared element *counts*, so
        /// empty/default round-trips falsely passed when the tree shape matched.
        /// </summary>
        public static bool Compare(object source, object target, out string errorText, Log log, bool trace = false)
        {
            var sourceElements = Travers(source);
            var targetElements = Travers(target);

            if (ElementCount(sourceElements) != ElementCount(targetElements))
            {
                errorText = string.Format(
                    "Comparison Error: Element numbers of source and target test objects are not equal: [{0}] != [{1}]",
                    ElementCount(sourceElements), ElementCount(targetElements));
                if (log != null) log.FidelityScore = 0.0;
                return false;
            }

            // Value-level check (order-stable Travers). Floats/doubles compared with relative
            // epsilon so JSON codecs (NetJSON, fastJson) are not failed for binary64 rounding.
            if (!LinesEqualLoose(sourceElements, targetElements, out var mismatch))
            {
                errorText = "Comparison Error: " + mismatch;
                if (log != null) log.FidelityScore = 0.0;
                return false;
            }

            if (ValidateSize(log, out errorText))
            {
                if (log != null) log.FidelityScore = 0.0;
                return false;
            }

            if (log != null) log.FidelityScore = 1.0;
            errorText = null;
            return true;
        }

        private static bool ValidateSize(Log log, out string errorText)
        {
            if (log != null && log.Size == 0)
            {
                errorText = string.Format(
                    "Validation Error: Seems serialization failed. Serialized object size = {0}.",
                    log.Size);
                return true; // invalid
            }
            errorText = null;
            return false;
        }

        /// <summary>
        /// Compare Travers dumps line-by-line; numeric leaves use relative tolerance.
        /// </summary>
        private static bool LinesEqualLoose(string source, string target, out string mismatch)
        {
            var sLines = (source ?? "").Split(new[] { Environment.NewLine }, StringSplitOptions.None);
            var tLines = (target ?? "").Split(new[] { Environment.NewLine }, StringSplitOptions.None);
            if (sLines.Length != tLines.Length)
            {
                mismatch = string.Format("line count {0} != {1}", sLines.Length, tLines.Length);
                return false;
            }
            for (var i = 0; i < sLines.Length; i++)
            {
                if (string.Equals(sLines[i], tLines[i], StringComparison.Ordinal))
                    continue;
                if (NumericLeavesClose(sLines[i], tLines[i]))
                    continue;
                var left = sLines[i];
                var right = tLines[i];
                if (left.Length > 120) left = left.Substring(0, 120) + "…";
                if (right.Length > 120) right = right.Substring(0, 120) + "…";
                mismatch = string.Format("value mismatch at line {0}: [{1}] != [{2}]", i, left, right);
                return false;
            }
            mismatch = null;
            return true;
        }

        private static bool NumericLeavesClose(string a, string b)
        {
            // Expected shape: ".Path = value" or "value"
            var av = ExtractLeaf(a);
            var bv = ExtractLeaf(b);
            if (av == null || bv == null) return false;
            if (!double.TryParse(av, System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out var da))
                return false;
            if (!double.TryParse(bv, System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out var db))
                return false;
            if (double.IsNaN(da) && double.IsNaN(db)) return true;
            if (double.IsInfinity(da) || double.IsInfinity(db)) return da.Equals(db);
            var scale = Math.Max(1.0, Math.Max(Math.Abs(da), Math.Abs(db)));
            // ~1e-9 relative; JSON number round-trip is typically ~1e-15 abs but codecs vary
            return Math.Abs(da - db) <= 1e-9 * scale + 1e-12;
        }

        private static string ExtractLeaf(string line)
        {
            if (string.IsNullOrEmpty(line)) return null;
            var idx = line.LastIndexOf(" = ", StringComparison.Ordinal);
            if (idx >= 0) return line.Substring(idx + 3).Trim();
            // Array leaf form from Travers: ".Values[3]21.917…" (no " = ")
            var bracket = line.LastIndexOf(']');
            if (bracket >= 0 && bracket + 1 < line.Length)
            {
                var rest = line.Substring(bracket + 1).Trim();
                if (rest.Length > 0 && (char.IsDigit(rest[0]) || rest[0] == '-' || rest[0] == '+'))
                    return rest;
            }
            return line.Trim();
        }

        private static int ElementCount(string traversedObjectElementList)
        {
            if (string.IsNullOrEmpty(traversedObjectElementList)) return 0;
            return traversedObjectElementList
                .Split(new[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries)
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
                {
                    // Normalize floating formatting for stable compares
                    if (o is double d)
                        return leafprefix + d.ToString("R", System.Globalization.CultureInfo.InvariantCulture);
                    if (o is float f)
                        return leafprefix + f.ToString("R", System.Globalization.CultureInfo.InvariantCulture);
                    return leafprefix + Convert.ToString(o, System.Globalization.CultureInfo.InvariantCulture);
                }

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
                // Stable order: properties then fields by name (ignore compiler/backing noise)
                foreach (var p in t.GetProperties().OrderBy(p => p.Name, StringComparer.Ordinal))
                {
                    if (p.GetIndexParameters().Length > 0) continue;
                    if (!p.CanRead) continue;
                    sb.AppendLine(TraversInternal(p.GetValue(o, null), name + '.' + p.Name, depth, visited));
                }
                foreach (var f in t.GetFields().OrderBy(f => f.Name, StringComparer.Ordinal))
                {
                    // Skip backing fields for auto-props
                    if (f.Name.Contains("<") || f.Name.StartsWith("k__BackingField", StringComparison.Ordinal))
                        continue;
                    sb.AppendLine(TraversInternal(f.GetValue(o), name + '.' + f.Name, depth, visited));
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
