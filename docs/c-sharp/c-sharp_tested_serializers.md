# C# Tested Serializers

All **38** entries below are registered in [`c-sharp/src/Program.cs`](../../c-sharp/src/Program.cs). **Log name** is `SerializerName` in `logs/csharp/benchmark-log.csv`. Times are **ticks** (analysis converts to ns).

**Not in this suite:** System.Text.Json, MessagePack-CSharp, Wire (ecosystem only — see [C# overview](index.md)).

Format advice (when to choose JSON vs binary vs schema): [Selection Guide](../serializers/index.md). Suite-wide categories: [Serialization Categories](../analysis/serialization_categories.md).

| Log name | Category | Library / notes |
|----------|----------|-----------------|
| MS Binary | Binary (native) | Legacy `BinaryFormatter` path |
| MS Bond Compact | Schema / Bond | Bond Compact Binary; Bond-generated types under `src/Bond/` |
| MS Bond Fast | Schema / Bond | Bond Fast Binary |
| MS Bond Json | JSON / Bond | Bond JSON protocol |
| MS DataContract | XML | `DataContractSerializer` |
| MS DataContract Json | JSON | `DataContractJsonSerializer` |
| JavaScriptSerializer (N/A) | JSON (stub) | Legacy `System.Web`; not meaningful on .NET 8 |
| MS XmlSerializer | XML | Classic `XmlSerializer` |
| fastJson | JSON | FastJson |
| Jil | JSON | Jil (Sigil) |
| Json.Net (Helper) | JSON | Newtonsoft.Json helper path |
| Json.Net | JSON | Newtonsoft.Json |
| FsPickler | Binary | FsPickler binary |
| FsPicklerJson | JSON | FsPickler JSON |
| NetJSON | JSON | NetJSON |
| ProtoBuf | Schema | protobuf-net |
| SharpSerializer | Binary / XML | SharpSerializer |
| ServiceStack Json | JSON | ServiceStack.Text JSON |
| ServiceStack | Binary | ServiceStack type serializer (non-JSON) |
| Ceras | Binary | Ceras |
| CsvHelper | CSV | Flat tabular only |
| FlatSharp | Schema / FlatBuffers | FlatSharp (+ generated models for some fixtures) |
| FluentSerializer | JSON | FluentSerializer (needs profiles) |
| Google.Protobuf | Schema | Official Google.Protobuf (`IMessage` / `.proto`) |
| Hyperion | Binary | Hyperion (Akka.NET lineage) |
| NetSerializer | Binary | NetSerializer |
| SpanJson | JSON | SpanJson |
| Utf8Json | JSON | Utf8Json |
| YamlDotNet | YAML | YamlDotNet |
| YAXLib | XML | YAXLib |
| ZeroFormatter | Binary | ZeroFormatter (prefers zfc formatters) |
| BinaryPack | Binary | BinaryPack (`T : new()` constraints) |
| MemoryPack | Binary | MemoryPack (+ generator / models for some fixtures) |
| SharpYaml | YAML | SharpYaml |
| GroBuf | Binary | GroBuf |
| ExtendedXmlSerializer | XML | ExtendedXmlSerializer |
| Migrant | Binary | Migrant |
| Apex.Serialization | Binary | Apex.Serialization |

## Caveats (read before citing)

- **Coverage is per fixture**, not “all passed forever.” Many serializers skip or fail **ObjectGraph** (no cycles). Others only work on a subset (e.g. CsvHelper, ExtendedXmlSerializer, MemoryPack/FlatSharp model-backed types). Failures land in `logs/csharp/benchmark-errors.csv`; skips use harness `Supports()` where implemented.
- **Bond** uses Bond-generated types and schema attributes — not a free-form reflection pass over arbitrary POCOs.
- **Google.Protobuf**, **FluentSerializer**, **BinaryPack**, **ZeroFormatter**, **MemoryPack**, **FlatSharp** need schemas, profiles, or generated models; limited fixtures without them.
- **JavaScriptSerializer (N/A)** is a stub on modern .NET — do not treat timings as real.
- Status is **dynamic**: re-run benchmarks and inspect errors CSV rather than relying on historical “all passed” notes.
- Rankings for “fastest JSON” belong in **generated reports** (`analyze-benchmarks`), not this inventory.

## Related

- Harness: [`c-sharp/README.md`](../../c-sharp/README.md)
- Ecosystem context: [C# overview](index.md)
