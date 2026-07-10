# C#

In the .NET ecosystem, serialization has evolved dramatically over the past decade. With modern .NET memory primitives (`Span<T>`, `Memory<T>`) and source generators, the landscape shifted from heavy reflection-based engines to lower-allocation, code-generated libraries.

## What this benchmark measures vs the wider ecosystem

This suite registers **36 serializers** in [`c-sharp/src/Program.cs`](../../c-sharp/src/Program.cs). Log names appear as `SerializerName` in `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (times in **nanoseconds**).

**Not in this suite:** MessagePack-CSharp, Wire; Apex.Serialization (crashes on .NET 8); FluentSerializer (unsuitable for suite graphs).

| Log name | Category | Library / notes |
|----------|----------|-----------------|
| System.Text.Json | JSON | System.Text.Json (net8 built-in) |
| BinaryPack | Binary | BinaryPack (`T : new()` constraints) |
| Ceras | Binary | Ceras |
| CsvHelper | CSV | Tabular projection of suite types in `PrepareData` |
| ExtendedXmlSerializer | XML | ExtendedXmlSerializer |
| fastJson | JSON | FastJson |
| FlatSharp | Schema / FlatBuffers | FlatSharp (+ generated models for some fixtures) |
| FsPickler | Binary | FsPickler binary |
| FsPicklerJson | JSON | FsPickler JSON |
| Google.Protobuf | Schema | Official Google.Protobuf (`IMessage` / `.proto`) |
| GroBuf | Binary | GroBuf |
| Hyperion | Binary | Hyperion (Akka.NET lineage) |
| Jil | JSON | Jil (Sigil) |
| Json.Net | JSON | Newtonsoft.Json |
| Json.Net (Helper) | JSON | Newtonsoft.Json helper path |
| MemoryPack | Binary | MemoryPack (+ generator / models for some fixtures) |
| Migrant | Binary | Migrant |
| MS Binary | Binary (native) | Legacy `BinaryFormatter` path |
| MS Bond Compact | Schema / Bond | Bond Compact Binary; types under `src/Bond/` |
| MS Bond Fast | Schema / Bond | Bond Fast Binary |
| MS Bond Json | JSON / Bond | Bond JSON protocol |
| MS DataContract | XML | `DataContractSerializer` |
| MS DataContract Json | JSON | `DataContractJsonSerializer` |
| MS XmlSerializer | XML | Classic `XmlSerializer` |
| NetJSON | JSON | NetJSON |
| NetSerializer | Binary | NetSerializer |
| ProtoBuf | Schema | protobuf-net |
| ServiceStack | Binary | ServiceStack type serializer (non-JSON) |
| ServiceStack Json | JSON | ServiceStack.Text JSON |
| SharpSerializer | Binary / XML | SharpSerializer |
| SharpYaml | YAML | SharpYaml |
| SpanJson | JSON | SpanJson |
| Utf8Json | JSON | Utf8Json |
| YamlDotNet | YAML | YamlDotNet |
| YAXLib | XML | YAXLib |
| ZeroFormatter | Binary | ZeroFormatter; **all fixtures** via `KeyTuple` / list shapes (`PrepareData` untimed) — dynamic `[ZeroFormattable]` IL is broken on .NET 8 |

### Caveats

- Suite fixtures: `message`, `document`, `telemetry`, `strings`, `event` (payload POCOs under `TestData/`).
- All registered serializers run on all suite fixtures. Some codecs project suite graphs to library-native or envelope forms in untimed `PrepareData` (see serializer source comments): CsvHelper (tabular projection), Google.Protobuf (v2 proto mapping), Bond/MemoryPack/FlatSharp (annotated models), ExtendedXml/BinaryPack/Migrant (string envelopes for net8 compatibility). **Apex.Serialization** was removed (crashes on .NET 8 `FieldInfoModifier`); **FluentSerializer** removed (cannot encode nested graphs / long strings reliably). **System.Text.Json** added.
- MemoryPack / FlatSharp map supported fixtures via annotated models in `PrepareData` (timed path is codec-only; `ToDomain` untimed).
- ZeroFormatter maps **all** suite fixtures to `KeyTuple` graphs (max arity 8; Telemetry nested).
- SpanJson / Utf8Json cache closed generic delegates in `Initialize` (no per-call reflection).
- Jil reuses a single static `Options` instance.
- Harness no longer prints per-repetition DEBUG lines (measurement noise).

- Failures: `logs/csharp/<ts>.errors.csv` (per run).
- Rankings: use generated reports (`analyze-benchmarks`), not this list.

Harness: [`c-sharp/README.md`](../../c-sharp/README.md). Categories & format trade-offs: [Serialization Categories](../analysis/serialization_categories.md).

## The Power of `Span<T>` and `Memory<T>`

Historically, reading a byte array meant copying parts of it into new arrays. Modern serializers can create a window over existing memory without allocating new objects. Serializers in this suite that lean on modern layouts include **MemoryPack** and **FlatSharp** (among others).

## AOT and Source Generators

Reflection is slow and breaks down in AOT scenarios. Source generators produce hard-coded serialization methods at build time. In this suite, **MemoryPack** is the clearest example of that approach.

## The Garbage Collector (GC) Pressure

In high-throughput .NET applications, a common bottleneck is Garbage Collection from temporary strings or buffers. Choosing a serializer is often as much about allocations as about raw CPU time.
