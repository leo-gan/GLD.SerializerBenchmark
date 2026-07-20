# Swift

Swift’s serialization stack mixes **Codable** codecs (Foundation JSON/plist, IkigaJSON, MessagePack, CBOR, BSON, YAML, XML) with **schema/IDL** stacks (SwiftProtobuf, FlatBuffers, Avro, Cap’n Proto).

## Benchmark harness

- Directory: `swift/`
- Output: `logs/swift/YYYY-MM-DD-HHMMSS.csv` (`Language=swift`, times in **nanoseconds**)
- Runner: `swift/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift`](../../swift/Sources/SerializerBenchmarkCore/Serializers/Registry.swift)

## Serializers (12)

| Serializer | Category | Package | Stream | Notes |
|------------|----------|---------|--------|-------|
| Foundation.JSONEncoder | JSON | Foundation | adapted | Compact |
| IkigaJSON | JSON | IkigaJSON | adapted | Server JSON |
| Foundation.PropertyListEncoder | Native | Foundation | adapted | Binary plist |
| SwiftMsgpack | Binary | swift-msgpack | adapted | Codable MessagePack |
| SwiftCbor | Binary | swift-cbor | adapted | Codable CBOR |
| SwiftBSON | Binary | swift-bson | adapted | Map-root wrap for N>1 |
| Yams | Text | Yams | adapted | YAML |
| XMLCoder | Text | XMLCoder | adapted | Root `payload` |
| SwiftProtobuf | Schema | apple/swift-protobuf | adapted | Generated from suite `.proto` |
| FlatBuffers | Schema | google/flatbuffers | adapted | Generated from suite `.fbs` |
| SwiftAvroCore | Schema | SwiftAvroCore | adapted | Binary Avro + schema |
| CapnProto | Schema | Cap’n Proto C++ | adapted | C ABI over official C++ runtime |

### Call-path contract

```text
prepare(fixture)                 # untimed: schema, native message / builder state
serialize_bytes / stream         # timed
deserialize_bytes / stream       # timed (+ domain conversion for schema codecs)
fidelity                         # untimed, float-tolerant
```

**Codable wrappers** never import suite types. **Schema bridges** convert domain ↔ native in prepare / after deserialize (same pattern as Go protobuf / Rust prost).

### Suite fixtures

Type ids: `message`, `document`, `telemetry`, `strings`, `event`.

### Caveats

- Stream mode is **adapted** for all registered codecs.
- Cap’n Proto has no maintained first-class Swift codegen; the harness uses the **official C++ library** via `CapnpBridge` (requires `libcapnp` / `libkj`, typically under `~/.local`).
- TOML still omitted (TOMLKit C++ header/GCC version skew on some Linux hosts).

Also: [`swift/README.md`](../../swift/README.md).
