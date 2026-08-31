---
title: "Swift"
---

Swift
=====

Swift’s serialization stack mixes **Codable** codecs (Foundation JSON/plist, IkigaJSON, MessagePack, CBOR, BSON, YAML, XML) with **schema/IDL** stacks (SwiftProtobuf, FlatBuffers, Avro, Cap’n Proto).

## Runtime

### What it is

Swift compiles to **native machine code**. Memory is managed with **ARC** (Automatic Reference Counting). An object is freed when the last reference to it goes away. That is not the same as the tracing garbage collector used by .NET or the JVM. Swift is not treated here as an Apple-only language. This runner is built and timed on **Linux** as well.

| | This suite |
|---|---|
| Tools | Swift **5.10 or newer** (`Package.swift`). The install script places Swift **6.x** under `~/.local/swift`. |
| Build | Swift Package Manager (`swift build -c release`) |
| Prepare | `./scripts/install-host-requirements.sh swift` |
| Run | `swift/scripts/run-benchmarks.sh` |
| Memory | Automatic reference counting, not a tracing garbage collector |

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

| Serializer | Category | Package | Stream | Notes |
|------------|----------|---------|--------|-------|
| BinaryCodable | Binary | BinaryCodable | adapted | Pure-Swift binary Codable |
| CapnProto | Schema | Cap’n Proto C++ | adapted | C ABI over official C++ runtime |
| FlatBuffers | Schema | google/flatbuffers | adapted | Generated from suite `.fbs` |
| Foundation.JSONEncoder | JSON | Foundation | adapted | Compact |
| Foundation.PropertyListEncoder | Native | Foundation | adapted | Binary plist |
| IkigaJSON | JSON | IkigaJSON | adapted | Server JSON |
| SwiftAvroCore | Schema | SwiftAvroCore | adapted | Binary Avro + schema |
| SwiftBSON | Binary | swift-bson | adapted | Map-root wrap for N>1 |
| SwiftCbor | Binary | swift-cbor | adapted | Codable CBOR |
| SwiftMsgpack | Binary | swift-msgpack | adapted | Codable MessagePack |
| SwiftProtobuf | Schema | apple/swift-protobuf | adapted | Generated from suite `.proto` |
| TOML | Text | mattt/swift-toml | adapted | Map-root wrap for N>1 |
| XMLCoder | Text | XMLCoder | adapted | Root `payload` |
| Yams | Text | Yams | adapted | YAML |

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
