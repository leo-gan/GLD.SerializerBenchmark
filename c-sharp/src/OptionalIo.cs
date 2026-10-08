using System;
using System.Collections.Generic;
using System.IO;

namespace GLD.SerializerBenchmark
{
    /// <summary>Stream rows are timed only for names in config/optional-io.txt.</summary>
    static class OptionalIo
    {
        static HashSet<string> _names;

        public static bool IsStreamOptIn(string serializerName)
        {
            if (_names == null) _names = Load();
            return serializerName != null && _names.Contains(serializerName);
        }

        static HashSet<string> Load()
        {
            var set = new HashSet<string>(StringComparer.Ordinal);
            var path = FindFile();
            if (path == null) return set;
            foreach (var raw in File.ReadAllLines(path))
            {
                var tab = raw.IndexOf('\t');
                if (tab <= 0) continue;
                if (raw.Substring(0, tab) != "csharp") continue;
                var name = raw.Substring(tab + 1).Trim();
                if (name.Length > 0) set.Add(name);
            }
            return set;
        }

        static string FindFile()
        {
            var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
            while (dir != null)
            {
                var candidate = Path.Combine(dir.FullName, "config", "optional-io.txt");
                if (File.Exists(candidate)) return candidate;
                dir = dir.Parent;
            }
            return null;
        }
    }
}
