---
title: "C#"
---

C#
===

In the .NET ecosystem, serialization has evolved dramatically over the past decade. With modern .NET memory primitives (`Span<T>`, `Memory<T>`) and source generators, the landscape shifted from heavy reflection-based engines to lower-allocation, code-generated libraries.

## Benchmark runner

- Directory: `c-sharp/` (repository root)
- Output: monorepo `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (`Language=csharp`, times in **nanoseconds**)
- Registration: [`c-sharp/src/Program.cs`](../../c-sharp/src/Program.cs)
- **Not in this suite:** Wire; Apex.Serialization (crashes on .NET 8); FluentSerializer (unsuitable for suite graphs)

## Serializers

| Log name | Category | Library / notes |
|----------|----------|-----------------|
| Apache.Avro | Schema | Official Apache.Avro Reflect on domain POCOs; schema once in Initialize |
| BinaryPack | Binary | BinaryPack on domain types (`T : new()`); string mode = Base64 of bytes |
| Ceras | Binary | Ceras |
| CsvHelper | CSV | Row-list projection (message/event/strings only); real CsvHelper write/read |
| ExtendedXmlSerializer | XML (**envelope**) | **Not domain XML** — ExtendedXml of `{TypeName, Json}`; see [Envelope codecs](#envelope-codecs-not-native-domain-wire) |
| fastJson | JSON | FastJson |
| FlatSharp | Schema / FlatBuffers | FlatSharp tables via domain map (untimed `PrepareData`) |
| FsPickler | Binary | FsPickler binary |
| FsPicklerJson | JSON | FsPickler JSON |
| Google.Protobuf | Schema | Official Google.Protobuf (`IMessage` / `benchmark_v2.proto`) |
| GroBuf | Binary | GroBuf |
| Hyperion | Binary | Hyperion (Akka.NET lineage) |
| Jil | JSON | Jil (Sigil) |
| Json.Net | JSON | Newtonsoft.Json |
| Json.Net (Helper) | JSON | Newtonsoft.Json helper path |
| LightProto | Schema | [LightProto](https://github.com/dameng324/LightProto) source-generated protobuf-net–style API on domain types (`[LightProto.ProtoContract]`); needs **.NET SDK 9+** at build time (Roslyn 4.14+) |
| MemoryPack | Binary | MemoryPack (domain types are `[MemoryPackable]`) |
| MessagePack-CSharp | Binary | Official MessagePack-CSharp (`ContractlessStandardResolver` on domain POCOs) |
| Migrant | Binary (**envelope**) | **Not domain Migrant graphs** — Migrant of `{TypeName, Json}`; see [Envelope codecs](#envelope-codecs-not-native-domain-wire) |
| MS Binary | Binary (native) | Legacy `BinaryFormatter` path |
| MS Bond Compact | Schema / Bond | Bond Compact Binary; V2 domain marked `[Schema]` |
| MS Bond Fast | Schema / Bond | Bond Fast Binary |
| MS Bond Json | JSON / Bond | Bond JSON protocol |
| MS DataContract | XML | `DataContractSerializer` |
| MS DataContract Json | JSON | `DataContractJsonSerializer` |
| MS XmlSerializer | XML | Classic `XmlSerializer` (real domain XML when attributes allow) |
| NetJSON | JSON | NetJSON |
| NetSerializer | Binary | NetSerializer |
| ProtoBuf | Schema | protobuf-net |
| ServiceStack | Binary | ServiceStack type serializer (non-JSON) |
| ServiceStack Json | JSON | ServiceStack.Text JSON |
| SharpSerializer | Binary / XML | SharpSerializer |
| SharpYaml | YAML | SharpYaml |
| SpanJson | JSON | SpanJson |
| System.Text.Json | JSON | System.Text.Json (net8 built-in) |
| Utf8Json | JSON | Utf8Json |
| YamlDotNet | YAML | YamlDotNet |
| YAXLib | XML | YAXLib |
| ZeroFormatter | Binary | ZeroFormatter; **all data types** via `KeyTuple` / list shapes (`PrepareData` untimed) — dynamic `[ZeroFormattable]` IL is broken on .NET 8 |

### Envelope codecs (not native domain wire)

These rows stay in the matrix for history and size noise, but **Results must not be read as “library X serializes suite POCOs directly.”**

| Log name | Timed wire | Untimed fidelity | Stream mode |
|----------|------------|------------------|-------------|
| **ExtendedXmlSerializer** | ExtendedXml of `{ TypeName, Json }` where `Json` is Newtonsoft of the domain object | `ToDomain` deserializes JSON | **Adapted** — UTF-8 `StreamWriter` of the XML string |
| **Migrant** | Migrant of the same JSON envelope POCO | `ToDomain` deserializes JSON | **Native Migrant stream** of the envelope only; **string mode** is Base64 of those bytes |

Source: [`ExtendedXmlSerializerSer.cs`](../../c-sharp/src/Serializers/ExtendedXmlSerializerSer.cs), [`MigrantSerializerSer.cs`](../../c-sharp/src/Serializers/MigrantSerializerSer.cs).

**Compare fairly:** use **MS XmlSerializer** / **YAXLib** / **MS DataContract** for real XML-ish paths; use **Ceras**, **MemoryPack**, **NetSerializer**, etc. for binary domain graphs — not Migrant’s envelope row.

### String mode vs stream mode

CSV column `StringOrStream` is **`string`** or **`Stream`** (Results labels: **bytes mode** often means the non-stream column; for C# that column is the **string** path).

| Path | Meaning on C# |
|------|----------------|
| **Stream** | `Serialize`/`Deserialize` with `Stream`. |
| **string** | `Serialize`/`Deserialize` with `string`. **Text** codecs return real text. **Binary** codecs usually return **Base64** of the byte payload (extra encode/decode on the timed path). |

**Stream honesty**

| Kind | What is timed | Examples |
|------|----------------|----------|
| **Adapted stream** | Stream path is “take the full string (or Base64) path and write/read it” via `StreamWriter`/`StreamReader` | **ExtendedXmlSerializer**, CsvHelper (CSV text via StreamWriter), fastJson / NetJSON when they delegate to the string path, some Ceras string-delegate paths |
| **Native binary stream** | Library writes/reads `Stream` with its binary API | ProtoBuf, LightProto, Bond, BinaryPack, MemoryPack, NetSerializer, Hyperion, GroBuf, Google.Protobuf, Apache.Avro, DataContract*, FsPickler, ZeroFormatter, Migrant *(envelope only)*, … |
| **Text writer on stream** | Library writes to `TextWriter`/`JsonTextWriter` over the stream (real library streaming text API; not “serialize whole string then dump”) | Json.Net, Jil, YamlDotNet, SharpYaml, System.Text.Json (when bound to stream), … |

When stream ≈ string within a few percent on Results, check which kind applies. Prefer **within-mode** comparisons (string vs string, stream vs stream). **String mode for binary codecs** almost always includes Base64; do not compare that string size 1:1 with pure binary stream size without converting.

### Caveats

- Most codecs serialize domain types **directly** (attributes on V2 models: `[DataContract]`, `[ProtoContract]`, `[Schema]`, `[MemoryPackable]`, …). Domain models live in [`c-sharp/src/TestData/V2/Models.cs`](../../c-sharp/src/TestData/V2/Models.cs).
- **Library-native prepare (still real domain or codegen forms):** Google.Protobuf (`IMessage`), ZeroFormatter (`KeyTuple` on net8), FlatSharp (tables via map), CsvHelper (row lists). These are **not** JSON envelopes.
- **Envelope exceptions:** ExtendedXmlSerializer and Migrant only — see above.
- **Apex.Serialization** removed (crashes on .NET 8 `FieldInfoModifier`); **FluentSerializer** removed (cannot encode nested graphs / long strings reliably). **System.Text.Json** included.
- SpanJson / Utf8Json cache closed generic delegates in `Initialize` (no per-call reflection).
- Jil reuses a single static `Options` instance.
- Benchmark runner no longer prints per-repetition DEBUG lines (measurement noise).
- Failures: `logs/csharp/<ts>.errors.csv` (per run).
- Rankings: use generated reports (`analyze-benchmarks`), not this list. Prefer [same category](../analysis/serialization_categories.md) and same I/O mode.

Benchmark runner: [`c-sharp/README.md`](../../c-sharp/README.md). Categories & format trade-offs: [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=csharp&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

## The Power of `Span<T>` and `Memory<T>`

Historically, reading a byte array meant copying parts of it into new arrays. Modern serializers can create a window over existing memory without allocating new objects. Serializers in this suite that lean on modern layouts include **MemoryPack** and **FlatSharp** (among others).

## AOT and Source Generators

Reflection is slow and breaks down in AOT scenarios. Source generators produce hard-coded serialization methods at build time. In this suite, **MemoryPack** is the clearest example of that approach.

## The Garbage Collector (GC) Pressure

In high-throughput .NET applications, a common bottleneck is Garbage Collection from temporary strings or buffers. Choosing a serializer is often as much about allocations as about raw CPU time.
