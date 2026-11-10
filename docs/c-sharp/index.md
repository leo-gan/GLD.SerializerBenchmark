---
title: "C#"
---

C#
===

In the .NET ecosystem, serialization has evolved dramatically over the past decade. With modern .NET memory primitives (`Span<T>`, `Memory<T>`) and source generators, the landscape shifted from heavy reflection-based engines to lower-allocation, code-generated libraries.

## Runtime

### What it is

C# is a programming language. It runs on **.NET**, a platform made of a virtual machine and a standard library. The virtual machine is called the **CLR** (Common Language Runtime). C# compiles first to an intermediate form named **IL**. The first time a method actually runs, the CLR translates that IL into native machine code. That late translation is called **JIT** (just-in-time compilation). Memory that the program no longer uses is reclaimed by a **garbage collector (GC)**. The programmer does not free objects by hand.

The label “.NET 10” names the **target framework**: the set of runtime APIs the compiled program is allowed to call. The **SDK** is the compiler and the rest of the build tools. This suite’s target and SDK are both .NET 10.

The language is specified by the [C# language specification](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/introduction) and by [ECMA-334](https://ecma-international.org/publications-and-standards/standards/ecma-334/). The CLR and IL are specified by [ECMA-335](https://ecma-international.org/publications-and-standards/standards/ecma-335/), the Common Language Infrastructure.

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

Modern codecs such as MemoryPack, FlatSharp, and SpanJson avoid extra copies by using `Span<T>`: a window over memory that already exists, rather than a new array. Source generators (MemoryPack, LightProto) write the encode and decode methods at build time. They need the .NET 10 SDK, which is also what the `net10.0` target requires. Libraries that discover types by **reflection** (inspecting objects at run time) are simpler to write and usually allocate more.

### Suite-specific gotchas

Apex.Serialization was removed because it crashes on .NET 8. ZeroFormatter’s dynamic IL path is also broken on net8, so the suite uses `KeyTuple` shapes instead.

The in-memory path is `bytes`, the same label the other languages use. See [bytes and stream](#bytes-mode-and-stream-mode).

ExtendedXmlSerializer and Migrant do not serialize the suite objects as native XML or binary. They serialize a JSON envelope. See [envelope codecs](#envelope-codecs-not-native-domain-wire).

These times cannot be ranked against another language. The runtimes and garbage collectors are different.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`c-sharp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/README.md). Microsoft’s overview of the platform is [What is .NET](https://learn.microsoft.com/dotnet/core/introduction). For how garbage collection shows up in latency, see [Latency tails and GC](../theory/301/latency-tails-and-gc.md).

## Benchmark runner

- Directory: `c-sharp/` (repository root)
- Output: monorepo `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (`Language=csharp`, times in **nanoseconds**)
- Registration: [`c-sharp/src/Program.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Program.cs)
- **53 serializers** in `Program.cs`. Includes `arrow-ipc`, `parquet`, `parquet-uncompressed`, `fory`, and `gld-kiln`.
- **Not in this suite:** Wire; Apex.Serialization (crashes on .NET 8); FluentSerializer (unsuitable for suite graphs); **sbe** (no `Org.SbeTool.Sbe.Dll` 1.40.2 package — see [Columnar fixtures](#columnar-fixtures)); ORC; ParquetSharp

## Serializers

| Log name | Category | Library / notes |
|----------|----------|-----------------|
| [Amazon.IonDotnet](https://github.com/amazon-ion/ion-dotnet) | Binary | Ion team .NET binary reader/writer (NuGet `Amazon.IonDotnet`); reflection over suite types; `forceFloat64` |
| [Apache.Avro](https://github.com/apache/avro) | Schema | Official Apache.Avro Reflect on domain POCOs; schema once in Initialize |
| [arrow-ipc](https://github.com/apache/arrow-dotnet) | Columnar | Apache.Arrow **23.0.0** IPC **stream** (not the file format). Bytes path is the IPC payload. `table_project` reads the `FFloat0` value buffer only. Supports only `table`, `table_project`, `nested_table`, `signal`. No compliance decoder |
| [BinaryPack](https://github.com/Sergio0694/BinaryPack) | Binary | BinaryPack on domain types (`T : new()`); bytes path is the library payload |
| [Ceras](https://github.com/rikimaru0345/Ceras) | Binary | Ceras |
| [CsvHelper](https://github.com/JoshClose/CsvHelper) | CSV | Row-list projection (message/event/strings only); real CsvHelper write/read |
| [ExtendedXmlSerializer](https://github.com/wojtpl2/ExtendedXmlSerializer) | XML (**envelope**) | **Not domain XML** — ExtendedXml of `{TypeName, Json}`; see [Envelope codecs](#envelope-codecs-not-native-domain-wire) |
| [fastJson](https://github.com/mgholam/fastJSON) | JSON | FastJson |
| [FlatSharp](https://github.com/jamescourtney/FlatSharp) | Schema / FlatBuffers | FlatSharp tables via domain map (untimed `PrepareData`) |
| [fory](https://github.com/apache/fory) | Binary | Apache.Fory source-generated serializers on `[ForyStruct]` domain types; bytes path is the library payload; stream is adapted |
| [FsPickler](https://github.com/mbraceproject/FsPickler) | Binary | FsPickler binary |
| [FsPicklerJson](https://github.com/mbraceproject/FsPickler) | JSON | FsPickler JSON |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-csharp) | Binary | `Gld.Kiln` 0.2.0 from git tag `0.2.0`; positional `Writer.Encode` / decode; a batch is one list; bytes path is the library payload |
| [Google.Protobuf](https://github.com/protocolbuffers/protobuf) | Schema | Official Google.Protobuf (`IMessage` / `benchmark_v2.proto`) |
| [GroBuf](https://github.com/skbkontur/GroBuf) | Binary | GroBuf |
| [Hyperion](https://github.com/akkadotnet/Hyperion) | Binary | Hyperion (Akka.NET lineage) |
| [Json.Net](https://github.com/JamesNK/Newtonsoft.Json) | JSON | Newtonsoft.Json |
| [Json.Net (Helper)](https://github.com/JamesNK/Newtonsoft.Json) | JSON | Newtonsoft.Json helper path |
| [LightProto](https://github.com/dameng324/LightProto) | Schema | [LightProto](https://github.com/dameng324/LightProto) source-generated protobuf-net–style API on domain types (`[LightProto.ProtoContract]`); needs **.NET SDK 10+** at build time (the `net10.0` target; Roslyn 4.14+) |
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
| [parquet](https://github.com/aloneguid/parquet-dotnet) | Columnar | Parquet.Net **6.1.0** (explicit `net10.0`), library default **Snappy**. Bytes path is the Parquet payload. `table_project` reads the `FFloat0` data field only. No compliance decoder |
| [parquet-uncompressed](https://github.com/aloneguid/parquet-dotnet) | Columnar | Same Parquet.Net writer with `CompressionMethod.None`. Bytes path is the Parquet payload. No compliance decoder |
| [ProtoBuf](https://github.com/protobuf-net/protobuf-net) | Schema | protobuf-net |
| [ServiceStack](https://github.com/ServiceStack/ServiceStack.Text) | Binary | ServiceStack type serializer (non-JSON) |
| [ServiceStack Json](https://github.com/ServiceStack/ServiceStack.Text) | JSON | ServiceStack.Text JSON |
| [SharpSerializer](https://github.com/polenter/SharpSerializer) | Binary / XML | SharpSerializer |
| [SharpYaml](https://github.com/xoofx/SharpYaml) | YAML | SharpYaml |
| [ShapeShift.Cbor](https://github.com/AArnott/ShapeShift) | Binary / CBOR | ShapeShift's source-generated CBOR serializer; bytes path is the library payload |
| [ShapeShift.Json](https://github.com/AArnott/ShapeShift) | JSON | ShapeShift's source-generated JSON serializer |
| [ShapeShift.MsgPack](https://github.com/AArnott/ShapeShift) | Binary / MessagePack | ShapeShift's source-generated MessagePack serializer; bytes path is the library payload |
| [ShapeShift.Protobuf](https://github.com/AArnott/ShapeShift) | Schema / Protobuf | ShapeShift's source-generated protobuf-style serializer; bytes path is the library payload |
| [ShapeShift.Taml](https://github.com/AArnott/ShapeShift) | TAML | ShapeShift's source-generated TAML serializer (all suite data except `strings`) |
| [ShapeShift.Toml](https://github.com/AArnott/ShapeShift) | TOML | ShapeShift's source-generated TOML serializer |
| [ShapeShift.Yaml](https://github.com/AArnott/ShapeShift) | YAML | ShapeShift's source-generated YAML serializer |
| [SpanJson](https://github.com/Tornhoof/SpanJson) | JSON | SpanJson |
| [System.Text.Json](https://github.com/dotnet/runtime) | JSON | System.Text.Json (built into .NET 10) |
| [Utf8Json](https://github.com/neuecc/Utf8Json) | JSON | Utf8Json |
| [YamlDotNet](https://github.com/aaubry/YamlDotNet) | YAML | YamlDotNet |
| [YAXLib](https://github.com/sinairv/YAXLib) | XML | YAXLib |
| [ZeroFormatter](https://github.com/neuecc/ZeroFormatter) | Binary | ZeroFormatter; **all data types** via `KeyTuple` / list shapes (`PrepareData` untimed) — dynamic `[ZeroFormattable]` IL is broken on .NET 8 |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times).

#### [Amazon.IonDotnet](https://github.com/amazon-ion/ion-dotnet)

Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. Amazon.IonDotnet is the Ion team .NET reader and writer. NuGet marks the package deprecated and the GitHub repository is archived; the Ion libraries page still lists it. This row pins NuGet 1.3.2 (the newest package there; it fixes CVE-2025-11573) and reflects over the suite types to write binary Ion.

#### [Apache.Avro](https://github.com/apache/avro)

Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.

#### [arrow-ipc](https://github.com/apache/arrow-dotnet)

Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times Apache.Arrow 23.0.0 stream writer and reader on the bytes path, not the Arrow file format. Row-to-column conversion stays inside serialize. table_project reads the FFloat0 value buffer. NuGet 23.0.0 has no net10.0 asset; the net10.0 project consumes the net8.0 asset. No compliance decoder.

#### [BinaryPack](https://github.com/Sergio0694/BinaryPack)

BinaryPack is a compact binary serializer for .NET POCOs. It was written for fast, allocation-conscious binary packing of types that have a public parameterless constructor.

#### [Ceras](https://github.com/rikimaru0345/Ceras)

Ceras is a binary serializer for .NET object graphs. It was created as a modern, feature-rich alternative to BinaryFormatter-style packing without that formatter's security model.

#### [CsvHelper](https://github.com/JoshClose/CsvHelper)

CsvHelper was written so .NET could read and write CSV with a robust, mapping-based API. CSV exists as the simplest tabular exchange format. This row projects supported types to rows.

#### [ExtendedXmlSerializer](https://github.com/wojtpl2/ExtendedXmlSerializer)

ExtendedXmlSerializer is an XML serializer for .NET. In this suite the timed path is an envelope: ExtendedXml of `{TypeName, Json}`, not native domain XML. See the language inventory.

#### [fastJson](https://github.com/mgholam/fastJSON)

fastJSON (mgholam) is a small .NET JSON serializer. It was written to keep JSON simple and dependency-light. This row times that compact implementation.

#### [FlatSharp](https://github.com/jamescourtney/FlatSharp)

FlatSharp is a FlatBuffers implementation for .NET. FlatBuffers exists so readers can use serialized data without unpacking. FlatSharp generates C# from `.fbs` and times builder/parse on those tables.

#### [fory](https://github.com/apache/fory)

Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses Apache.Fory source-generated serializers. The bytes path is the library payload, and the stream path is adapted.

#### [FsPickler](https://github.com/mbraceproject/FsPickler)

FsPickler is an F#/.NET pickler for fast binary (and JSON) serialization of .NET objects. It was created in the MBrace project so distributed F# could ship graphs efficiently.

#### [FsPicklerJson](https://github.com/mbraceproject/FsPickler)

FsPickler is an F#/.NET pickler for fast binary (and JSON) serialization of .NET objects. It was created in the MBrace project so distributed F# could ship graphs efficiently.

#### [gld-kiln](https://github.com/leo-gan/gld-kiln-csharp)

gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.

#### [Google.Protobuf](https://github.com/protocolbuffers/protobuf)

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [GroBuf](https://github.com/skbkontur/GroBuf)

GroBuf is a binary serializer from SKB Kontur for high-throughput .NET services. The problem was slow built-in serializers. GroBuf generates a compact binary for .NET types.

#### [Hyperion](https://github.com/akkadotnet/Hyperion)

Hyperion is the binary serializer from the Akka.NET lineage (formerly Wire). It exists so an actor system can ship .NET messages efficiently. This row times that graph codec.

#### [Json.Net](https://github.com/JamesNK/Newtonsoft.Json)

Json.NET (Newtonsoft.Json) became the de-facto JSON library for .NET long before System.Text.Json. The problem was limited framework JSON. James Newton-King built a flexible, attribute-driven serializer that still defines much of the ecosystem.

#### [Json.Net (Helper)](https://github.com/JamesNK/Newtonsoft.Json)

Json.NET (Newtonsoft.Json) became the de-facto JSON library for .NET long before System.Text.Json. The problem was limited framework JSON. James Newton-King built a flexible, attribute-driven serializer that still defines much of the ecosystem. This row times a helper call path of the same Newtonsoft library.

#### [LightProto](https://github.com/dameng324/LightProto)

LightProto is a source-generated, protobuf-net-style serializer for modern .NET. The problem was reflection-based protobuf-net on AOT and hot paths. LightProto generates parsers at compile time from `[LightProto.ProtoContract]`.

#### [MemoryPack](https://github.com/Cysharp/MemoryPack)

MemoryPack was created by Yoshifumi Kawai for extremely fast, source-generated binary serialization on modern .NET. The problem was existing binary libraries allocating and reflecting too much. `[MemoryPackable]` types get generated encode/decode.

#### [MessagePack-CSharp](https://github.com/MessagePack-CSharp/MessagePack-CSharp)

MessagePack-CSharp is the official MessagePack implementation for .NET (neuecc / MessagePack-CSharp). MessagePack exists as compact binary JSON. This library is the standard .NET codec, including a contractless resolver.

#### [Nerdbank.MessagePack](https://github.com/AArnott/Nerdbank.MessagePack)

Nerdbank.MessagePack is a modern .NET MessagePack serializer built on type shapes. This row uses reflection-based POCO shapes with stable numeric keys and the library's default value retention.

#### [Migrant](https://github.com/antmicro/Migrant)

Migrant is Antmicro's .NET binary serializer for object graphs. In this suite the timed path is a JSON envelope, not native Migrant domain graphs. See the language inventory.

#### [MS Binary](https://github.com/dotnet/runtime)

BinaryFormatter is legacy .NET binary serialization. It exists so the early framework could persist object graphs. It is obsolete and unsafe for untrusted input; the suite keeps the row as a historical baseline.

#### [MS Bond Compact](https://github.com/microsoft/bond)

Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema. This row times Bond Compact Binary.

#### [MS Bond Fast](https://github.com/microsoft/bond)

Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema. This row times Bond Fast Binary.

#### [MS Bond Json](https://github.com/microsoft/bond)

Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema. This row times the Bond JSON protocol.

#### [MS DataContract](https://github.com/dotnet/runtime)

DataContractSerializer and DataContractJsonSerializer are framework WCF-era serializers. They exist so .NET services could share an explicit data-contract model (XML or JSON) without XmlSerializer's older rules.

#### [MS DataContract Json](https://github.com/dotnet/runtime)

DataContractSerializer and DataContractJsonSerializer are framework WCF-era serializers. They exist so .NET services could share an explicit data-contract model (XML or JSON) without XmlSerializer's older rules.

#### [MS XmlSerializer](https://github.com/dotnet/runtime)

XmlSerializer is classic .NET XML serialization. It exists so the framework could map objects to XML documents. This row is real domain XML when the attributes allow it.

#### [NetJSON](https://github.com/rpgmaker/NetJSON)

NetJSON is a small, fast JSON serializer for .NET. It was created as a lighter alternative to the large JSON frameworks. This row times its default encode/decode path.

#### [NetSerializer](https://github.com/tomba/netserializer)

NetSerializer is a compact, fast binary serializer for .NET. It was written to pack predefined types with very little overhead compared to BinaryFormatter.

#### [parquet](https://github.com/aloneguid/parquet-dotnet)

Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times Parquet.Net 6.1.0 at the library default, Snappy. The timed call is the bytes path. table_project reads the FFloat0 data field. The package has an explicit net10.0 asset. No compliance decoder.

#### [parquet-uncompressed](https://github.com/aloneguid/parquet-dotnet)

This is the same Parquet.Net writer as parquet, with CompressionMethod.None. Encodings stay at the library default. The name is the override. No compliance decoder.

#### [ProtoBuf](https://github.com/protobuf-net/protobuf-net)

protobuf-net was created so .NET could speak Protocol Buffers without Google's generated C# being the only path. The problem was protobuf's IDL-first workflow for POCO-heavy .NET code. It attributes existing types (`[ProtoContract]`) and generates or interprets a protobuf-compatible encoding.

#### [ServiceStack](https://github.com/ServiceStack/ServiceStack.Text)

ServiceStack.Text is the serializer stack behind ServiceStack. It was created so that framework had a fast, built-in JSON (and JSV) codec. This suite times the JSON path and the non-JSON type serializer as separate rows. This row times the non-JSON ServiceStack type serializer.

#### [ServiceStack Json](https://github.com/ServiceStack/ServiceStack.Text)

ServiceStack.Text is the serializer stack behind ServiceStack. It was created so that framework had a fast, built-in JSON (and JSV) codec. This suite times the JSON path and the non-JSON type serializer as separate rows. This row times ServiceStack.Text JSON.

#### [SharpSerializer](https://github.com/polenter/SharpSerializer)

SharpSerializer is a .NET serializer that can write binary or XML. It was created as a simple, portable alternative to framework serializers for app persistence.

#### [SharpYaml](https://github.com/xoofx/SharpYaml)

SharpYaml is a YAML parser/emitter for .NET (a port/evolution of YamlDotNet lineage ideas). It exists as another maintained YAML stack for C#.

#### [ShapeShift.Cbor](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The bytes path is the CBOR payload. The package has no stream API, so the stream row adapts its byte-array API.

#### [ShapeShift.Json](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The bytes path is UTF-8 of the serializer's text API. The stream row uses `SerializeAsync(Stream, ...)` and `DeserializeAsync(Stream)`.

#### [ShapeShift.MsgPack](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The bytes path is the MessagePack payload. The stream row uses `SerializeAsync(Stream, ...)` and `DeserializeAsync(Stream)`.

#### [ShapeShift.Protobuf](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The bytes path is the library payload. The package has no stream API, so the stream row adapts its byte-array API.

#### [ShapeShift.Taml](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The package has no streaming text API, so the stream row adapts its complete string output. The `strings` fixture is unsupported because its N=100 batch cannot be deserialized.

#### [ShapeShift.Toml](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The package has no streaming text API, so the stream row adapts its complete string output.

#### [ShapeShift.Yaml](https://github.com/AArnott/ShapeShift)

ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time. The package has no streaming text API, so the stream row adapts its complete string output.

#### [SpanJson](https://github.com/Tornhoof/SpanJson)

SpanJson was created to serialize JSON on .NET using `Span<T>` and modern memory primitives. The problem was older JSON libraries allocating too many strings. It writes UTF-8 directly from spans.

#### [System.Text.Json](https://github.com/dotnet/runtime)

System.Text.Json is the built-in JSON serializer for modern .NET. It was created so the platform had a fast, AOT-friendly JSON stack without Newtonsoft. It solves that with a serializer in the runtime and source-generation options.

#### [Utf8Json](https://github.com/neuecc/Utf8Json)

Utf8Json was written by Yoshifumi Kawai (neuecc) as a fast UTF-8 JSON serializer for C#. The problem was string-heavy JSON APIs. It encodes directly to UTF-8 bytes.

#### [YamlDotNet](https://github.com/aaubry/YamlDotNet)

YamlDotNet is the usual YAML library for .NET. YAML exists as a human-friendly config language. YamlDotNet implements YAML 1.1/1.2 serialize/deserialize.

#### [YAXLib](https://github.com/sinairv/YAXLib)

YAXLib is a flexible XML serializer for .NET. The problem was XmlSerializer and DataContract being rigid about XML shape. YAXLib lets you control the XML more directly on domain types.

#### [ZeroFormatter](https://github.com/neuecc/ZeroFormatter)

ZeroFormatter was created (neuecc) as a fast, zero-encoding-style binary serializer for .NET, inspired by FlatBuffers/Cap'n Proto ideas. Dynamic IL is broken on .NET 8; this suite uses KeyTuple shapes.


### Columnar fixtures

Arrow and Parquet time the **bytes** path: the IPC or Parquet buffer. The stream path is **adapted** (the same buffer is copied onto the harness `Stream`). It is not a native streaming writer. There is **no compliance decoder** for Arrow or Parquet.

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

I/O modes come from the run config. `io_modes: [bytes]` still adds `stream` when a selected name is on the shared opt-in list, the same rule as the other runners. In-process checks: `dotnet run --project src -c Release -- selfcheck`.

### Envelope codecs (not native domain wire)

These rows stay in the matrix for history and size noise, but **Dashboard numbers must not be read as “library X serializes suite POCOs directly.”**

| Log name | Timed wire | Untimed fidelity | Stream mode |
|----------|------------|------------------|-------------|
| **ExtendedXmlSerializer** | ExtendedXml of `{ TypeName, Json }` where `Json` is Newtonsoft of the domain object | `ToDomain` deserializes JSON | **Adapted** — UTF-8 `StreamWriter` of the XML string |
| **Migrant** | Migrant of the same JSON envelope POCO | `ToDomain` deserializes JSON | **Native Migrant stream** of the envelope; the bytes path is those same bytes |

Source: [`ExtendedXmlSerializerSer.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Serializers/ExtendedXmlSerializerSer.cs), [`MigrantSerializerSer.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Serializers/MigrantSerializerSer.cs).

**Compare fairly:** use **MS XmlSerializer** / **YAXLib** / **MS DataContract** for real XML-ish paths; use **Ceras**, **MemoryPack**, **NetSerializer**, etc. for binary domain graphs — not Migrant’s envelope row.

### Bytes mode and stream mode

CSV column `StringOrStream` is **`bytes`** or **`stream`**, the same labels as the other languages. Older logs in this tree say `string` and `Stream`. On those older rows, binary codecs timed Base64 of the payload.

| Path | Meaning |
|------|---------|
| **bytes** | `SerializeBytes` / `DeserializeBytes`. Binary codecs time the library byte payload. Text codecs time UTF-8 of the library text. |
| **stream** | `Serialize` / `Deserialize` with `Stream`. |

**Stream honesty**

| Kind | What is timed | Examples |
|------|----------------|----------|
| **Adapted stream** | Stream path writes or reads a finished buffer rather than a native streaming API | **arrow-ipc**, **parquet**, **parquet-uncompressed** (the IPC or Parquet buffer copied onto the harness stream), ShapeShift.Cbor / ShapeShift.Protobuf / ShapeShift.Taml / ShapeShift.Toml / ShapeShift.Yaml, **ExtendedXmlSerializer**, CsvHelper, fastJson, NetJSON, Ceras |
| **Native text stream** | Library writes/reads `Stream` directly with its text codec API | ShapeShift.Json |
| **Native binary stream** | Library writes/reads `Stream` with its binary API | ShapeShift.MsgPack, ProtoBuf, LightProto, Bond, BinaryPack, MemoryPack, NetSerializer, Hyperion, GroBuf, Google.Protobuf, Apache.Avro, DataContract*, FsPickler, ZeroFormatter, Migrant *(envelope only)*, … |
| **Text writer on stream** | Library writes to `TextWriter`/`JsonTextWriter` over the stream (real library streaming text API; not “serialize whole string then dump”) | Json.Net, YamlDotNet, SharpYaml, System.Text.Json (when bound to stream), … |

When stream and bytes are within a few percent, check which kind applies. Compare inside one mode. Older binary rows that say `string` include Base64, so that size is not the raw payload.

### Caveats

- Most codecs serialize domain types **directly** (attributes on V2 models: `[DataContract]`, `[ProtoContract]`, `[Schema]`, `[MemoryPackable]`, `[GenerateShape]`, …). Domain models live in [`c-sharp/src/TestData/V2/Models.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/TestData/V2/Models.cs).
- **Library-native prepare (still real domain or codegen forms):** Google.Protobuf (`IMessage`), ZeroFormatter (`KeyTuple` on net8), FlatSharp (tables via map), CsvHelper (row lists). These are **not** JSON envelopes.
- **Envelope exceptions:** ExtendedXmlSerializer and Migrant only — see above.
- **Apex.Serialization** removed (crashes on .NET 8 `FieldInfoModifier`); **FluentSerializer** removed (cannot encode nested graphs / long strings reliably). **System.Text.Json** included.
- SpanJson / Utf8Json cache closed generic delegates in `Initialize` (no per-call reflection).
- Benchmark runner no longer prints per-repetition DEBUG lines (measurement noise).
- Failures: `logs/csharp/<ts>.errors.csv` (per run).
- Rankings: use generated reports (`analyze-benchmarks`), not this list. Compare inside one [standard](../analysis/terminology.md#standard), and keep the same I/O mode.

Benchmark runner: [`c-sharp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/README.md). Format trade-offs: [Families](../analysis/families.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=csharp&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
