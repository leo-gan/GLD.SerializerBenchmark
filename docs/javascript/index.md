# JavaScript

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Harness

- `javascript/` (repository root)
- Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
- Requires Node ≥ 18
- Registration: modular under [`javascript/src/serializers/`](../../javascript/src/serializers/)
- `prepare()` compiles schemas / reuses encoder instances outside timed loops
- Protobuf-ES codegen: `npm run generate:protobuf-es` (needs `protoc`)

## Serializers (18–19)

| Name | Category | Package | Optimal API |
|------|----------|---------|-------------|
| JSON.stringify | JSON | builtin | `JSON.stringify` / `JSON.parse` |
| fast-json-stringify | JSON | `fast-json-stringify` | compile once + `JSON.parse` |
| simdjson | JSON | `simdjson` (optional) | `parse` (+ stringify for ser) |
| msgpackr | Binary | `msgpackr` | reused `Packr` / `Unpackr` |
| @msgpack/msgpack | Binary | `@msgpack/msgpack` | `encode` / `decode` |
| json-pack-msgpack | Binary | `@jsonjoy.com/json-pack` | `MsgPackEncoder` / `MsgPackDecoder` |
| cbor-x | Binary | `cbor-x` | reused `Encoder` / `Decoder` |
| cbor | Binary | `cbor` | `encode` / `decodeFirstSync` |
| bson | Binary | `bson` | `BSON.serialize` / `deserialize` |
| bser | Binary | `bser` | `dumpToBuffer` / `loadFromBuffer` |
| sia | Binary | `@timeleap/sia` | typed-tag JSON-model over Sia primitives |
| avsc | Schema | `avsc` | `Type.forSchema` + `toBuffer` / `fromBuffer` |
| protobufjs | Schema | `protobufjs` | real fixture `Type.encode` / `decode` |
| protobuf-es | Schema | `@bufbuild/protobuf` | `create` + `toBinary` / `fromBinary` |
| flatbuffers | Schema | `flatbuffers` | `Builder` / `ByteBuffer` |
| flexbuffers | Schema | `flatbuffers` (FlexBuffers) | `encode` / `toObject` |
| bebop | Schema | `bebop` | `BebopView` JSON-model primitives |
| v8-serializer | Native | `node:v8` | `v8.serialize` / `v8.deserialize` |
| devalue | Native | `devalue` | `stringify` / `parse` |

### Notes

- **simdjson** optional native addon.
- **protobuf-es** uses generated code from `javascript/schemas/js_fixtures.proto` (field shapes match JS fixtures; string timestamps).
- **flexbuffers** skips Telemetry / EDI_835 / StringArray: upstream `toObject()` throws on those shapes in flatbuffers 24.x.
- **bebop** / **sia** encode a JSON data model via each library’s primitive writers (no separate IDL codegen in-tree for bebop; full Bebop would use `.bop` + `bebopc`).
- **bson** / **bser** skip bare `Integer`.
- **devalue** is a framework-oriented value codec (SvelteKit), not a portable wire standard.

Also: [`javascript/README.md`](../../javascript/README.md).
