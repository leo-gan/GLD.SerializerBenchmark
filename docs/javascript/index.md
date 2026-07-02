# JavaScript

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Harness

- `javascript/` (repository root)
- Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
- Requires Node ≥ 18
- Registration: [`javascript/src/serializers/index.js`](../../javascript/src/serializers/index.js)
- `prepare()` compiles schemas / reuses encoder instances outside timed loops

## Serializers (11–12)

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

### Notes

- **simdjson** is optional; if the native addon fails to build, it is omitted (still ≥10 serializers).
- **protobufjs** uses a real `Person`/`SimpleObject` schema where applicable; other types may use a JSON-in-protobuf wrapper (documented limitation in code).
- **v8-serializer** is not portable across languages/processes; included as the Node-native baseline.

Also: [`javascript/README.md`](../../javascript/README.md). [Serialization Categories](../analysis/serialization_categories.md).
