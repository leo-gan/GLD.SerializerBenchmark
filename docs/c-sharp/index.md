---
title: "C#"
---

C#
===

In the .NET ecosystem, serialization has evolved dramatically over the past decade. With modern .NET memory primitives (`Span<T>`, `Memory<T>`) and source generators, the landscape shifted from heavy reflection-based engines to lower-allocation, code-generated libraries.

## Runtime

### What it is

C# is a programming language. It runs on **.NET**, a platform made of a virtual machine and a standard library. The virtual machine is called the **CLR** (Common Language Runtime). C# compiles first to an intermediate form named **IL**. The first time a method actually runs, the CLR translates that IL into native machine code. That late translation is called **JIT** (just-in-time compilation). Memory that the program no longer uses is reclaimed by a **garbage collector (GC)**. The programmer does not free objects by hand.

The label “.NET 8” names the **target framework**: the set of runtime APIs the compiled program is allowed to call. The **SDK** is the compiler and the rest of the build tools. In this suite those two version numbers are not the same.

| | This suite |
|---|---|
| Target | `net10.0` (.NET 10 APIs) |
| Host SDK | .NET SDK **10+** |
| Prepare | `./scripts/install-host-requirements.sh csharp` installs into `~/.dotnet` |
| Run | `dotnet build` and `dotnet run -c Release` through `c-sharp/scripts/run-benchmarks.sh` |
| Memory | Tracing garbage collector. No Docker. |

### What this suite runs

The project file targets `net10.0`, because the ShapeShift packages require the .NET 10 API surface. The .NET 10 SDK also satisfies LightProto's Roslyn 4.14 source-generator requirement. A **source generator** is a compiler plugin that writes extra C# while the project builds.

We build and run in the **Release** configuration, which turns on optimizations. The **Debug** configuration is slower, and the Dashboard numbers do not come from it. The `dotnet` tools live under the user’s home directory. There is no Docker container.

### What changes the numbers

The JIT compiles methods on first use, so the earliest repetitions are often slower than later ones. Analysis may drop those warmup rows. Creating many temporary strings or buffers makes the garbage collector pause the process. A library that looks faster on average can still lose on the slowest requests (the **latency tail**).

Modern codecs such as MemoryPack, FlatSharp, and SpanJson avoid extra copies by using `Span<T>`: a window over memory that already exists, rather than a new array. Source generators (MemoryPack, LightProto) write the encode and decode methods at build time. They therefore need a new enough SDK even when the target framework is still net8. Libraries that discover types by **reflection** (inspecting objects at run time) are simpler to write and usually allocate more.

### Suite-specific gotchas

Apex.Serialization was removed because it crashes on .NET 8. ZeroFormatter’s dynamic IL path is also broken on net8, so the suite uses `KeyTuple` shapes instead.

On the **string** path, binary codecs usually encode the payload as Base64. That extra encode and decode runs inside the timer. See [string vs stream](#string-mode-vs-stream-mode).

ExtendedXmlSerializer and Migrant do not serialize the suite objects as native XML or binary. They serialize a JSON envelope. See [envelope codecs](#envelope-codecs-not-native-domain-wire).

These times cannot be ranked against another language. The runtimes and garbage collectors are different.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`c-sharp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/README.md). Microsoft’s overview of the platform is [What is .NET](https://learn.microsoft.com/dotnet/core/introduction). For how garbage collection shows up in latency, see [Latency tails and GC](../theory/301/latency-tails-and-gc.md).

## Benchmark runner

- Directory: `c-sharp/` (repository root)
- Output: monorepo `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (`Language=csharp`, times in **nanoseconds**)
- Registration: [`c-sharp/src/Program.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Program.cs)
- **50 serializers** in `Program.cs` (was 47). Added `arrow-ipc`, `parquet`, `parquet-uncompressed`.
- **Not in this suite:** Wire; Apex.Serialization (crashes on .NET 8); FluentSerializer (unsuitable for suite graphs); **sbe** (no `Org.SbeTool.Sbe.Dll` 1.40.2 package — see [Columnar fixtures](#columnar-fixtures)); ORC; ParquetSharp

## Serializers

| Log name | Category | Library / notes |
|----------|----------|-----------------|
| [Amazon.IonDotnet](https://github.com/amazon-ion/ion-dotnet) | Binary | Ion team .NET binary reader/writer (NuGet `Amazon.IonDotnet`); reflection over suite types; `forceFloat64` |
| [Apache.Avro](https://github.com/apache/avro) | Schema | Official Apache.Avro Reflect on domain POCOs; schema once in Initialize |
| [arrow-ipc](https://github.com/apache/arrow-dotnet) | Columnar | Apache.Arrow **23.0.0** IPC **stream** (not the file format). String path is Base64 of those bytes. `table_project` reads the `FFloat0` value buffer only. Supports only `table`, `table_project`, `nested_table`, `signal`. No compliance decoder |
| [BinaryPack](https://github.com/Sergio0694/BinaryPack) | Binary | BinaryPack on domain types (`T : new()`); string mode = Base64 of bytes |
| [Ceras](https://github.com/rikimaru0345/Ceras) | Binary | Ceras |
| [CsvHelper](https://github.com/JoshClose/CsvHelper) | CSV | Row-list projection (message/event/strings only); real CsvHelper write/read |
| [ExtendedXmlSerializer](https://github.com/wojtpl2/ExtendedXmlSerializer) | XML (**envelope**) | **Not domain XML** — ExtendedXml of `{TypeName, Json}`; see [Envelope codecs](#envelope-codecs-not-native-domain-wire) |
| [fastJson](https://github.com/mgholam/fastJSON) | JSON | FastJson |
| [FlatSharp](https://github.com/jamescourtney/FlatSharp) | Schema / FlatBuffers | FlatSharp tables via domain map (untimed `PrepareData`) |
| [FsPickler](https://github.com/mbraceproject/FsPickler) | Binary | FsPickler binary |
| [FsPicklerJson](https://github.com/mbraceproject/FsPickler) | JSON | FsPickler JSON |
| [Google.Protobuf](https://github.com/protocolbuffers/protobuf) | Schema | Official Google.Protobuf (`IMessage` / `benchmark_v2.proto`) |
| [GroBuf](https://github.com/skbkontur/GroBuf) | Binary | GroBuf |
| [Hyperion](https://github.com/akkadotnet/Hyperion) | Binary | Hyperion (Akka.NET lineage) |
| [Json.Net](https://github.com/JamesNK/Newtonsoft.Json) | JSON | Newtonsoft.Json |
| [Json.Net (Helper)](https://github.com/JamesNK/Newtonsoft.Json) | JSON | Newtonsoft.Json helper path |
| [LightProto](https://github.com/dameng324/LightProto) | Schema | [LightProto](https://github.com/dameng324/LightProto) source-generated protobuf-net–style API on domain types (`[LightProto.ProtoContract]`); needs **.NET SDK 9+** at build time (Roslyn 4.14+) |
| [MemoryPack](https://github.com/Cysharp/MemoryPack) | Binary | MemoryPack (domain types are `[MemoryPackable]`) |
| [MessagePack-CSharp](https://github.com/MessagePack-CSharp/MessagePack-CSharp) | Binary | Official MessagePack-CSharp (`ContractlessStandardResolver` on domain POCOs) |
| [Nerdbank.MessagePack](https://github.com/AArnott/Nerdbank.MessagePack) | Binary | Nerdbank.MessagePack with reflection-based POCO shapes and stable numeric keys; its default-value retention is retained |
| [Migrant](https://github.com/antmicro/Migrant) | Binary (**envelope**) | **Not domain Migrant graphs** — Migrant of `{TypeName, Json}`; see [Envelope codecs](#envelope-codecs-not-native-domain-wire) |
| [MS Binary](https://github.com/dotnet/runtime) | Binary (native) | Legacy `BinaryFormatter` path |
| [MS Bond Compact](https://github.com/microsoft/bond) | Schema / Bond | Bond Compact Binary; V2 domain marked `[Schema]` |
| [MS Bond Fast](https://github.com/microsoft/bond) | Schema / Bond | Bond Fast Binary |
| [MS Bond Json](https://github.com/microsoft/bond) | JSON / Bond | Bond JSON protocol |
| [MS DataContract](https://github.com/dotnet/runtime) | XML | `DataContractSerializer` |
| [MS DataContract Json](https://github.com/dotnet/runtime) | JSON | `DataContractJsonSerializer` |
| [MS XmlSerializer](https://github.com/dotnet/runtime) | XML | Classic `XmlSerializer` (real domain XML when attributes allow) |
| [NetJSON](https://github.com/rpgmaker/NetJSON) | JSON | NetJSON |
| [NetSerializer](https://github.com/tomba/netserializer) | Binary | NetSerializer |
| [parquet](https://github.com/aloneguid/parquet-dotnet) | Columnar | Parquet.Net **6.1.0** (explicit `net10.0`), library default **Snappy**. String path is Base64. `table_project` reads the `FFloat0` data field only. No compliance decoder |
| [parquet-uncompressed](https://github.com/aloneguid/parquet-dotnet) | Columnar | Same Parquet.Net writer with `CompressionMethod.None`. String path is Base64. No compliance decoder |
| [ProtoBuf](https://github.com/protobuf-net/protobuf-net) | Schema | protobuf-net |
| [ServiceStack](https://github.com/ServiceStack/ServiceStack.Text) | Binary | ServiceStack type serializer (non-JSON) |
| [ServiceStack Json](https://github.com/ServiceStack/ServiceStack.Text) | JSON | ServiceStack.Text JSON |
| [SharpSerializer](https://github.com/polenter/SharpSerializer) | Binary / XML | SharpSerializer |
| [SharpYaml](https://github.com/xoofx/SharpYaml) | YAML | SharpYaml |
| [ShapeShift.Cbor](https://github.com/AArnott/ShapeShift) | Binary / CBOR | ShapeShift's source-generated CBOR serializer; string mode = Base64 of bytes |
| [ShapeShift.Json](https://github.com/AArnott/ShapeShift) | JSON | ShapeShift's source-generated JSON serializer |
| [ShapeShift.MsgPack](https://github.com/AArnott/ShapeShift) | Binary / MessagePack | ShapeShift's source-generated MessagePack serializer; string mode = Base64 of bytes |
| [ShapeShift.Protobuf](https://github.com/AArnott/ShapeShift) | Schema / Protobuf | ShapeShift's source-generated protobuf-style serializer; string mode = Base64 of bytes |
| [ShapeShift.Taml](https://github.com/AArnott/ShapeShift) | TAML | ShapeShift's source-generated TAML serializer (all suite data except `strings`) |
| [ShapeShift.Toml](https://github.com/AArnott/ShapeShift) | TOML | ShapeShift's source-generated TOML serializer |
| [ShapeShift.Yaml](https://github.com/AArnott/ShapeShift) | YAML | ShapeShift's source-generated YAML serializer |
| [SpanJson](https://github.com/Tornhoof/SpanJson) | JSON | SpanJson |
| [System.Text.Json](https://github.com/dotnet/runtime) | JSON | System.Text.Json (net8 built-in) |
| [Utf8Json](https://github.com/neuecc/Utf8Json) | JSON | Utf8Json |
| [YamlDotNet](https://github.com/aaubry/YamlDotNet) | YAML | YamlDotNet |
| [YAXLib](https://github.com/sinairv/YAXLib) | XML | YAXLib |
| [ZeroFormatter](https://github.com/neuecc/ZeroFormatter) | Binary | ZeroFormatter; **all data types** via `KeyTuple` / list shapes (`PrepareData` untimed) — dynamic `[ZeroFormattable]` IL is broken on .NET 8 |

### Columnar fixtures

The three new rows time **bytes only**: the harness string path, which is Base64 of the IPC stream or Parquet payload. That Base64 encode and decode is inside the timer. The stream path is **adapted** (the same buffer is copied onto the harness `Stream`). It is not a native streaming writer, and it is not the number to quote for these rows. There is **no compliance decoder** for Arrow or Parquet.

`Supports` on these rows is true only for `table`, `table_project`, `nested_table`, and `signal`. Older classes still default `Supports` to true. A columnar run without a comma-separated allow-list is forbidden: an empty filter selects all 50 names, and a filter with no comma is still a case-insensitive substring (`json` matches every JSON library). With a comma, names must match exactly, ignoring case. `json,` selects nothing. `protobuf,` selects only `ProtoBuf`, not `Google.Protobuf`, LightProto, or ShapeShift.Protobuf.

Allow-list for this tree (sbe omitted), and the names it selects, in registration order:

`FlatSharp`, `Google.Protobuf`, `Apache.Avro`, `System.Text.Json`, `arrow-ipc`, `parquet`, `parquet-uncompressed`

`table_project` serialize writes every column. Deserialize returns only `FFloat0` as a sequence of length N. Apache.Arrow and Parquet.Net project that column. The four peers decode the whole value, then slice `FFloat0` inside deserialize. The runner compares against that column.

`parquet` leaves compression at the library default (Snappy). `parquet-uncompressed` sets `CompressionMethod.None`. The byte payloads differ at N=100.

Apache.Arrow 23.0.0 publishes `net462`, `net8.0`, and `netstandard2.0` (no `net10.0` asset). This project stays on `net10.0` and consumes the `net8.0` asset. Parquet.Net 6.1.0 publishes `net10.0` and `net8.0`.

**sbe is not registered.** sbe-tool 1.40.2 accepts `schemas/v2/sbe/signal.xml` (fixed fields, then the legs group, then symbol and venue; `nested_table` is absent on purpose). The C# flyweights import `Org.SbeTool.Sbe.Dll`. No NuGet package provides that assembly on the 1.40.2 line. NuGet `sbe-tool` 1.23.1.1 (2021) is `net45` / `netstandard2.0` and ships `SBE.dll`, a different line. Maven `uk.co.real-logic:sbe-tool:1.40.2` is Java only. Generated code would also land in `Benchmark.V2`, which is already Google.Protobuf's `csharp_namespace`. The target was not retargeted, and the runtime was not vendored.

`./scripts/run-benchmarks.sh smoke` is unchanged: it still forces the Json.Net / message filter and `config/library/smoke.yaml` (message + telemetry only). Columnar smoke:

```bash
cd c-sharp
BENCHMARK_RUN_CONFIG=../config/library/columnar-smoke.yaml \
  ./scripts/run-benchmarks.sh custom 2 \
  "arrow-ipc,parquet,parquet-uncompressed,System.Text.Json,Google.Protobuf,FlatSharp,Apache.Avro"
```

The C# runner still times string and stream even when the YAML lists `io_modes: [bytes]`. Quote the string column for these rows. In-process checks (no second harness): `dotnet run --project src -c Release -- selfcheck`.

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [Amazon.IonDotnet](https://github.com/amazon-ion/ion-dotnet) · `1.3.2`

Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. Amazon.IonDotnet is the Ion team .NET reader and writer. NuGet marks the package deprecated and the GitHub repository is archived; the Ion libraries page still lists it. This row pins NuGet 1.3.2, the newest package published there (the page's 1.3.4 tag is not on NuGet) and the release that fixes CVE-2025-11573. The timed path reflects over the suite types and writes binary Ion with `forceFloat64` so doubles stay float64. The stream path writes to the harness `Stream`.

#### [Apache.Avro](https://github.com/apache/avro) · `1.12.2`

Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library. Columnar fixtures use the same reflect path. `table_project` deserialize returns `FFloat0` after a full decode.

#### [arrow-ipc](https://github.com/apache/arrow-dotnet) · `23.0.0`

Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times Apache.Arrow's stream writer and reader on the string path (Base64 of the IPC stream), not the Arrow file format. Row-to-column conversion stays inside serialize. `table_project` deserialize reads the `FFloat0` value buffer and does not build the other columns. There is no compliance decoder. The stream path is adapted. NuGet 23.0.0 has no `net10.0` lib; the suite consumes the `net8.0` asset from the `net10.0` project.

#### [BinaryPack](https://github.com/Sergio0694/BinaryPack) · `1.0.3`

BinaryPack is a compact binary serializer for .NET POCOs. It was written for fast, allocation-conscious binary packing of types that have a public parameterless constructor.

#### [Ceras](https://github.com/rikimaru0345/Ceras) · `4.1.7`

Ceras is a binary serializer for .NET object graphs. It was created as a modern, feature-rich alternative to BinaryFormatter-style packing without that formatter's security model.

#### [CsvHelper](https://github.com/JoshClose/CsvHelper) · `33.1.0`

CsvHelper was written so .NET could read and write CSV with a robust, mapping-based API. CSV exists as the simplest tabular exchange format. This row projects supported types to rows.

#### [ExtendedXmlSerializer](https://github.com/wojtpl2/ExtendedXmlSerializer) · `3.10.0.0`

ExtendedXmlSerializer is an XML serializer for .NET. In this suite the timed path is an envelope: ExtendedXml of `{TypeName, Json}`, not native domain XML. See the language inventory.

#### [fastJson](https://github.com/mgholam/fastJSON) · `2.4.0.4`

fastJSON (mgholam) is a small .NET JSON serializer. It was written to keep JSON simple and dependency-light. This row times that compact implementation.

#### [FlatSharp](https://github.com/jamescourtney/FlatSharp) · `7.5.1`

FlatSharp is a FlatBuffers implementation for .NET. FlatBuffers exists so readers can use serialized data without unpacking. FlatSharp generates C# from `.fbs` and times builder/parse on those tables. Columnar fixtures use hand-written `[FlatBufferTable]` types in `FlatSharpModels.cs` with the same slot order as the Python FlatBuffers schema. Shared `.fbs` files are not loaded. `table_project` deserialize returns `FFloat0` after a full decode.

#### [FsPickler](https://github.com/mbraceproject/FsPickler) · `5.3.2`

FsPickler is an F#/.NET pickler for fast binary (and JSON) serialization of .NET objects. It was created in the MBrace project so distributed F# could ship graphs efficiently.

#### [FsPicklerJson](https://github.com/mbraceproject/FsPickler) · `5.3.2`

FsPickler is an F#/.NET pickler for fast binary (and JSON) serialization of .NET objects. It was created in the MBrace project so distributed F# could ship graphs efficiently.

#### [Google.Protobuf](https://github.com/protocolbuffers/protobuf) · `3.36.2`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format. This is the primary protobuf row. Columnar messages come from `benchmark_v2.proto` (`csharp_namespace` `Benchmark.V2`). `table_project` deserialize returns `FFloat0` after a full decode.

#### [GroBuf](https://github.com/skbkontur/GroBuf) · `1.9.2`

GroBuf is a binary serializer from SKB Kontur for high-throughput .NET services. The problem was slow built-in serializers. GroBuf generates a compact binary for .NET types.

#### [Hyperion](https://github.com/akkadotnet/Hyperion) · `0.12.2`

Hyperion is the binary serializer from the Akka.NET lineage (formerly Wire). It exists so an actor system can ship .NET messages efficiently. This row times that graph codec.

#### [Json.Net](https://github.com/JamesNK/Newtonsoft.Json) · `13.0.4`

Json.NET (Newtonsoft.Json) became the de-facto JSON library for .NET long before System.Text.Json. The problem was limited framework JSON. James Newton-King built a flexible, attribute-driven serializer that still defines much of the ecosystem.

#### [Json.Net (Helper)](https://github.com/JamesNK/Newtonsoft.Json) · `13.0.4`

Json.NET (Newtonsoft.Json) became the de-facto JSON library for .NET long before System.Text.Json. The problem was limited framework JSON. James Newton-King built a flexible, attribute-driven serializer that still defines much of the ecosystem. This row times a helper call path of the same Newtonsoft library.

#### [LightProto](https://github.com/dameng324/LightProto) · `1.4.0`

LightProto is a source-generated, protobuf-net-style serializer for modern .NET. The problem was reflection-based protobuf-net on AOT and hot paths. LightProto generates parsers at compile time from `[LightProto.ProtoContract]`.

#### [MemoryPack](https://github.com/Cysharp/MemoryPack)

MemoryPack was created by Yoshifumi Kawai for extremely fast, source-generated binary serialization on modern .NET. The problem was existing binary libraries allocating and reflecting too much. `[MemoryPackable]` types get generated encode/decode.

#### [MessagePack-CSharp](https://github.com/MessagePack-CSharp/MessagePack-CSharp) · `2.5.305`

MessagePack-CSharp is the official MessagePack implementation for .NET (neuecc / MessagePack-CSharp). MessagePack exists as compact binary JSON. This library is the standard .NET codec, including a contractless resolver.

#### [Nerdbank.MessagePack](https://github.com/AArnott/Nerdbank.MessagePack) · `1.3.88`

Nerdbank.MessagePack is a modern .NET MessagePack serializer built on type shapes. This row uses reflection-based POCO shapes with stable numeric keys and the library's default value retention.

#### [Migrant](https://github.com/antmicro/Migrant) · `0.13.0.0`

Migrant is Antmicro's .NET binary serializer for object graphs. In this suite the timed path is a JSON envelope, not native Migrant domain graphs. See the language inventory.

#### [MS Binary](https://github.com/dotnet/runtime) · `.NET 10.0.10`

BinaryFormatter is legacy .NET binary serialization. It exists so the early framework could persist object graphs. It is obsolete and unsafe for untrusted input; the suite keeps the row as a historical baseline.

#### [MS Bond Compact](https://github.com/microsoft/bond) · `.NET 10.0.10`

Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema. This row times Bond Compact Binary.

#### [MS Bond Fast](https://github.com/microsoft/bond) · `.NET 10.0.10`

Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema. This row times Bond Fast Binary.

#### [MS Bond Json](https://github.com/microsoft/bond) · `.NET 10.0.10`

Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema. This row times the Bond JSON protocol.

#### [MS DataContract](https://github.com/dotnet/runtime) · `.NET 10.0.10`

DataContractSerializer and DataContractJsonSerializer are framework WCF-era serializers. They exist so .NET services could share an explicit data-contract model (XML or JSON) without XmlSerializer's older rules.

#### [MS DataContract Json](https://github.com/dotnet/runtime) · `.NET 10.0.10`

DataContractSerializer and DataContractJsonSerializer are framework WCF-era serializers. They exist so .NET services could share an explicit data-contract model (XML or JSON) without XmlSerializer's older rules.

#### [MS XmlSerializer](https://github.com/dotnet/runtime) · `.NET 10.0.10`

XmlSerializer is classic .NET XML serialization. It exists so the framework could map objects to XML documents. This row is real domain XML when the attributes allow it.

#### [NetJSON](https://github.com/rpgmaker/NetJSON) · `1.0.0`

NetJSON is a small, fast JSON serializer for .NET. It was created as a lighter alternative to the large JSON frameworks. This row times its default encode/decode path.

#### [NetSerializer](https://github.com/tomba/netserializer) · `4.1.2`

NetSerializer is a compact, fast binary serializer for .NET. It was written to pack predefined types with very little overhead compared to BinaryFormatter.

#### [parquet](https://github.com/aloneguid/parquet-dotnet) · `6.1.0`

Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times Parquet.Net with the library default compression, Snappy. Encodings stay at the library default. The timed call is the string path: Base64 of the Parquet bytes. `table_project` deserialize reads the `FFloat0` data field only. There is no compliance decoder. The stream path is adapted. The package has an explicit `net10.0` asset.

#### [parquet-uncompressed](https://github.com/aloneguid/parquet-dotnet) · `6.1.0`

This is the same Parquet.Net writer as `parquet`, with `CompressionMethod.None`. Encodings stay at the library default. The name is the override. Use this size when the question is layout rather than Snappy. At N=100 the bytes differ from `parquet`. The timed call is the string path (Base64). There is no compliance decoder. The stream path is adapted.

#### [ProtoBuf](https://github.com/protobuf-net/protobuf-net) · `2.4.9.1`

protobuf-net was created so .NET could speak Protocol Buffers without Google's generated C# being the only path. The problem was protobuf's IDL-first workflow for POCO-heavy .NET code. It attributes existing types (`[ProtoContract]`) and generates or interprets a protobuf-compatible encoding.

#### [ServiceStack](https://github.com/ServiceStack/ServiceStack.Text) · `6.11.0`

ServiceStack.Text is the serializer stack behind ServiceStack. It was created so that framework had a fast, built-in JSON (and JSV) codec. This suite times the JSON path and the non-JSON type serializer as separate rows. This row times the non-JSON ServiceStack type serializer.

#### [ServiceStack Json](https://github.com/ServiceStack/ServiceStack.Text) · `6.11.0`

ServiceStack.Text is the serializer stack behind ServiceStack. It was created so that framework had a fast, built-in JSON (and JSV) codec. This suite times the JSON path and the non-JSON type serializer as separate rows. This row times ServiceStack.Text JSON.

#### [SharpSerializer](https://github.com/polenter/SharpSerializer)

SharpSerializer is a .NET serializer that can write binary or XML. It was created as a simple, portable alternative to framework serializers for app persistence.

#### [SharpYaml](https://github.com/xoofx/SharpYaml) · `3.14.0`

SharpYaml is a YAML parser/emitter for .NET (a port/evolution of YamlDotNet lineage ideas). It exists as another maintained YAML stack for C#.

#### [ShapeShift.Cbor](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. String mode Base64-encodes the CBOR bytes. The package has no stream API, so the stream row adapts its byte-array API.

#### [ShapeShift.Json](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. String mode uses the serializer's string API. The stream row uses `SerializeAsync(Stream, ...)` and `DeserializeAsync(Stream)`.

#### [ShapeShift.MsgPack](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. String mode Base64-encodes MessagePack bytes. The stream row uses `SerializeAsync(Stream, ...)` and `DeserializeAsync(Stream)`.

#### [ShapeShift.Protobuf](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. String mode Base64-encodes bytes. The package has no stream API, so the stream row adapts its byte-array API.

#### [ShapeShift.Taml](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The package has no streaming text API, so the stream row adapts its complete string output. The `strings` fixture is unsupported because its N=100 batch cannot be deserialized.

#### [ShapeShift.Toml](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The package has no streaming text API, so the stream row adapts its complete string output.

#### [ShapeShift.Yaml](https://github.com/AArnott/ShapeShift) · `0.1.1068-alpha`

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The package has no streaming text API, so the stream row adapts its complete string output.

#### [SpanJson](https://github.com/Tornhoof/SpanJson) · `4.2.1`

SpanJson was created to serialize JSON on .NET using `Span<T>` and modern memory primitives. The problem was older JSON libraries allocating too many strings. It writes UTF-8 directly from spans.

#### [System.Text.Json](https://github.com/dotnet/runtime) · `10.0.0.0`

System.Text.Json is the built-in JSON serializer for modern .NET. It was created so the platform had a fast, AOT-friendly JSON stack without Newtonsoft. It solves that with a serializer in the runtime and source-generation options. Columnar POCOs use that same string API. `table_project` deserialize returns `FFloat0` after a full decode.

#### [Utf8Json](https://github.com/neuecc/Utf8Json) · `1.3.7`

Utf8Json was written by Yoshifumi Kawai (neuecc) as a fast UTF-8 JSON serializer for C#. The problem was string-heavy JSON APIs. It encodes directly to UTF-8 bytes.

#### [YamlDotNet](https://github.com/aaubry/YamlDotNet) · `17.1.0`

YamlDotNet is the usual YAML library for .NET. YAML exists as a human-friendly config language. YamlDotNet implements YAML 1.1/1.2 serialize/deserialize.

#### [YAXLib](https://github.com/sinairv/YAXLib) · `4.5.0`

YAXLib is a flexible XML serializer for .NET. The problem was XmlSerializer and DataContract being rigid about XML shape. YAXLib lets you control the XML more directly on domain types.

#### [ZeroFormatter](https://github.com/neuecc/ZeroFormatter) · `1.6.4`

ZeroFormatter was created (neuecc) as a fast, zero-encoding-style binary serializer for .NET, inspired by FlatBuffers/Cap'n Proto ideas. Dynamic IL is broken on .NET 8; this suite uses KeyTuple shapes.

### Envelope codecs (not native domain wire)

These rows stay in the matrix for history and size noise, but **Dashboard numbers must not be read as “library X serializes suite POCOs directly.”**

| Log name | Timed wire | Untimed fidelity | Stream mode |
|----------|------------|------------------|-------------|
| **ExtendedXmlSerializer** | ExtendedXml of `{ TypeName, Json }` where `Json` is Newtonsoft of the domain object | `ToDomain` deserializes JSON | **Adapted** — UTF-8 `StreamWriter` of the XML string |
| **Migrant** | Migrant of the same JSON envelope POCO | `ToDomain` deserializes JSON | **Native Migrant stream** of the envelope only; **string mode** is Base64 of those bytes |

Source: [`ExtendedXmlSerializerSer.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Serializers/ExtendedXmlSerializerSer.cs), [`MigrantSerializerSer.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Serializers/MigrantSerializerSer.cs).

**Compare fairly:** use **MS XmlSerializer** / **YAXLib** / **MS DataContract** for real XML-ish paths; use **Ceras**, **MemoryPack**, **NetSerializer**, etc. for binary domain graphs — not Migrant’s envelope row.

### String mode vs stream mode

CSV column `StringOrStream` is **`string`** or **`Stream`** (canonical mode labels: **bytes mode** often means the non-stream column; for C# that column is the **string** path).

| Path | Meaning on C# |
|------|----------------|
| **Stream** | `Serialize`/`Deserialize` with `Stream`. |
| **string** | `Serialize`/`Deserialize` with `string`. **Text** codecs return real text. **Binary** codecs usually return **Base64** of the byte payload (extra encode/decode on the timed path). |

**Stream honesty**

| Kind | What is timed | Examples |
|------|----------------|----------|
| **Adapted stream** | Stream path writes/reads a complete string, Base64 value, or in-memory buffer rather than using a native streaming API | **arrow-ipc**, **parquet**, **parquet-uncompressed** (full IPC/Parquet buffer copied onto the harness stream; the honest columnar number is the string/bytes path), ShapeShift.Cbor / ShapeShift.Protobuf / ShapeShift.Taml / ShapeShift.Toml / ShapeShift.Yaml, **ExtendedXmlSerializer**, CsvHelper (CSV text via StreamWriter), fastJson / NetJSON when they delegate to the string path, some Ceras string-delegate paths |
| **Native text stream** | Library writes/reads `Stream` directly with its text codec API | ShapeShift.Json |
| **Native binary stream** | Library writes/reads `Stream` with its binary API | ShapeShift.MsgPack, ProtoBuf, LightProto, Bond, BinaryPack, MemoryPack, NetSerializer, Hyperion, GroBuf, Google.Protobuf, Apache.Avro, DataContract*, FsPickler, ZeroFormatter, Migrant *(envelope only)*, … |
| **Text writer on stream** | Library writes to `TextWriter`/`JsonTextWriter` over the stream (real library streaming text API; not “serialize whole string then dump”) | Json.Net, YamlDotNet, SharpYaml, System.Text.Json (when bound to stream), … |

When stream ≈ string within a few percent on the Dashboard, check which kind applies. Prefer **within-mode** comparisons (string vs string, stream vs stream). **String mode for binary codecs** almost always includes Base64; do not compare that string size 1:1 with pure binary stream size without converting.

### Caveats

- Most codecs serialize domain types **directly** (attributes on V2 models: `[DataContract]`, `[ProtoContract]`, `[Schema]`, `[MemoryPackable]`, `[GenerateShape]`, …). Domain models live in [`c-sharp/src/TestData/V2/Models.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/TestData/V2/Models.cs).
- **Library-native prepare (still real domain or codegen forms):** Google.Protobuf (`IMessage`), ZeroFormatter (`KeyTuple` on net8), FlatSharp (tables via map), CsvHelper (row lists). These are **not** JSON envelopes.
- **Envelope exceptions:** ExtendedXmlSerializer and Migrant only — see above.
- **Apex.Serialization** removed (crashes on .NET 8 `FieldInfoModifier`); **FluentSerializer** removed (cannot encode nested graphs / long strings reliably). **System.Text.Json** included.
- SpanJson / Utf8Json cache closed generic delegates in `Initialize` (no per-call reflection).
- Benchmark runner no longer prints per-repetition DEBUG lines (measurement noise).
- Failures: `logs/csharp/<ts>.errors.csv` (per run).
- Rankings: use generated reports (`analyze-benchmarks`), not this list. Prefer [same category](../analysis/serialization_categories.md) and same I/O mode.

Benchmark runner: [`c-sharp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/README.md). Categories & format trade-offs: [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=csharp&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
