---
title: "Swift"
---

Swift
=====

Swift’s serialization stack mixes **Codable** codecs (Foundation JSON/plist, IkigaJSON, MessagePack, CBOR, BSON, YAML, XML) with **schema/IDL** stacks (SwiftProtobuf, FlatBuffers, Avro, Cap’n Proto).

## Benchmark runner

- Directory: `swift/`
- Output: `logs/swift/YYYY-MM-DD-HHMMSS.csv` (`Language=swift`, times in **nanoseconds**)
- Runner: `swift/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift`](../../swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift)

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

Also: [`swift/README.md`](../../swift/README.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=swift&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
