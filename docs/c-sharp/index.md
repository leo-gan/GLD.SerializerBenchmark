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
| FlatSharp | Schema / FlatBuffers | FlatSharp (blob table + MemoryPack payload of V2 domain) |
| FsPickler | Binary | FsPickler binary |
| FsPicklerJson | JSON | FsPickler JSON |
| Google.Protobuf | Schema | Official Google.Protobuf (`IMessage` / `benchmark_v2.proto`) |
| GroBuf | Binary | GroBuf |
| Hyperion | Binary | Hyperion (Akka.NET lineage) |
| Jil | JSON | Jil (Sigil) |
| Json.Net | JSON | Newtonsoft.Json |
| Json.Net (Helper) | JSON | Newtonsoft.Json helper path |
| MemoryPack | Binary | MemoryPack (domain types are `[MemoryPackable]`) |
| Migrant | Binary | Migrant |
| MS Binary | Binary (native) | Legacy `BinaryFormatter` path |
| MS Bond Compact | Schema / Bond | Bond Compact Binary; V2 domain marked `[Schema]` |
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

- **Domain types:** `Message`, `Document`, `Telemetry`, `Strings`, `Event` (+ batch wrappers) in [`c-sharp/src/TestData/V2/Models.cs`](../../c-sharp/src/TestData/V2/Models.cs).
- All registered serializers run on all suite fixtures. Most serialize domain types **directly** (attributes on the V2 models: `[DataContract]`, `[ProtoContract]`, `[Schema]`, `[MemoryPackable]`, …).
- A few codecs still need untimed `PrepareData` / `ToDomain` for **library wire format** (not old→new type mapping): Google.Protobuf (`IMessage` from `.proto`), ZeroFormatter (`KeyTuple` on net8), FlatSharp (blob + MemoryPack payload), CsvHelper / BinaryPack / ExtendedXml / Migrant (string envelopes where the library cannot hold nested graphs on net8). See serializer source comments.
- **Apex.Serialization** removed (crashes on .NET 8 `FieldInfoModifier`); **FluentSerializer** removed (cannot encode nested graphs / long strings reliably). **System.Text.Json** included.
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
