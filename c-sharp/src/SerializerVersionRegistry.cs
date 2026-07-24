using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

namespace GLD.SerializerBenchmark
{
    /// <summary>
    /// Resolve CSV SerializerVersion from the NuGet package assembly loaded at runtime.
    /// Uses a display-name → assembly-name map (avoids fragile type name collisions).
    /// </summary>
    internal static class SerializerVersionRegistry
    {
        // serializer Name → assembly simple name (as loaded)
        private static readonly Dictionary<string, string> AssemblyByName =
            new(StringComparer.Ordinal)
            {
                ["Json.Net"] = "Newtonsoft.Json",
                ["Json.Net (Helper)"] = "Newtonsoft.Json",
                ["ProtoBuf"] = "protobuf-net",
                ["LightProto"] = "LightProto",
                ["Jil"] = "Jil",
                ["ServiceStack Json"] = "ServiceStack.Text",
                ["ServiceStack"] = "ServiceStack.Text",
                ["MS Bond Compact"] = "Bond.Runtime.CSharp",
                ["MS Bond Fast"] = "Bond.Runtime.CSharp",
                ["MS Bond Json"] = "Bond.Runtime.CSharp",
                ["FsPickler"] = "FsPickler",
                ["FsPicklerJson"] = "FsPickler.Json",
                ["SharpSerializer"] = "SharpSerializer",
                ["fastJson"] = "fastJSON",
                ["NetJSON"] = "NetJSON",
                ["Apex.Serialization"] = "Apex.Serialization",
                ["Ceras"] = "Ceras",
                ["CsvHelper"] = "CsvHelper",
                ["ExtendedXmlSerializer"] = "ExtendedXmlSerializer",
                ["FlatSharp"] = "FlatSharp",
                ["FluentSerializer"] = "FluentSerializer.Json",
                ["Google.Protobuf"] = "Google.Protobuf",
                ["Apache.Avro"] = "Avro",
                ["GroBuf"] = "GroBuf",
                ["Hyperion"] = "Hyperion",
                ["NetSerializer"] = "NetSerializer",
                ["SharpYaml"] = "SharpYaml",
                ["SpanJson"] = "SpanJson",
                ["Utf8Json"] = "Utf8Json",
                ["YamlDotNet"] = "YamlDotNet",
                ["YAXLib"] = "YAXLib",
                ["ZeroFormatter"] = "ZeroFormatter",
                ["BinaryPack"] = "BinaryPack",
                ["MemoryPack"] = "MemoryPack",
                ["Migrant"] = "Migrant",
            };

        public static string Resolve(string serializerName)
        {
            if (string.IsNullOrEmpty(serializerName)) return "";

            if (AssemblyByName.TryGetValue(serializerName, out var asmName))
            {
                var ver = VersionFromAssemblyName(asmName);
                if (!string.IsNullOrEmpty(ver)) return ver;
            }

            if (serializerName.StartsWith("MS ", StringComparison.Ordinal))
                return PackageVersion.RuntimeFramework;

            return "";
        }

        private static string VersionFromAssemblyName(string simpleName)
        {
            // Prefer already-loaded assemblies (restore pulls them in before tests run).
            var loaded = AppDomain.CurrentDomain.GetAssemblies()
                .FirstOrDefault(a =>
                    string.Equals(a.GetName().Name, simpleName, StringComparison.OrdinalIgnoreCase));
            if (loaded != null)
                return PackageVersion.OfAssembly(loaded);

            try
            {
                var asm = Assembly.Load(new AssemblyName(simpleName));
                return PackageVersion.OfAssembly(asm);
            }
            catch
            {
                return "";
            }
        }
    }
}
