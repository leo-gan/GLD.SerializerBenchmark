# The C# Ecosystem: High-Performance Serialization

In the .NET ecosystem, serialization has evolved dramatically over the past decade. With modern .NET memory primitives (`Span<T>`, `Memory<T>`) and source generators, the landscape shifted from heavy reflection-based engines to lower-allocation, code-generated libraries.

## What this benchmark measures vs the wider ecosystem

This suite registers **38 serializers** in [`c-sharp/src/Program.cs`](../../c-sharp/src/Program.cs). Log names appear as `SerializerName` in `logs/csharp/benchmark-log.csv` (times in **ticks**; analysis converts to ns).

**Not in this suite:** System.Text.Json, MessagePack-CSharp, Wire (ecosystem context only).

| Log name | Category | Library / notes |
|----------|----------|-----------------|
| MS Binary | Binary (native) | Legacy `BinaryFormatter` path |
| MS Bond Compact | Schema / Bond | Bond Compact Binary; types under `src/Bond/` |
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

### Caveats

- Coverage is **per fixture**; many skip/fail **ObjectGraph**. Failures: `logs/csharp/benchmark-errors.csv`.
- Bond, Google.Protobuf, FluentSerializer, BinaryPack, ZeroFormatter, MemoryPack, FlatSharp often need schemas or generated models.
- **JavaScriptSerializer (N/A)** is a stub — do not treat timings as real.
- Rankings: use generated reports (`analyze-benchmarks`), not this list.

Harness: [`c-sharp/README.md`](../../c-sharp/README.md). Format trade-offs: [Selection Guide](../serializers/index.md). Categories: [Serialization Categories](../analysis/serialization_categories.md).

## The Power of `Span<T>` and `Memory<T>`

Historically, reading a byte array meant copying parts of it into new arrays. Modern serializers can create a window over existing memory without allocating new objects. Serializers in this suite that lean on modern layouts include **MemoryPack** and **FlatSharp** (among others).

## AOT and Source Generators

Reflection is slow and breaks down in AOT scenarios. Source generators produce hard-coded serialization methods at build time. In this suite, **MemoryPack** is the clearest example of that approach.

## The Garbage Collector (GC) Pressure

In high-throughput .NET applications, a common bottleneck is Garbage Collection from temporary strings or buffers. Choosing a serializer is often as much about allocations as about raw CPU time.
