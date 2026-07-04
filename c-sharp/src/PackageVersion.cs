using System;
using System.Reflection;
using System.Runtime.InteropServices;

namespace GLD.SerializerBenchmark
{
    /// <summary>Resolve an assembly's published package version for CSV logging.</summary>
    internal static class PackageVersion
    {
        public static string RuntimeFramework =>
            RuntimeInformation.FrameworkDescription?.Trim() ?? Environment.Version.ToString();

        public static string Of(Type typeInPackage)
        {
            if (typeInPackage == null) return "";
            return OfAssembly(typeInPackage.Assembly);
        }

        public static string OfAssembly(Assembly asm)
        {
            if (asm == null) return "";
            var info = asm.GetCustomAttribute<AssemblyInformationalVersionAttribute>()
                ?.InformationalVersion;
            if (!string.IsNullOrWhiteSpace(info))
            {
                var plus = info.IndexOf('+');
                if (plus >= 0) info = info.Substring(0, plus);
                return info.Trim();
            }
            var file = asm.GetCustomAttribute<AssemblyFileVersionAttribute>()?.Version;
            if (!string.IsNullOrWhiteSpace(file)) return file.Trim();
            return asm.GetName().Version?.ToString() ?? "";
        }
    }
}
