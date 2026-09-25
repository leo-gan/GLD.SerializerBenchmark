---
title: "Swift"
---

# Swift

Swift’s serialization stack mixes **Codable** codecs (Foundation JSON/plist, IkigaJSON, MessagePack, CBOR, BSON, YAML, XML) with **schema/IDL** stacks (SwiftProtobuf, FlatBuffers, Avro, Cap’n Proto).

## Runtime

### What it is

Swift compiles to **native machine code**. Memory is managed with **ARC** (Automatic Reference Counting). An object is freed when the last reference to it goes away. That is not the same as the tracing garbage collector used by .NET or the JVM. Swift is not treated here as an Apple-only language. This runner is built and timed on **Linux** as well.

|         | This suite                                                                                                |
| ------- | --------------------------------------------------------------------------------------------------------- |
| Tools   | Swift **6.0 or newer** (`Package.swift`). The install script places Swift **6.x** under `~/.local/swift`. |
| Build   | Swift Package Manager (`swift build -c release`)                                                          |
| Prepare | `./scripts/install-host-requirements.sh swift`                                                            |
| Run     | `swift/scripts/run-benchmarks.sh`                                                                         |
| Memory  | Automatic reference counting, not a tracing garbage collector                                             |

### What this suite runs

The runner is built in the **release** configuration, which turns on optimizations. Codable wrappers never import the suite types. They see a type-erased `Fixture` value instead. Schema codecs (Protobuf, FlatBuffers, Avro, Cap’n Proto) convert between the suite objects and each library’s native type **outside** the timer.

### What changes the numbers

ARC still has a cost: every extra retain and release is work. Foundation JSON on Linux is not the same binary as Foundation JSON on Apple platforms. **Cap’n Proto** in this suite is the official **C++** library, reached through `CapnpBridge` and `libcapnp` / `libkj` under `~/.local`. It is not a pure-Swift runtime.

### Suite-specific gotchas

Stream mode is **adapted** for every registered codec. The timed path is still bytes, then a write or read of those bytes.

Linux TOML builds may need GCC 11 `libstdc++` include flags. The run script already sets those flags.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`swift/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/swift/README.md). The language overview is [About Swift](https://www.swift.org/about/).

## Benchmark runner

- Directory: `swift/`
- Output: `logs/swift/YYYY-MM-DD-HHMMSS.csv` (`Language=swift`, times in **nanoseconds**)
- Runner: `swift/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift)

## Serializers

| Serializer                                                                  | Category | Package              | Stream  | Notes                                         |
| --------------------------------------------------------------------------- | -------- | -------------------- | ------- | --------------------------------------------- |
| [BinaryCodable](https://github.com/christophhagen/BinaryCodable)            | Binary   | BinaryCodable        | adapted | Pure-Swift binary Codable                     |
| [CapnProto](https://github.com/capnproto/capnproto)                         | Schema   | Cap’n Proto C++      | adapted | C ABI over official C++ runtime               |
| [FlatBuffers](https://github.com/google/flatbuffers)                        | Schema   | google/flatbuffers   | adapted | Generated from suite `.fbs`                   |
| [fory](https://github.com/apache/fory)                                      | Binary   | apache/fory          | adapted | Generated serializers on native Swift structs |
| [Foundation.JSONEncoder](https://github.com/apple/swift-foundation)         | JSON     | Foundation           | adapted | Compact                                       |
| [Foundation.PropertyListEncoder](https://github.com/apple/swift-foundation) | Native   | Foundation           | adapted | Binary plist                                  |
| [IkigaJSON](https://github.com/orlandos-nl/IkigaJSON)                       | JSON     | IkigaJSON            | adapted | Server JSON                                   |
| [SwiftAvroCore](https://github.com/lynixliu/SwiftAvroCore)                  | Schema   | SwiftAvroCore        | adapted | Binary Avro + schema                          |
| [SwiftBSON](https://github.com/mongodb/swift-bson)                          | Binary   | swift-bson           | adapted | Map-root wrap for N>1                         |
| [SwiftCbor](https://github.com/nnabeyang/swift-cbor)                        | Binary   | swift-cbor           | adapted | Codable CBOR                                  |
| [SwiftMsgpack](https://github.com/nnabeyang/swift-msgpack)                  | Binary   | swift-msgpack        | adapted | Codable MessagePack                           |
| [SwiftProtobuf](https://github.com/apple/swift-protobuf)                    | Schema   | apple/swift-protobuf | adapted | Generated from suite `.proto`                 |
| [TOML](https://github.com/mattt/swift-toml)                                 | Text     | mattt/swift-toml     | adapted | Map-root wrap for N>1                         |
| [XMLCoder](https://github.com/CoreOffice/XMLCoder)                          | Text     | XMLCoder             | adapted | Root `payload`                                |
| [Yams](https://github.com/jpsim/Yams)                                       | Text     | Yams                 | adapted | YAML                                          |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [BinaryCodable](https://github.com/christophhagen/BinaryCodable) · `4.0.0`

BinaryCodable is a pure-Swift binary Codable implementation. It was written so Swift types could have a simple binary encoding without an IDL — Swift-only, not a public standard.

#### [CapnProto](https://github.com/capnproto/capnproto) · `capnproto-1.0.2`

Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.

#### [FlatBuffers](https://github.com/google/flatbuffers) · `24.3.25`

FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.

#### [fory](https://github.com/apache/fory)

Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses ForyStruct macro-generated serializers on Swift value types.

#### [Foundation.JSONEncoder](https://github.com/apple/swift-foundation) · `Foundation`

Foundation's JSONEncoder/JSONDecoder are Apple's standard Codable JSON codecs. They exist so Swift can speak JSON with the language's Codable model. On Linux this is swift-corelibs-foundation, not the Apple OS binary.

#### [Foundation.PropertyListEncoder](https://github.com/apple/swift-foundation) · `Foundation`

Foundation PropertyListEncoder writes Apple property lists. plists exist so Apple platforms can store typed configuration. This row times the binary plist path.

#### [IkigaJSON](https://github.com/orlandos-nl/IkigaJSON) · `2.5.4`

IkigaJSON is a server-oriented JSON encoder/decoder for Swift. The problem was Foundation JSON performance on Linux servers. IkigaJSON implements Codable with a faster core.

#### [SwiftAvroCore](https://github.com/lynixliu/SwiftAvroCore) · `2.3.0`

SwiftAvroCore implements Apache Avro for Swift. Avro exists for compact, schema-driven records. The library encodes binary Avro with a schema.

#### [SwiftBSON](https://github.com/mongodb/swift-bson) · `3.1.0`

swift-bson is MongoDB's official BSON library for Swift. BSON exists so MongoDB can store typed documents. This package implements that spec for Codable-style use.

#### [SwiftCbor](https://github.com/nnabeyang/swift-cbor) · `0.0.4`

swift-cbor is a Codable CBOR implementation for Swift. CBOR is the IETF binary JSON-like format. The library maps Codable types to RFC 8949.

#### [SwiftMsgpack](https://github.com/nnabeyang/swift-msgpack) · `1.2.1`

swift-msgpack is a Codable MessagePack implementation for Swift. MessagePack exists as compact binary JSON. This library is a straightforward Codable backend.

#### [SwiftProtobuf](https://github.com/apple/swift-protobuf) · `1.38.1`

swift-protobuf is Apple's official Protocol Buffers runtime for Swift. Protobuf exists as a language-neutral IDL and wire format. This package generates Swift from `.proto`.

#### [TOML](https://github.com/mattt/swift-toml) · `2.0.0`

mattt/swift-toml (toml++) is a TOML library for Swift. TOML exists as an obvious config language. This row times that implementation (map-root wrap for N>1).

#### [XMLCoder](https://github.com/CoreOffice/XMLCoder) · `0.18.2`

XMLCoder is a Codable XML encoder/decoder for Swift. The problem was that Swift had JSON Codable but not a first-class XML Codable. XMLCoder maps Codable types to XML elements.

#### [Yams](https://github.com/jpsim/Yams) · `5.4.0`

Yams is a Swift wrapper around libyaml. YAML exists as a human-friendly config language. Yams is the usual Swift YAML library.

### Call-path contract

```text
prepare(fixture)                 # untimed: schema, native message / builder state
serialize_bytes / stream         # timed
deserialize_bytes / stream       # timed (+ domain conversion for schema codecs)
fidelity                         # untimed, float-tolerant
```

**Codable wrappers** never import suite types. **Schema bridges** convert domain ↔ native in prepare / after deserialize (same pattern as Go protobuf / Rust prost).

### Caveats

- Stream mode is **adapted** for all registered codecs.
- Cap’n Proto has no maintained first-class Swift codegen; the benchmark runner uses the **official C++ library** via `CapnpBridge` (requires `libcapnp` / `libkj`, typically under `~/.local`).
- TOML uses mattt/swift-toml (toml++); Linux builds may need GCC 11 `libstdc++` include flags (set in `run-benchmarks.sh`).

Also: [`swift/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/swift/README.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=swift&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
