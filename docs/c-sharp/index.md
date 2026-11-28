---
title: "C#"
---

# C#

Serialization in modern .NET spans legacy reflection frameworks, high-throughput `Span<T>`-based UTF-8 and binary codecs, and Roslyn source-generated serializers (`MemoryPack`, `LightProto`, `ShapeShift`, `Apache.Fory`) that eliminate runtime reflection and reduce heap allocation.

## Runtime & Environment

The C# runner targets `net10.0` on the .NET 10 Common Language Runtime (CLR), which JIT-compiles Intermediate Language (IL) to native code and manages memory with a generational tracing garbage collector. Because first-call JIT compilation inflates early repetitions and temporary buffer allocations add GC tail latency, analysis drops warmup repetition 0 and reports dispersion alongside medians (see [Latency tails and GC](../theory/301/latency-tails-and-gc.md)). The language and runtime are specified by [ECMA-334](https://ecma-international.org/publications-and-standards/standards/ecma-334/) ([C# specification](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/introduction)) and [ECMA-335](https://ecma-international.org/publications-and-standards/standards/ecma-335/).

| Property | Configuration |
|---|---|
| Language / spec | C# on .NET 10 (`net10.0`, ECMA-334 / ECMA-335) |
| Build & toolchain | .NET SDK 10+ (required by `ShapeShift` and `LightProto`'s Roslyn 4.14 source generator); Release configuration (`dotnet run -c Release`) |
| Memory model | Generational tracing garbage collector |
| Runner & logs | `c-sharp/scripts/run-benchmarks.sh` → `logs/csharp/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`c-sharp/src/Program.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/Program.cs) |
| Data sets | `suite`, `columnar`, `array`, `tensor` |

## Registered Serializers

Domain models in [`c-sharp/src/TestData/V2/Models.cs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/src/TestData/V2/Models.cs) carry format attributes (`[DataContract]`, `[ProtoContract]`, `[Schema]`, `[MemoryPackable]`, `[GenerateShape]`, `[ForyStruct]`) so codecs serialize domain POCOs directly unless a native IDL shape is required.

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [Amazon.IonDotnet](https://github.com/amazon-ion/ion-dotnet) | `ion` | `suite` | `native` | Ion binary reader/writer (`NuGet 1.3.2`, archived upstream); reflection with `forceFloat64` |
| [Apache.Avro](https://github.com/apache/avro) | `avro` | `suite`, `columnar` | `native` | Typed `ReflectWriter<T>` / `ReflectReader<T>` with reused encoder/decoder; schema cached in `Initialize` |
| [arrow-ipc](https://github.com/apache/arrow-dotnet) | `arrow` | `columnar` | `adapted` | Apache.Arrow 23.0.0 IPC stream (`net8.0` asset); row→column build timed; `table_project` reads `FFloat0` only |
| [BinaryPack](https://github.com/Sergio0694/BinaryPack) | `custom` | `suite` | `native` | Dynamic IL positional binary packing on POCOs (`T : new()`) |
| [Ceras](https://github.com/rikimaru0345/Ceras) | `custom` | `suite` | `adapted` | Binary graph serializer for .NET types |
| [Corvus.Toon](https://github.com/corvus-dotnet/Corvus.JsonSchema) | `toon` | `suite` | `adapted` | JSON↔TOON conversion via `System.Text.Json`; size in UTF-8 bytes |
| [CsvHelper](https://github.com/JoshClose/CsvHelper) | `custom` | `suite` | `adapted` | Tabular row-list projection (`message`, `event`, `strings` only) |
| [ExtendedXmlSerializer](https://github.com/wojtpl2/ExtendedXmlSerializer) | `custom` | `suite` | `adapted` | **JSON envelope** (`{TypeName, Json}`), not native domain XML (see caveats) |
| [fastJson](https://github.com/mgholam/fastJSON) | `json` | `suite` | `adapted` | Compact reflection JSON serializer |
| [FlatSharp](https://github.com/jamescourtney/FlatSharp) | `flatbuffers` | `suite`, `columnar` | `adapted` | Generated FlatSharp tables; domain map untimed in `PrepareData` |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | Apache Fory source-generated `[ForyStruct]` binary codec |
| [FsPickler](https://github.com/mbraceproject/FsPickler) | `custom` | `suite` | `native` | MBrace binary pickler for .NET object graphs |
| [FsPicklerJson](https://github.com/mbraceproject/FsPickler) | `json` | `suite` | `native` | MBrace JSON pickler |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-csharp) | `kiln` | `suite`, `tensor` | `adapted` | `Gld.Kiln` 0.2.1 positional little-endian codec; `tensor_view` borrows payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `array`, `tensor` | `adapted` | Pure x86-64 Assembly Kiln Wire Format v2 (`[LibraryImport]` + `[SuppressGCTransition]` into `libkiln_asm_bench.so`); `KILN_OPT_EMBEDDED` `table_project`, strided `grid_window`, zero-copy `tensor_view` |
| [Google.Protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite`, `columnar` | `native` | Official `Google.Protobuf` `IMessage` generated from `benchmark_v2.proto` |
| [GroBuf](https://github.com/skbkontur/GroBuf) | `custom` | `suite` | `native` | Compiled binary serializer for .NET types |
| [Hyperion](https://github.com/akkadotnet/Hyperion) | `custom` | `suite` | `native` | Akka.NET binary object-graph serializer |
| [Json.Net](https://github.com/JamesNK/Newtonsoft.Json) | `json` | `suite` | `text_on_stream` | `Newtonsoft.Json` standard path; `JsonTextWriter` on stream |
| [Json.Net (Helper)](https://github.com/JamesNK/Newtonsoft.Json) | `json` | `suite` | `text_on_stream` | `Newtonsoft.Json` helper call path |
| [LightProto](https://github.com/dameng324/LightProto) | `protobuf` | `suite` | `native` | Source-generated protobuf-net–style API (`[LightProto.ProtoContract]`, Roslyn 4.14+) |
| [MemoryPack](https://github.com/Cysharp/MemoryPack) | `custom` | `suite` | `native` | Source-generated zero-encoding-inspired binary codec (`[MemoryPackable]`) |
| [MessagePack-CSharp](https://github.com/MessagePack-CSharp/MessagePack-CSharp) | `msgpack` | `suite` | `native` | Official MessagePack-CSharp (`ContractlessStandardResolver` on POCOs) |
| [Migrant](https://github.com/antmicro/Migrant) | `custom` | `suite` | `native` | **JSON envelope** (`{TypeName, Json}`), not native Migrant graphs (see caveats) |
| [MS Binary](https://github.com/dotnet/runtime) | `custom` | `suite` | `native` | Legacy `BinaryFormatter` (obsolete/unsafe; historical baseline only) |
| [MS Bond Compact](https://github.com/microsoft/bond) | `bond` | `suite` | `native` | Microsoft Bond Compact Binary on `[Schema]` POCOs |
| [MS Bond Fast](https://github.com/microsoft/bond) | `bond` | `suite` | `native` | Microsoft Bond Fast Binary |
| [MS Bond Json](https://github.com/microsoft/bond) | `json` | `suite` | `native` | Microsoft Bond JSON protocol (primary standard `json`) |
| [MS DataContract](https://github.com/dotnet/runtime) | `custom` | `suite` | `native` | Framework `DataContractSerializer` (XML) |
| [MS DataContract Json](https://github.com/dotnet/runtime) | `json` | `suite` | `native` | Framework `DataContractJsonSerializer` |
| [MS XmlSerializer](https://github.com/dotnet/runtime) | `custom` | `suite` | `native` | Classic `XmlSerializer` on domain types |
| [Nerdbank.MessagePack](https://github.com/AArnott/Nerdbank.MessagePack) | `msgpack` | `suite` | `native` | Type-shape MessagePack with stable numeric keys and default-value retention |
| [NetJSON](https://github.com/rpgmaker/NetJSON) | `json` | `suite` | `adapted` | Lightweight .NET JSON serializer |
| [NetSerializer](https://github.com/tomba/netserializer) | `custom` | `suite` | `native` | Pre-registered compact binary serializer |
| [parquet](https://github.com/aloneguid/parquet-dotnet) | `parquet` | `columnar` | `adapted` | Parquet.Net 6.1.0 with library-default Snappy compression; `table_project` reads `FFloat0` only |
| [parquet-uncompressed](https://github.com/aloneguid/parquet-dotnet) | `parquet` | `columnar` | `adapted` | Same Parquet.Net writer with `CompressionMethod.None` |
| [ProtoBuf](https://github.com/protobuf-net/protobuf-net) | `protobuf` | `suite` | `native` | `protobuf-net` (`[ProtoContract]`) |
| [PureHDF](https://github.com/Apollo3zehn/PureHDF) | `hdf5` | `array` | `adapted` | Pure-managed .NET HDF5 writer/reader (no `libhdf5`); hyperslab read for `grid_window` |
| [ServiceStack](https://github.com/ServiceStack/ServiceStack.Text) | `custom` | `suite` | `adapted` | `ServiceStack.Text` JSV/type serializer (non-JSON) |
| [ServiceStack Json](https://github.com/ServiceStack/ServiceStack.Text) | `json` | `suite` | `adapted` | `ServiceStack.Text` JSON serializer |
| [ShapeShift.Cbor](https://github.com/AArnott/ShapeShift) | `cbor` | `suite` | `adapted` | Source-generated PolyType CBOR serializer |
| [ShapeShift.Json](https://github.com/AArnott/ShapeShift) | `json` | `suite` | `native` | Source-generated PolyType JSON serializer (`SerializeAsync` / `DeserializeAsync` on stream) |
| [ShapeShift.MsgPack](https://github.com/AArnott/ShapeShift) | `msgpack` | `suite` | `native` | Source-generated PolyType MessagePack serializer |
| [ShapeShift.Protobuf](https://github.com/AArnott/ShapeShift) | `custom` | `suite` | `adapted` | Source-generated PolyType protobuf-style serializer |
| [ShapeShift.Taml](https://github.com/AArnott/ShapeShift) | `custom` | `suite` | `adapted` | Source-generated PolyType TAML serializer (`strings` unsupported) |
| [ShapeShift.Toml](https://github.com/AArnott/ShapeShift) | `toml` | `suite` | `adapted` | Source-generated PolyType TOML serializer |
| [ShapeShift.Yaml](https://github.com/AArnott/ShapeShift) | `yaml` | `suite` | `adapted` | Source-generated PolyType YAML serializer |
| [SharpSerializer](https://github.com/polenter/SharpSerializer) | `custom` | `suite` | `native` | Binary/XML .NET serializer |
| [SharpYaml](https://github.com/xoofx/SharpYaml) | `yaml` | `suite` | `text_on_stream` | .NET YAML emitter/parser |
| [SpanJson](https://github.com/Tornhoof/SpanJson) | `json` | `suite` | `native` | `Span<T>` UTF-8 JSON; closed generic delegates cached in `Initialize` |
| [System.Text.Json](https://github.com/dotnet/runtime) | `json` | `suite`, `columnar` | `text_on_stream` | Built-in .NET 10 JSON serializer |
| [Toon.Format](https://github.com/toon-format/toon-dotnet) | `toon` | `suite` | `text_on_stream` | Official .NET TOON 4.4 codec (`EncodeToBytes` / `EncodeToStream`); size in UTF-8 bytes |
| [ToonNet](https://github.com/selcukgural/ToonNet) | `toon` | `suite` | `adapted` | `ToonNet.Core` typed `Serialize` / `Deserialize`; size in UTF-8 bytes |
| [Utf8Json](https://github.com/neuecc/Utf8Json) | `json` | `suite` | `native` | Direct UTF-8 JSON serializer; generic delegates cached in `Initialize` |
| [YamlDotNet](https://github.com/aaubry/YamlDotNet) | `yaml` | `suite` | `text_on_stream` | YAML 1.1/1.2 serializer (`TextWriter` on stream) |
| [YAXLib](https://github.com/sinairv/YAXLib) | `custom` | `suite` | `adapted` | Attribute-driven XML serializer |
| [ZeroFormatter](https://github.com/neuecc/ZeroFormatter) | `custom` | `suite` | `native` | Uses `KeyTuple` shapes (`PrepareData` untimed); dynamic `[ZeroFormattable]` IL fails on .NET 8+ |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[Amazon.IonDotnet](https://github.com/amazon-ion/ion-dotnet)** — Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. Amazon.IonDotnet is the Ion team .NET reader and writer. NuGet marks the package deprecated and the GitHub repository is archived; the Ion libraries page still lists it. This row pins NuGet 1.3.2 (the newest package there; it fixes CVE-2025-11573) and reflects over the suite types to write binary Ion.
    - **[Apache.Avro](https://github.com/apache/avro)** — Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.
    - **[arrow-ipc](https://github.com/apache/arrow-dotnet)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times Apache.Arrow 23.0.0 stream writer and reader on the bytes path, not the Arrow file format. Row-to-column conversion stays inside serialize. table_project reads the FFloat0 value buffer. NuGet 23.0.0 has no net10.0 asset; the net10.0 project consumes the net8.0 asset. No compliance decoder.
    - **[BinaryPack](https://github.com/Sergio0694/BinaryPack)** — BinaryPack is a compact binary serializer for .NET POCOs. It was written for fast, allocation-conscious binary packing of types that have a public parameterless constructor.
    - **[Ceras](https://github.com/rikimaru0345/Ceras)** — Ceras is a binary serializer for .NET object graphs. It was created as a modern, feature-rich alternative to BinaryFormatter-style packing without that formatter's security model.
    - **[Corvus.Toon](https://github.com/corvus-dotnet/Corvus.JsonSchema)** — Corvus.Toon.SystemTextJson converts JSON text and TOON text. The timed path includes that System.Text.Json pass. The Size column is the UTF-8 byte length.
    - **[CsvHelper](https://github.com/JoshClose/CsvHelper)** — CsvHelper was written so .NET could read and write CSV with a robust, mapping-based API. CSV exists as the simplest tabular exchange format. This row projects supported types to rows.
    - **[ExtendedXmlSerializer](https://github.com/wojtpl2/ExtendedXmlSerializer)** — ExtendedXmlSerializer is an XML serializer for .NET. In this suite the timed path is an envelope: ExtendedXml of `{TypeName, Json}`, not native domain XML. See the language inventory.
    - **[fastJson](https://github.com/mgholam/fastJSON)** — fastJSON (mgholam) is a small .NET JSON serializer. It was written to keep JSON simple and dependency-light. This row times that compact implementation.
    - **[FlatSharp](https://github.com/jamescourtney/FlatSharp)** — FlatSharp is a FlatBuffers implementation for .NET. FlatBuffers exists so readers can use serialized data without unpacking. FlatSharp generates C# from `.fbs` and times builder/parse on those tables.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses Apache.Fory source-generated serializers. The bytes path is the library payload, and the stream path is adapted.
    - **[FsPickler](https://github.com/mbraceproject/FsPickler)**, **[FsPicklerJson](https://github.com/mbraceproject/FsPickler)** — FsPickler is an F#/.NET pickler for fast binary (and JSON) serialization of .NET objects. It was created in the MBrace project so distributed F# could ship graphs efficiently.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-csharp)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) bound via .NET `[LibraryImport]` + `[SuppressGCTransition]` into shared `libkiln_asm_bench.so`. Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), `array` (KLNT v2 `grid` + strided `grid_window`), and `tensor` (KLNT v2 with zero-copy `tensor_view`).
    - **[Google.Protobuf](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[GroBuf](https://github.com/skbkontur/GroBuf)** — GroBuf is a binary serializer from SKB Kontur for high-throughput .NET services. The problem was slow built-in serializers. GroBuf generates a compact binary for .NET types.
    - **[Hyperion](https://github.com/akkadotnet/Hyperion)** — Hyperion is the binary serializer from the Akka.NET lineage (formerly Wire). It exists so an actor system can ship .NET messages efficiently. This row times that graph codec.
    - **[Json.Net](https://github.com/JamesNK/Newtonsoft.Json)**, **[Json.Net (Helper)](https://github.com/JamesNK/Newtonsoft.Json)** — Json.NET (Newtonsoft.Json) became the de-facto JSON library for .NET long before System.Text.Json. The problem was limited framework JSON. James Newton-King built a flexible, attribute-driven serializer that still defines much of the ecosystem.
        - `Json.Net (Helper)`: This row times a helper call path of the same Newtonsoft library.
    - **[LightProto](https://github.com/dameng324/LightProto)** — LightProto is a source-generated, protobuf-net-style serializer for modern .NET. The problem was reflection-based protobuf-net on AOT and hot paths. LightProto generates parsers at compile time from `[LightProto.ProtoContract]`.
    - **[MemoryPack](https://github.com/Cysharp/MemoryPack)** — MemoryPack was created by Yoshifumi Kawai for extremely fast, source-generated binary serialization on modern .NET. The problem was existing binary libraries allocating and reflecting too much. `[MemoryPackable]` types get generated encode/decode.
    - **[MessagePack-CSharp](https://github.com/MessagePack-CSharp/MessagePack-CSharp)** — MessagePack-CSharp is the official MessagePack implementation for .NET (neuecc / MessagePack-CSharp). MessagePack exists as compact binary JSON. This library is the standard .NET codec, including a contractless resolver.
    - **[Migrant](https://github.com/antmicro/Migrant)** — Migrant is Antmicro's .NET binary serializer for object graphs. In this suite the timed path is a JSON envelope, not native Migrant domain graphs. See the language inventory.
    - **[MS Binary](https://github.com/dotnet/runtime)** — BinaryFormatter is legacy .NET binary serialization. It exists so the early framework could persist object graphs. It is obsolete and unsafe for untrusted input; the suite keeps the row as a historical baseline.
    - **[MS Bond Compact](https://github.com/microsoft/bond)**, **[MS Bond Fast](https://github.com/microsoft/bond)**, **[MS Bond Json](https://github.com/microsoft/bond)** — Microsoft Bond was created for large-scale Microsoft services that needed a schema, several binary protocols, and codegen — in the same design space as Thrift/protobuf. Compact, Fast, and JSON protocols share one schema.
        - `MS Bond Compact`: This row times Bond Compact Binary.
        - `MS Bond Fast`: This row times Bond Fast Binary.
        - `MS Bond Json`: This row times the Bond JSON protocol.
    - **[MS DataContract](https://github.com/dotnet/runtime)**, **[MS DataContract Json](https://github.com/dotnet/runtime)** — DataContractSerializer and DataContractJsonSerializer are framework WCF-era serializers. They exist so .NET services could share an explicit data-contract model (XML or JSON) without XmlSerializer's older rules.
    - **[MS XmlSerializer](https://github.com/dotnet/runtime)** — XmlSerializer is classic .NET XML serialization. It exists so the framework could map objects to XML documents. This row is real domain XML when the attributes allow it.
    - **[Nerdbank.MessagePack](https://github.com/AArnott/Nerdbank.MessagePack)** — Nerdbank.MessagePack is a modern .NET MessagePack serializer built on type shapes. This row uses reflection-based POCO shapes with stable numeric keys and the library's default value retention.
    - **[NetJSON](https://github.com/rpgmaker/NetJSON)** — NetJSON is a small, fast JSON serializer for .NET. It was created as a lighter alternative to the large JSON frameworks. This row times its default encode/decode path.
    - **[NetSerializer](https://github.com/tomba/netserializer)** — NetSerializer is a compact, fast binary serializer for .NET. It was written to pack predefined types with very little overhead compared to BinaryFormatter.
    - **[parquet](https://github.com/aloneguid/parquet-dotnet)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times Parquet.Net 6.1.0 at the library default, Snappy. The timed call is the bytes path. table_project reads the FFloat0 data field. The package has an explicit net10.0 asset. No compliance decoder.
    - **[parquet-uncompressed](https://github.com/aloneguid/parquet-dotnet)** — This is the same Parquet.Net writer as parquet, with CompressionMethod.None. Encodings stay at the library default. The name is the override. No compliance decoder.
    - **[ProtoBuf](https://github.com/protobuf-net/protobuf-net)** — protobuf-net was created so .NET could speak Protocol Buffers without Google's generated C# being the only path. The problem was protobuf's IDL-first workflow for POCO-heavy .NET code. It attributes existing types (`[ProtoContract]`) and generates or interprets a protobuf-compatible encoding.
    - **[PureHDF](https://github.com/Apollo3zehn/PureHDF)** — PureHDF is a managed C# HDF5 reader and writer. It does not call libhdf5. This row times one float64 dataset named grid. grid_window reads a hyperslab selection. The bytes path returns the file bytes, so the size is the file length. The row does not time the five suite types.
    - **[ServiceStack](https://github.com/ServiceStack/ServiceStack.Text)**, **[ServiceStack Json](https://github.com/ServiceStack/ServiceStack.Text)** — ServiceStack.Text is the serializer stack behind ServiceStack. It was created so that framework had a fast, built-in JSON (and JSV) codec. This suite times the JSON path and the non-JSON type serializer as separate rows.
        - `ServiceStack`: This row times the non-JSON ServiceStack type serializer.
        - `ServiceStack Json`: This row times ServiceStack.Text JSON.
    - **[ShapeShift.Cbor](https://github.com/AArnott/ShapeShift)**, **[ShapeShift.Json](https://github.com/AArnott/ShapeShift)**, **[ShapeShift.MsgPack](https://github.com/AArnott/ShapeShift)**, **[ShapeShift.Protobuf](https://github.com/AArnott/ShapeShift)**, **[ShapeShift.Taml](https://github.com/AArnott/ShapeShift)**, **[ShapeShift.Toml](https://github.com/AArnott/ShapeShift)**, **[ShapeShift.Yaml](https://github.com/AArnott/ShapeShift)** — ShapeShift is a source-generated serialization framework built on PolyType contracts. It solves the reflection and trimming limitations of conventional serializers by generating strongly typed conversion logic for each model at compile time.
        - `ShapeShift.Cbor`: String mode Base64-encodes the CBOR bytes. The package has no stream API, so the stream row adapts its byte-array API.
        - `ShapeShift.Json`: String mode uses the serializer's string API. The stream row uses `SerializeAsync(Stream, ...)` and `DeserializeAsync(Stream)`.
        - `ShapeShift.MsgPack`: String mode Base64-encodes MessagePack bytes. The stream row uses `SerializeAsync(Stream, ...)` and `DeserializeAsync(Stream)`.
        - `ShapeShift.Protobuf`: String mode Base64-encodes bytes. The package has no stream API, so the stream row adapts its byte-array API.
        - `ShapeShift.Taml`: The package has no streaming text API, so the stream row adapts its complete string output. The `strings` data type is unsupported because its N=100 batch cannot be deserialized.
        - `ShapeShift.Toml`: The package has no streaming text API, so the stream row adapts its complete string output.
        - `ShapeShift.Yaml`: The package has no streaming text API, so the stream row adapts its complete string output.
    - **[SharpSerializer](https://github.com/polenter/SharpSerializer)** — SharpSerializer is a .NET serializer that can write binary or XML. It was created as a simple, portable alternative to framework serializers for app persistence.
    - **[SharpYaml](https://github.com/xoofx/SharpYaml)** — SharpYaml is a YAML parser/emitter for .NET (a port/evolution of YamlDotNet lineage ideas). It exists as another maintained YAML stack for C#.
    - **[SpanJson](https://github.com/Tornhoof/SpanJson)** — SpanJson was created to serialize JSON on .NET using `Span<T>` and modern memory primitives. The problem was older JSON libraries allocating too many strings. It writes UTF-8 directly from spans.
    - **[System.Text.Json](https://github.com/dotnet/runtime)** — System.Text.Json is the built-in JSON serializer for modern .NET. It was created so the platform had a fast, AOT-friendly JSON stack without Newtonsoft. It solves that with a serializer in the runtime and source-generation options.
    - **[Toon.Format](https://github.com/toon-format/toon-dotnet)** — Toon.Format is the official .NET codec for TOON specification 4.4. EncodeToBytes and Decode of a type are bound once. EncodeToStream and Decode from a stream are the library text stream API. The Size column is the UTF-8 byte length.
    - **[ToonNet](https://github.com/selcukgural/ToonNet)** — ToonNet.Core serializes a .NET type to TOON text. Serialize and Deserialize of that type are bound once. The stream path writes the UTF-8 buffer. The Size column is the byte length.
    - **[Utf8Json](https://github.com/neuecc/Utf8Json)** — Utf8Json was written by Yoshifumi Kawai (neuecc) as a fast UTF-8 JSON serializer for C#. The problem was string-heavy JSON APIs. It encodes directly to UTF-8 bytes.
    - **[YamlDotNet](https://github.com/aaubry/YamlDotNet)** — YamlDotNet is the usual YAML library for .NET. YAML exists as a human-friendly config language. YamlDotNet implements YAML 1.1/1.2 serialize/deserialize.
    - **[YAXLib](https://github.com/sinairv/YAXLib)** — YAXLib is a flexible XML serializer for .NET. The problem was XmlSerializer and DataContract being rigid about XML shape. YAXLib lets you control the XML more directly on domain types.
    - **[ZeroFormatter](https://github.com/neuecc/ZeroFormatter)** — ZeroFormatter was created (neuecc) as a fast, zero-encoding-style binary serializer for .NET, inspired by FlatBuffers/Cap'n Proto ideas. Dynamic IL is broken on .NET 8; this suite uses KeyTuple shapes.

## Measurement Caveats

- **Envelope codecs (not native domain wire):** `ExtendedXmlSerializer` and `Migrant` serialize a `{TypeName, Json}` envelope (wrapping a `Newtonsoft.Json` string) and restore domain objects via JSON inside untimed `ToDomain`. Do not interpret them as native XML or Migrant object-graph benchmarks; use `MS XmlSerializer`, `YAXLib`, `MS DataContract`, `Ceras`, or `MemoryPack` for direct domain wire paths.
- **Bytes vs. legacy `string` labels:** Current logs emit `bytes` (`SerializeBytes` / `DeserializeBytes` returning raw library bytes or UTF-8 text) and `stream`. Older C# logs labeled in-memory rows `string` and Base64-encoded binary payloads (expanding size by ~4/3); see [I/O & run modes](../analysis/modes.md).
- **Columnar rules and exclusions:** `arrow-ipc`, `parquet`, and `parquet-uncompressed` support only `table`, `table_project`, `nested_table`, and `signal`; row-to-column conversion stays inside timed `SerializeBytes`, and stream mode is adapted. Columnar runs require an explicit comma-separated allow-list (`FlatSharp,Google.Protobuf,Apache.Avro,System.Text.Json,arrow-ipc,parquet,parquet-uncompressed`). `sbe` is omitted because no NuGet package supplies `Org.SbeTool.Sbe.Dll` 1.40.2.
- **Excluded libraries:** `Apex.Serialization` (crashes on .NET 8+ `FieldInfoModifier`), `FluentSerializer` (fails nested graphs/long strings), `Wire`, `ORC`, and `ParquetSharp` are not registered.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (C#)](../dashboard/index.html?lang=csharp&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (C#)](../dashboard/index.html#compliance)
- **Source-level analyses:** [C#: `BinaryPack` vs. `MS Bond Fast`](../analysis/call-sites/csharp-binarypack-vs-bond.md)
- **Build & run guide:** [`c-sharp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c-sharp/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
