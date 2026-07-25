# Swift Serializer Benchmark

Native Swift benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`).

## Design: type-agnostic wrappers (Codable) + schema bridges

- **Codable wrappers** under `Serializers/` only see the type-erased `Fixture` API.
- **Schema codecs** (Protobuf, FlatBuffers, Avro, Cap’n Proto) use a domain↔native bridge in prepare / post-decode (same idea as Go protobuf / Rust prost). Conversion is not the “optimal hot path”; timed work is the library encode/decode.

## Serializers (14)

| Name | Category | Package | Notes |
|------|----------|---------|-------|
| Foundation.JSONEncoder | JSON | Foundation | Compact Codable |
| IkigaJSON | JSON | IkigaJSON | Server-side JSON |
| Foundation.PropertyListEncoder | Native | Foundation | Binary plist |
| **BinaryCodable** | Binary | christophhagen/BinaryCodable | Pure-Swift binary Codable |
| SwiftMsgpack | Binary | swift-msgpack | MessagePack |
| SwiftCbor | Binary | swift-cbor | CBOR |
| SwiftBSON | Binary | swift-bson | BSON document root wrap for N>1 |
| Yams | Text | Yams | YAML |
| XMLCoder | Text | XMLCoder | Root key `payload` |
| **TOML** | Text | mattt/swift-toml | Table root; ItemsWrap for N>1 |
| **SwiftProtobuf** | Schema | apple/swift-protobuf | Generated from `schemas/v2/protobuf/` |
| **FlatBuffers** | Schema | google/flatbuffers | Generated from `swift/schemas/benchmark.fbs` |
| **SwiftAvroCore** | Schema | lynixliu/SwiftAvroCore | Schemaless binary + JSON schema |
| **CapnProto** | Schema | Cap’n Proto C++ | C ABI bridge (`CapnpBridge`) |

## Host tools (schema)

```bash
./scripts/install-host-requirements.sh swift
# also needs for schema regen:
#   protoc + protoc-gen-swift
#   flatc
#   capnp (and libcapnp in ~/.local for CapnpBridge)
```

Regenerate:

```bash
./swift/scripts/generate-schemas.sh
```

## Run

```bash
./swift/scripts/run-benchmarks.sh smoke
./swift/scripts/run-benchmarks.sh all-single
```

