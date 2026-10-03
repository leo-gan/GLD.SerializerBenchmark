using System;
using System.Collections;
using System.Collections.Generic;
using System.Reflection;

namespace GLD.SerializerBenchmark.Serializers
{
    /// <summary>
    /// Pull FFloat0 from a full row or a batch. Peers full-decode, then slice here.
    /// Arrow and Parquet projection does not use this path.
    /// </summary>
    internal static class ColumnarProject
    {
        public static List<double> FFloat0(object decoded)
        {
            if (decoded == null)
                throw new InvalidOperationException("table_project decoded null");

            var itemsProp = decoded.GetType().GetProperty("Items", BindingFlags.Public | BindingFlags.Instance);
            if (itemsProp != null && itemsProp.GetIndexParameters().Length == 0)
            {
                var pt = itemsProp.PropertyType;
                if (pt != typeof(string) && typeof(IEnumerable).IsAssignableFrom(pt))
                {
                    if (itemsProp.GetValue(decoded) is IEnumerable seq)
                    {
                        var list = new List<double>();
                        var ok = true;
                        foreach (var item in seq)
                        {
                            if (item == null)
                            {
                                ok = false;
                                break;
                            }
                            var p = item.GetType().GetProperty("FFloat0", BindingFlags.Public | BindingFlags.Instance);
                            if (p == null)
                            {
                                ok = false;
                                break;
                            }
                            list.Add(Convert.ToDouble(p.GetValue(item)));
                        }
                        if (ok) return list;
                    }
                }
            }

            var self = decoded.GetType().GetProperty("FFloat0", BindingFlags.Public | BindingFlags.Instance);
            if (self == null)
                throw new InvalidOperationException("table_project value has no FFloat0: " + decoded.GetType().FullName);
            return new List<double> { Convert.ToDouble(self.GetValue(decoded)) };
        }
    }
}
