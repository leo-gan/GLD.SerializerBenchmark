# JavaScript

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Benchmark runner

- `javascript/` (repository root)
- Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
- Requires Node ≥ 18
- Registration: modular under [`javascript/src/serializers/`](../../javascript/src/serializers/)
- `prepare()` compiles schemas / reuses encoder instances outside timed loops
- Protobuf codegen: `npm run generate:protobuf` (protobuf-es + google-protobuf; needs suite protoc sysroot for jspb stubs)

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
| google-protobuf | Schema | `google-protobuf` | official jspb `serializeBinary` / `deserializeBinary` |
| flatbuffers | Schema | `flatbuffers` | `Builder` / `ByteBuffer` |
| flexbuffers | Schema | `flatbuffers` (FlexBuffers) | `encode` / `toObject` |
| bebop | Schema | `bebop` | `BebopView` JSON-model primitives |
| v8-serializer | Native | `node:v8` | `v8.serialize` / `v8.deserialize` |
| devalue | Native | `devalue` | `stringify` / `parse` |

### Stream I/O

**Not measured.** The Node suite times the same buffer `serialize` / `deserialize` path for every codec; there is no distinct stream API loop. The benchmark runner emits **bytes only** so Results do not claim a second I/O mode. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).

### Notes

- **simdjson-parse+JSON.stringify** (optional native addon; omitted from the run if not installed): only **deserialize** uses SIMD; serialize is stdlib `JSON.stringify` (honest leaderboard label).
- **protobuf-es** / **google-protobuf** use generated code from `javascript/schemas/js_fixtures.proto` (field shapes match JS data types; string timestamps). Google stubs live under `src/generated/google/` (`npm run generate:google-protobuf`).
- Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.
- **flatbuffers / flexbuffers:** fixture support via tables / FlexBuffers; see the benchmark runner for float/array workarounds.
- **bebop** / **sia** encode a JSON-shaped model via each library’s primitive writers.
- **devalue** is a framework-oriented value codec (SvelteKit), not a portable wire standard.
- **prepare()** builds native messages and compiles schemas outside the timed path.

Also: [`javascript/README.md`](../../javascript/README.md).
