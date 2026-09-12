using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using YamlDotNet.Serialization;
using Google.Protobuf;
using ProtoBuf;

namespace GLD.SerializerBenchmark
{
    /// <summary>C# compliance runner — same catalog as Python.</summary>
    internal static class Compliance
    {
        public static int Run(string[] args)
        {
            string jsonOut = null;
            var formats = new List<string>();
            for (var i = 0; i < args.Length; i++)
            {
                if ((args[i] == "--json-out" || args[i] == "-o") && i + 1 < args.Length)
                    jsonOut = args[++i];
                else if ((args[i] == "--format" || args[i] == "-f") && i + 1 < args.Length)
                    formats.Add(args[++i].ToLowerInvariant());
            }

            var root = RepoRoot();
            var suites = LoadSuites(Path.Combine(root, "compliance", "data"));
            if (formats.Count > 0)
                suites = suites.Where(s => formats.Contains(s.Format.ToLowerInvariant())).ToList();

            var adapters = Adapters();
            var byFmt = adapters.GroupBy(a => a.Format).ToDictionary(g => g.Key, g => g.ToList());
            var results = new List<Dictionary<string, object>>();
            var adapterErrs = new List<string>();
            foreach (var suite in suites)
            {
                if (!byFmt.TryGetValue(suite.Format, out var chosen) || chosen.Count == 0)
                {
                    adapterErrs.Add($"No adapter registered for format {suite.Format} ({suite.Standard} ({suite.Version}))");
                    continue;
                }
                foreach (var a in chosen)
                foreach (var c in suite.Cases)
                    results.Add(RunOne(suite, c, a));
            }
            PrintSummary(results, adapterErrs);
            if (!string.IsNullOrEmpty(jsonOut))
            {
                WriteReport(jsonOut, results, adapterErrs);
                Console.WriteLine("\nWrote " + jsonOut);
            }
            return 0;
        }

        private static string RepoRoot()
        {
            var dir = Directory.GetCurrentDirectory();
            for (var i = 0; i < 8; i++)
            {
                if (Directory.Exists(Path.Combine(dir, "compliance", "data")))
                    return dir;
                var parent = Directory.GetParent(dir);
                if (parent == null) break;
                dir = parent.FullName;
            }
            throw new DirectoryNotFoundException("cannot locate compliance/data");
        }

        private static List<Suite> LoadSuites(string root)
        {
            var suites = new List<Suite>();
            foreach (var file in Directory.GetFiles(root, "*.json", SearchOption.AllDirectories))
            {
                if (Path.GetFileName(file).StartsWith("_")) continue;
                var raw = File.ReadAllText(file);
                var suite = JsonConvert.DeserializeObject<Suite>(raw);
                if (suite?.Cases == null || suite.Cases.Count == 0 || string.IsNullOrEmpty(suite.Format))
                    continue;
                suites.Add(suite);
            }
            if (suites.Count == 0)
                throw new InvalidOperationException("no compliance suites under " + root);
            return suites;
        }

        private static List<Adapter> Adapters()
        {
            var yaml = new DeserializerBuilder().Build();
            return new List<Adapter>
            {
                new("System.Text.Json", "json", SerializerVersionRegistry.Resolve("System.Text.Json"), (b, _) => System.Text.Json.JsonSerializer.Deserialize<object>(b)),
                new("Json.Net", "json", SerializerVersionRegistry.Resolve("Json.Net"), (b, _) => JsonConvert.DeserializeObject(Encoding.UTF8.GetString(b))),
                new("YamlDotNet", "yaml", SerializerVersionRegistry.Resolve("YamlDotNet"), (b, _) => yaml.Deserialize<object>(Encoding.UTF8.GetString(b))),
                new("MessagePack-CSharp", "msgpack", SerializerVersionRegistry.Resolve("MessagePack-CSharp"), (b, _) => MessagePack.MessagePackSerializer.Deserialize<object>(b)),
                new("Google.Protobuf", "protobuf", SerializerVersionRegistry.Resolve("Google.Protobuf"), DecodeGoogleProtobuf),
                new("protobuf-net", "protobuf", SerializerVersionRegistry.Resolve("protobuf-net"), DecodeProtobufNet),
            };
        }

        private static Dictionary<string, object> RunOne(Suite suite, Case c, Adapter a)
        {
            var baseRow = new Dictionary<string, object>
            {
                ["id"] = c.Id,
                ["language"] = "csharp",
                ["serializer"] = a.Name,
                ["serializer_version"] = a.Version,
                ["format"] = suite.Format,
                ["standard"] = suite.Standard,
                ["standard_url"] = suite.StandardUrl ?? "",
                ["version"] = suite.Version,
                ["version_key"] = suite.Format + "." + suite.Version,
                ["requirement"] = c.Requirement,
                ["expect"] = c.Expect,
                ["section"] = c.Section,
                ["section_title"] = c.SectionTitle,
                ["section_url"] = c.SectionUrl,
                ["paragraph"] = c.Paragraph,
                ["title"] = c.Title,
                ["input"] = c.Input,
                ["input_encoding"] = string.IsNullOrEmpty(c.InputEncoding) ? "utf-8" : c.InputEncoding,
                ["detail"] = "",
                ["observed"] = "",
                ["outcome"] = "pass",
            };
            object got = null;
            var ok = true;
            var err = "";
            try
            {
                got = a.Decode(InputBytes(c), c.Schema != null && c.Schema.Type == JTokenType.String ? (string)c.Schema : "");
            }
            catch (Exception ex)
            {
                ok = false;
                err = ex.GetType().Name + ": " + ex.Message;
            }
            if (c.Expect == "any")
            {
                baseRow["observed"] = ok ? Preview(got) : err;
                return baseRow;
            }
            if (c.Expect == "reject")
            {
                if (!ok)
                {
                    baseRow["observed"] = err;
                    return baseRow;
                }
                baseRow["outcome"] = "fail";
                baseRow["detail"] = "parser accepted input the spec requires to be rejected";
                baseRow["observed"] = "accepted as " + Preview(got);
                return baseRow;
            }
            if (!ok)
            {
                baseRow["outcome"] = "fail";
                baseRow["detail"] = "parser rejected input the spec requires to accept";
                baseRow["observed"] = err;
                return baseRow;
            }
            if (c.Decoded != null && !ValuesEqual(c.Decoded, got))
            {
                baseRow["outcome"] = "fail";
                baseRow["detail"] = "decoded value does not match the catalog case";
                baseRow["observed"] = "got " + Preview(got) + ", want " + Preview(c.Decoded);
                return baseRow;
            }
            baseRow["observed"] = Preview(got);
            return baseRow;
        }

        private static byte[] InputBytes(Case c)
        {
            var enc = string.IsNullOrEmpty(c.InputEncoding) ? "utf-8" : c.InputEncoding;
            var input = c.Input ?? "";
            if (enc == "hex")
            {
                var compact = new string(input.Where(ch => !char.IsWhiteSpace(ch)).ToArray());
                return compact.Length == 0 ? Array.Empty<byte>() : Convert.FromHexString(compact);
            }
            return Encoding.UTF8.GetBytes(input);
        }

        private static bool ValuesEqual(object expected, object observed)
        {
            if (expected == null) return observed == null;
            if (expected is bool || observed is bool) return Equals(expected, observed);
            if (expected is long or int or double or float && observed is IConvertible)
                return Convert.ToDouble(expected) == Convert.ToDouble(observed);
            if (expected is string es) return es.Equals(observed as string);
            if (expected is JToken jt)
                return JToken.DeepEquals(jt, observed as JToken ?? JToken.FromObject(observed));
            return Equals(expected, observed);
        }

        private static string Preview(object v)
        {
            try
            {
                var s = JsonConvert.SerializeObject(v);
                return s.Length > 120 ? s.Substring(0, 117) + "..." : s;
            }
            catch
            {
                var s = Convert.ToString(v) ?? "";
                return s.Length > 120 ? s.Substring(0, 117) + "..." : s;
            }
        }

        private static void PrintSummary(List<Dictionary<string, object>> results, List<string> adapterErrs)
        {
            var p = 0; var f = 0; var s = 0; var e = 0;
            var by = new SortedDictionary<string, int[]>();
            foreach (var r in results)
            {
                var o = Convert.ToString(r["outcome"]);
                if (o == "pass") p++;
                else if (o == "fail") f++;
                else if (o == "skip") s++;
                else e++;
                var k = $"{r["standard"]} ({r["version"]}) × {r["serializer"]}";
                if (!by.TryGetValue(k, out var c)) { c = new int[3]; by[k] = c; }
                if (o == "pass") c[0]++;
                else if (o == "fail") c[1]++;
                else c[2]++;
            }
            Console.WriteLine("Serialization compliance (library deviations are catalogued, not a red build)");
            Console.WriteLine($"  {p} pass  {f} fail  {s} skip  {e} error  {results.Count} total");
            if (adapterErrs.Count > 0)
            {
                Console.WriteLine("  Adapter errors:");
                foreach (var a in adapterErrs) Console.WriteLine("    - " + a);
            }
            Console.WriteLine("  By suite × adapter:");
            foreach (var kv in by)
                Console.WriteLine($"    {kv.Key}: {kv.Value[0]} pass, {kv.Value[1]} fail, {kv.Value[2]} skip");
        }

        private static void WriteReport(string path, List<Dictionary<string, object>> results, List<string> adapterErrs)
        {
            var p = results.Count(r => (string)r["outcome"] == "pass");
            var f = results.Count(r => (string)r["outcome"] == "fail");
            var s = results.Count(r => (string)r["outcome"] == "skip");
            var e = results.Count - p - f - s;
            var fmts = results.Select(r => (string)r["format"]).Distinct().ToList();
            var doc = new Dictionary<string, object>
            {
                ["schema"] = "gld.dashboard.compliance/1",
                ["generated_at"] = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ"),
                ["language"] = "csharp",
                ["languages"] = new[] { "csharp" },
                ["policy"] = "report-only",
                ["scope"] = new Dictionary<string, object> { ["formats"] = fmts },
                ["passed"] = p,
                ["failed"] = f,
                ["skipped"] = s,
                ["errors"] = e,
                ["catalog_errors"] = Array.Empty<string>(),
                ["serializer_errors"] = adapterErrs,
                ["results"] = results,
            };
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            var settings = new JsonSerializerSettings
            {
                Formatting = Formatting.Indented,
                StringEscapeHandling = StringEscapeHandling.EscapeNonAscii,
            };
            File.WriteAllText(path, JsonConvert.SerializeObject(doc, settings) + "\n");
        }

        private sealed class Suite
        {
            [JsonProperty("format")] public string Format { get; set; }
            [JsonProperty("standard")] public string Standard { get; set; }
            [JsonProperty("version")] public string Version { get; set; }
            [JsonProperty("standard_url")] public string StandardUrl { get; set; }
            [JsonProperty("cases")] public List<Case> Cases { get; set; }
        }

        private sealed class Case
        {
            [JsonProperty("id")] public string Id { get; set; }
            [JsonProperty("title")] public string Title { get; set; }
            [JsonProperty("section")] public string Section { get; set; }
            [JsonProperty("section_title")] public string SectionTitle { get; set; }
            [JsonProperty("section_url")] public string SectionUrl { get; set; }
            [JsonProperty("paragraph")] public string Paragraph { get; set; }
            [JsonProperty("requirement")] public string Requirement { get; set; }
            [JsonProperty("expect")] public string Expect { get; set; }
            [JsonProperty("input")] public string Input { get; set; }
            [JsonProperty("input_encoding")] public string InputEncoding { get; set; }
            [JsonProperty("decoded")] public JToken Decoded { get; set; }
            [JsonProperty("schema")] public JToken Schema { get; set; }
        }

        [ProtoContract]
        private sealed class PbDoc
        {
            [ProtoMember(1)] public int N { get; set; }
            [ProtoMember(2)] public string S { get; set; } = "";
            [ProtoMember(3)] public bool Ok { get; set; }
            [ProtoMember(4, IsPacked = true)] public List<int> Tags { get; set; } = new();
        }

        private static object DecodeGoogleProtobuf(byte[] data, string schema)
        {
            if (schema == "json")
                return PbDocFromJson(data);
            return PbDocFromWire(data);
        }

        private static object DecodeProtobufNet(byte[] data, string schema)
        {
            if (schema == "json")
                return PbDocFromJson(data);
            var doc = ProtoBuf.Serializer.Deserialize<PbDoc>(new MemoryStream(data));
            return PbDocMap(doc);
        }

        private static Dictionary<string, object> PbDocFromWire(byte[] data)
        {
            var doc = new PbDoc();
            var input = new CodedInputStream(data);
            uint tag;
            while ((tag = input.ReadTag()) != 0)
            {
                var field = WireFormat.GetTagFieldNumber(tag);
                var wt = WireFormat.GetTagWireType(tag);
                if (field == 1 && wt == WireFormat.WireType.Varint)
                    doc.N = input.ReadInt32();
                else if (field == 2 && wt == WireFormat.WireType.LengthDelimited)
                    doc.S = input.ReadString();
                else if (field == 3 && wt == WireFormat.WireType.Varint)
                    doc.Ok = input.ReadBool();
                else if (field == 4 && wt == WireFormat.WireType.Varint)
                    doc.Tags.Add(input.ReadInt32());
                else if (field == 4 && wt == WireFormat.WireType.LengthDelimited)
                {
                    var payload = input.ReadBytes();
                    var inner = new CodedInputStream(payload.ToByteArray());
                    while (!inner.IsAtEnd)
                        doc.Tags.Add(inner.ReadInt32());
                }
                else if ((int)wt == 6 || (int)wt == 7)
                    throw new InvalidOperationException("invalid wire type");
                else
                    input.SkipLastField();
            }
            return PbDocMap(doc);
        }

        private static Dictionary<string, object> PbDocFromJson(byte[] data)
        {
            var tok = JToken.Parse(Encoding.UTF8.GetString(data));
            if (tok.Type != JTokenType.Object)
                throw new InvalidOperationException("proto3 JSON message must be an object");
            var obj = (JObject)tok;
            var doc = new PbDoc();
            if (obj["n"] != null && obj["n"].Type != JTokenType.Null)
                doc.N = PbInt32(obj["n"]);
            if (obj["s"] != null && obj["s"].Type != JTokenType.Null)
                doc.S = obj["s"].Type == JTokenType.String ? (string)obj["s"] : throw new InvalidOperationException("s");
            if (obj["ok"] != null && obj["ok"].Type != JTokenType.Null)
                doc.Ok = obj["ok"].Type == JTokenType.Boolean ? (bool)obj["ok"] : throw new InvalidOperationException("ok");
            if (obj["tags"] != null && obj["tags"].Type != JTokenType.Null)
            {
                if (obj["tags"].Type != JTokenType.Array)
                    throw new InvalidOperationException("tags");
                foreach (var t in (JArray)obj["tags"])
                    doc.Tags.Add(PbInt32(t));
            }
            return PbDocMap(doc);
        }

        private static int PbInt32(JToken t)
        {
            if (t.Type == JTokenType.Integer)
                return (int)t;
            if (t.Type == JTokenType.String && int.TryParse((string)t, out var n))
                return n;
            throw new InvalidOperationException("int32 must be a number or digit string");
        }

        private static Dictionary<string, object> PbDocMap(PbDoc doc) =>
            new() { ["n"] = doc.N, ["s"] = doc.S ?? "", ["ok"] = doc.Ok, ["tags"] = doc.Tags ?? new List<int>() };

        private sealed class Adapter
        {
            public string Name { get; }
            public string Format { get; }
            public string Version { get; }
            public Func<byte[], string, object> Decode { get; }
            public Adapter(string name, string format, string version, Func<byte[], string, object> decode)
            {
                Name = name; Format = format; Version = version; Decode = decode;
            }
        }
    }
}
