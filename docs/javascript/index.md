# JavaScript

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Harness

- `javascript/` (repository root)
- Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
- Requires Node ≥ 18
- Registration: modular under [`javascript/src/serializers/`](../../javascript/src/serializers/) (`index.js` exports `ALL_SERIALIZERS`)
- `prepare()` compiles schemas / reuses encoder instances outside timed loops

## Serializers (12–13)

| Name | Category | Package | Optimal API |
|------|----------|---------|-------------|
| JSON.stringify | JSON | builtin | `JSON.stringify` / `JSON.parse` |
| fast-json-stringify | JSON | `fast-json-stringify` | compile once, then `stringify` + `JSON.parse` |
| simdjson | JSON | `simdjson` (optional native) | `parse` on UTF-8 string (+ stringify for ser) |
| msgpackr | Binary | `msgpackr` | reused `Packr` / `Unpackr` |
| @msgpack/msgpack | Binary | `@msgpack/msgpack` | `encode` / `decode` |
| cbor-x | Binary | `cbor-x` | reused `Encoder` / `Decoder` |
| cbor | Binary | `cbor` | `encode` / `decodeFirstSync` |
| bson | Binary | `bson` | `BSON.serialize` / `deserialize` |
| bser | Binary | `bser` | `dumpToBuffer` / `loadFromBuffer` |
| avsc | Schema | `avsc` | `Type.forSchema` in prepare; `toBuffer` / `fromBuffer` |
| protobufjs | Schema | `protobufjs` | preloaded `Type.encode` / `decode` (real fixture messages) |
| flatbuffers | Schema | `flatbuffers` | `Builder` + `ByteBuffer` (real FB wire) |
| v8-serializer | Native | `node:v8` | `v8.serialize` / `v8.deserialize` |

### Notes

- **simdjson** is optional; if the native addon fails to build, it is omitted (still ≥12 serializers).
- **protobufjs** uses **real per-fixture message types** (Person, Telemetry, EDI835, …), not a JSON-in-bytes wrapper.
- **avsc** uses **explicit Avro schemas** for all standard fixtures (including Integer / Telemetry / EDI_835).
- **flatbuffers** produces real FlatBuffers binary; the harness stores a UTF-8 JSON payload field and materializes owned JS objects on deserialize (same rehydrate model as non-zero-copy paths).
- **bson** / **bser** skip bare `Integer` (top-level document required).
- **v8-serializer** is not portable across languages/processes; included as the Node-native baseline (supports cycles / ObjectGraph if added later).
- C++-only libraries are out of scope here except optional native addons already registered (`simdjson`).

Also: [`javascript/README.md`](../../javascript/README.md). [Serialization Categories](../analysis/serialization_categories.md).
