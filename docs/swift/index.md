---
title: "Swift"
---

# Swift

Swift serialization pairs compiler-synthesized `Codable` encoders (`Foundation` JSON/plist, `IkigaJSON`, `SwiftMsgpack`, `SwiftCbor`, `SwiftBSON`, `Yams`, `XMLCoder`, `TOML`, `ToonFormat`, `BinaryCodable`) with IDL/schema codecs (`SwiftProtobuf`, `FlatBuffers`, `Cap'n Proto`, `Avro`, `Dagr`, `Apache Fory`, `gld-kiln`).

## Runtime & Environment

Swift compiles ahead of time to native machine code (`swift build -c release`) and manages heap objects through Automatic Reference Counting (ARC) rather than a tracing garbage collector; retain/release traffic on class instances and reference-backed buffers directly affects hot-loop throughput. On Linux, `Foundation` uses `swift-corelibs-foundation` rather than Apple's OS-bundled Foundation binary. Language semantics are specified in [The Swift Programming Language](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/) ([Language Reference](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/aboutthelanguagereference)).

| Property | Configuration |
|---|---|
| Language / spec | Swift 6.0+ (`// swift-tools-version: 6.0`; install script places Swift 6.3.3 under `~/.local/swift`) |
| Build & toolchain | Swift Package Manager (`swift build -c release`); C++ `libcapnp` / `libkj` under `~/.local` for Cap'n Proto |
| Memory model | Automatic Reference Counting (ARC); no tracing garbage collector |
| Runner & logs | `swift/scripts/run-benchmarks.sh` → `logs/swift/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift) |
| Data sets | `suite`, `graph`, `tensor` |

## Registered Serializers

`Codable` adapters operate on a type-erased suite value without importing domain model names, while IDL adapters bridge domain and native types outside the timed path unless noted.

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [BinaryCodable](https://github.com/christophhagen/BinaryCodable) | `custom` | `suite` | `adapted` | Pure-Swift binary `Codable` encoder/decoder |
| [CapnProto](https://github.com/capnproto/capnproto) | `capnp` | `suite` | `adapted` | Official C++ Cap'n Proto runtime via `CapnpBridge` C ABI |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Builds `<Graph>.Arena` + stores into reused `DataArenaBuilder`; lazy reader→domain |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct builder value structs → reused `DataArenaBuilder`; lazy reader→domain |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct builder value structs → reused `DataArenaBuilder`; lazy reader→domain |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Builds `<Graph>.Arena` + stores into reused `DataArenaBuilder`; lazy reader→domain |
| [FlatBuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite` | `adapted` | Official `google/flatbuffers` generated from suite `.fbs` |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | `apache/fory` `ForyStruct` macro on suite value types; registered untimed |
| [Foundation.JSONEncoder](https://github.com/apple/swift-foundation) | `json` | `suite` | `adapted` | Compact `Foundation` `JSONEncoder` / `JSONDecoder` (`swift-corelibs-foundation` on Linux) |
| [Foundation.PropertyListEncoder](https://github.com/apple/swift-foundation) | `plist` | `suite` | `adapted` | Binary property list (`PropertyListEncoder`) |
| [gld-avro](https://github.com/leo-gan/gld-avro-swift) | `avro` | `suite` | `adapted` | `leo-gan/gld-avro-swift` 0.2.0 `parseAvsc` once; `encodeGeneric` / `decodeGeneric` |
| [gld-ion](https://github.com/leo-gan/gld-ion-swift) | `ion` | `suite` | `adapted` | `leo-gan/gld-ion-swift` 0.2.0 Ion 1.0 binary `encode` / `decodeBinary` |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-swift) | `kiln` | `suite`, `tensor` | `adapted` | `leo-gan/gld-kiln-swift` 0.2.1 positional `Writer.encode` / `decode`; `tensor_view` borrows payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `tensor` | `adapted` | Pure x86-64 Assembly Kiln Wire Format v2 (`libkiln_asm_bench.a` via `KilnAsmC`); `tensor_view` borrows payload |
| [IkigaJSON](https://github.com/orlandos-nl/IkigaJSON) | `json` | `suite` | `adapted` | Server-oriented `Codable` JSON codec |
| [SwiftAvroCore](https://github.com/lynixliu/SwiftAvroCore) | `avro` | `suite` | `adapted` | Binary Avro with schema |
| [SwiftBSON](https://github.com/mongodb/swift-bson) | `bson` | `suite` | `adapted` | Official `swift-bson`; map-root wrap for $N > 1$ |
| [SwiftCbor](https://github.com/nnabeyang/swift-cbor) | `cbor` | `suite` | `adapted` | `Codable` CBOR encoder/decoder |
| [SwiftMsgpack](https://github.com/nnabeyang/swift-msgpack) | `msgpack` | `suite` | `adapted` | `Codable` MessagePack encoder/decoder |
| [SwiftProtobuf](https://github.com/apple/swift-protobuf) | `protobuf` | `suite` | `adapted` | Apple `swift-protobuf` generated from suite `.proto` |
| [TOML](https://github.com/mattt/swift-toml) | `toml` | `suite` | `adapted` | `mattt/swift-toml` (`toml++`); map-root wrap for $N > 1$ |
| [ToonFormat](https://github.com/toon-format/toon-swift) | `toon` | `suite` | `adapted` | Official `toon-swift` (spec 4.1) `TOONEncoder` / `TOONDecoder`; size in UTF-8 bytes |
| [XMLCoder](https://github.com/CoreOffice/XMLCoder) | `custom` | `suite` | `adapted` | `Codable` XML encoder/decoder (root `payload`) |
| [Yams](https://github.com/jpsim/Yams) | `yaml` | `suite` | `adapted` | Swift wrapper over `libyaml` |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[BinaryCodable](https://github.com/christophhagen/BinaryCodable)** — BinaryCodable is a pure-Swift binary Codable implementation. It was written so Swift types could have a simple binary encoding without an IDL — Swift-only, not a public standard.
    - **[CapnProto](https://github.com/capnproto/capnproto)** — Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.
    - **[FlatBuffers](https://github.com/google/flatbuffers)** — FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses ForyStruct macro-generated serializers on Swift value types.
    - **[Foundation.JSONEncoder](https://github.com/apple/swift-foundation)** — Foundation's JSONEncoder/JSONDecoder are Apple's standard Codable JSON codecs. They exist so Swift can speak JSON with the language's Codable model. On Linux this is swift-corelibs-foundation, not the Apple OS binary.
    - **[Foundation.PropertyListEncoder](https://github.com/apple/swift-foundation)** — Foundation PropertyListEncoder writes Apple property lists. plists exist so Apple platforms can store typed configuration. This row times the binary plist path.
    - **[gld-avro](https://github.com/leo-gan/gld-avro-swift)** — gld-avro-swift (leo-gan) is a pure-Swift Apache Avro binary codec that parses `.avsc` schemas in `prepare` and times `encodeGeneric` and `decodeGeneric`.
    - **[gld-ion](https://github.com/leo-gan/gld-ion-swift)** — gld-ion-swift (leo-gan) is a pure-Swift Amazon Ion 1.0 binary encoder and decoder timing `encode` and `decodeBinary`.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-swift)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) statically linked via `KilnAsmC` and shared `libkiln_asm_bench.a`. Covers `suite` and `tensor` (KLNT v2 with zero-copy `tensor_view`).
    - **[IkigaJSON](https://github.com/orlandos-nl/IkigaJSON)** — IkigaJSON is a server-oriented JSON encoder/decoder for Swift. The problem was Foundation JSON performance on Linux servers. IkigaJSON implements Codable with a faster core.
    - **[SwiftAvroCore](https://github.com/lynixliu/SwiftAvroCore)** — SwiftAvroCore implements Apache Avro for Swift. Avro exists for compact, schema-driven records. The library encodes binary Avro with a schema.
    - **[SwiftBSON](https://github.com/mongodb/swift-bson)** — swift-bson is MongoDB's official BSON library for Swift. BSON exists so MongoDB can store typed documents. This package implements that spec for Codable-style use.
    - **[SwiftCbor](https://github.com/nnabeyang/swift-cbor)** — swift-cbor is a Codable CBOR implementation for Swift. CBOR is the IETF binary JSON-like format. The library maps Codable types to RFC 8949.
    - **[SwiftMsgpack](https://github.com/nnabeyang/swift-msgpack)** — swift-msgpack is a Codable MessagePack implementation for Swift. MessagePack exists as compact binary JSON. This library is a straightforward Codable backend.
    - **[SwiftProtobuf](https://github.com/apple/swift-protobuf)** — swift-protobuf is Apple's official Protocol Buffers runtime for Swift. Protobuf exists as a language-neutral IDL and wire format. This package generates Swift from `.proto`.
    - **[TOML](https://github.com/mattt/swift-toml)** — mattt/swift-toml (toml++) is a TOML library for Swift. TOML exists as an obvious config language. This row times that implementation (map-root wrap for N>1).
    - **[ToonFormat](https://github.com/toon-format/toon-swift)** — ToonFormat is the official Swift codec. Release 0.5 targets TOON specification 4.1. The timed path is TOONEncoder and TOONDecoder on the suite Codable value. The Size column is the UTF-8 byte length.
    - **[XMLCoder](https://github.com/CoreOffice/XMLCoder)** — XMLCoder is a Codable XML encoder/decoder for Swift. The problem was that Swift had JSON Codable but not a first-class XML Codable. XMLCoder maps Codable types to XML elements.
    - **[Yams](https://github.com/jpsim/Yams)** — Yams is a Swift wrapper around libyaml. YAML exists as a human-friendly config language. Yams is the usual Swift YAML library.

## Measurement Caveats

- **Stream mode:** Stream rows are `StreamMode=adapted` across all registered Swift codecs (measuring buffer encode/decode plus stream copy).
- **C++ bridge for Cap'n Proto:** Because Swift lacks a maintained native Cap'n Proto code generator, `CapnProto` calls the official C++ runtime via `CapnpBridge` (requiring `libcapnp` / `libkj` under `~/.local`).
- **Dagr timed conversion & framing:** `dagr-packed` and `dagr-frozen-packed` construct direct value structs and write into a reused `DataArenaBuilder` inside timed serialize; `dagr-regular` and `dagr-frozen` build a per-item `<Graph>.Arena` and store each item as a self-contained record framed as `[u32 count][u32 len][record]` for $N > 1$. Decode materializes domain values via `lazyRoot(from:at:)`.
- **Root-array wrappers & Linux flags:** `SwiftBSON` and `TOML` wrap $N > 1$ batches in a root map/table. Linux builds of `mattt/swift-toml` require GCC 11 `libstdc++` include flags (configured automatically by `swift/scripts/run-benchmarks.sh`).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Swift)](../dashboard/index.html?lang=swift&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Swift)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Swift: `FlatBuffers` vs. `SwiftProtobuf`](../analysis/call-sites/swift-flatbuffers-vs-protobuf.md)
- **Build & run guide:** [`swift/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/swift/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
