namespace GLD.SerializerBenchmark
{
    /// <summary>B-6 StreamMode labels for C# codecs (see docs/c-sharp/index.md stream honesty).</summary>
    internal static class StreamModeHelper
    {
        /// <summary>
        /// Resolve honesty label. Adapted = full string/Base64 then dump to stream.
        /// text_on_stream = library text writer on stream. Else native binary stream API.
        /// </summary>
        public static string Resolve(string serializerName)
        {
            var n = serializerName ?? "";
            switch (n)
            {
                case "ExtendedXmlSerializer":
                case "CsvHelper":
                case "fastJson":
                case "NetJSON":
                case "Ceras":
                case "SharpSerializer":
                    return "adapted";
                case "Json.Net":
                case "Json.Net (Helper)":
                case "Jil":
                case "YamlDotNet":
                case "SharpYaml":
                case "System.Text.Json":
                case "ServiceStack Json":
                case "FsPicklerJson":
                case "MS Bond Json":
                case "MS DataContract Json":
                case "SpanJson":
                case "Utf8Json":
                case "YAXLib":
                case "MS XmlSerializer":
                case "MS DataContract":
                    return "text_on_stream";
                default:
                    return "native";
            }
        }
    }
}
