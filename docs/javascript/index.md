# JavaScript

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Harness

- `javascript/` (repository root)
- Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
- Requires Node ≥ 18
- Registration: modular under [`javascript/src/serializers/`](../../javascript/src/serializers/)
- `prepare()` compiles schemas / reuses encoder instances outside timed loops
- Protobuf-ES codegen: `npm run generate:protobuf-es` (needs `protoc`)

## Serializers

| Name | Category | Package | Optimal API |
|------|----------|---------|-------------|
| JSON.stringify | JSON | builtin | `JSON.stringify` / `JSON.parse` |
| fast-json-stringify | JSON | `fast-json-stringify` | compile once + `JSON.parse` |
| simdjson-parse+JSON.stringify | JSON | `simdjson` (optional) | ser: `JSON.stringify`; deser: `simdjson.parse` |
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

- **simdjson-parse+JSON.stringify** (optional native addon; omitted from the run if not installed): only **deserialize** uses SIMD; serialize is stdlib `JSON.stringify` (honest leaderboard label).
- **protobuf-es** uses generated code from `javascript/schemas/js_fixtures.proto` (field shapes match JS fixtures; string timestamps).
- **flatbuffers:** Integer / SimpleObject use a **compact table** (no JSON blob) for fair small-object sizes; larger fixtures store a JSON payload string in a FlatBuffer table.
- **flexbuffers:** full fixture support. flatbuffers 24.x `toObject` bugs on large vectors / mixed float maps are worked around by encoding arrays as maps and non-integer floats as `{__f}` wrappers (still real FlexBuffers wire; restore is exact).
- **bebop** / **sia** encode a JSON data model via each library’s primitive writers (no separate IDL codegen in-tree for bebop; full Bebop would use `.bop` + `bebopc`).
- **bson** / **bser** skip bare `Integer`.
- **devalue** is a framework-oriented value codec (SvelteKit), not a portable wire standard.

Also: [`javascript/README.md`](../../javascript/README.md).
