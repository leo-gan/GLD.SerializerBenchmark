# JavaScript Tested Serializers

| Name | Category | Package | Optimal API |
|------|----------|---------|-------------|
| JSON.stringify | JSON baseline | builtin | `JSON.stringify` / `JSON.parse` |
| fast-json-stringify | JSON | `fast-json-stringify` | compile once, then `stringify` + `JSON.parse` |
| simdjson | JSON | `simdjson` (optional native) | `parse` on UTF-8 string |
| msgpackr | MessagePack | `msgpackr` | reused `Packr` / `Unpackr` |
| @msgpack/msgpack | MessagePack | `@msgpack/msgpack` | `encode` / `decode` |
| cbor-x | CBOR | `cbor-x` | reused `Encoder` / `Decoder` |
| cbor | CBOR | `cbor` | `encode` / `decodeFirstSync` |
| avsc | Avro | `avsc` | `Type.forValue` in prepare; `toBuffer` / `fromBuffer` |
| protobufjs | Protobuf | `protobufjs` | preloaded `Type.encode` / `decode` |
| bson | BSON | `bson` | `BSON.serialize` / `deserialize` |
| v8-serializer | Native | `node:v8` | `v8.serialize` / `v8.deserialize` |
| bser | Binary | `bser` | `dumpToBuffer` / `loadFromBuffer` |

## Notes

- **simdjson** is optional; if the native addon fails to build, it is omitted (still ≥10 serializers).
- **protobufjs** uses a real `Person`/`SimpleObject` schema; other types use a JSON-in-protobuf wrapper (documented limitation).
- **v8-serializer** is not portable across languages/processes; included as the Node-native baseline.
