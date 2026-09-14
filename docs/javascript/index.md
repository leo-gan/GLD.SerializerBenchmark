---
title: "JavaScript"
---

JavaScript
==========

Node benchmarks run on V8 with `performance.now()` converted to nanoseconds.

## Runtime

### What it is

This suite measures **Node.js**, not JavaScript running in a web browser. Node.js is a command-line host that embeds the **V8** JavaScript engine, which is the same engine Chrome uses. V8 **JIT**-compiles (just-in-time compiles) hot functions into native code and reclaims unused objects with a garbage collector. Node also provides `Buffer`, `require`/`import`, and native addons written in C++.

| | This suite |
|---|---|
| Host | **Node.js 18 or newer** and npm |
| Engine | V8 inside Node.js, not a browser |
| Prepare | Install Node with your package manager, then run `npm install` in `javascript/` |
| Run | `javascript/scripts/run-benchmarks.sh` |
| Memory | V8 garbage collector |

### What this suite runs

`package.json` requires Node 18 or newer. Timing uses `performance.now()` and converts the result to nanoseconds. There is **no stream mode**. Every codec is timed on in-memory buffers only.

### What changes the numbers

V8 compiles hot functions after they have run a few times, so early repetitions can be slower than later ones. Libraries that reuse an `Encoder` or `Packr` instance, such as `cbor-x` and `msgpackr`, avoid setup work on every call. `v8-serialize` is a Node-only format. It is not JSON and it is not portable to other languages. Optional native addons such as `simdjson` are left out of a run when they are not installed.

Calling `JSON.stringify` in a browser on the same payload is a different environment from this Node runner.

### Suite-specific gotchas

**devalue** is a framework value codec used by tools such as SvelteKit. It is not a portable wire format.

The row named **simdjson-parse+JSON.stringify** uses SIMD only for parse. Serialize is still the standard `JSON.stringify`.

These times cannot be ranked against another language, or against a browser.

### Where to go next

The steps to install Node and run the benchmark are in [`javascript/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/javascript/README.md). The platform overview is [Introduction to Node.js](https://nodejs.org/en/learn/getting-started/introduction-to-nodejs).

## Benchmark runner

- `javascript/` (repository root)
- Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
- Registration: modular under [`javascript/src/serializers/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/javascript/src/serializers)
- `prepare()` compiles schemas / reuses encoder instances outside timed loops
- Protobuf codegen: `npm run generate:protobuf` (protobuf-es + google-protobuf; needs suite protoc sysroot for jspb stubs)

## Serializers

| Name | Category | Package | Optimal API |
|------|----------|---------|-------------|
| [@msgpack/msgpack](https://github.com/msgpack/msgpack-javascript) | Binary | `@msgpack/msgpack` | `encode` / `decode` |
| [avsc](https://github.com/mtth/avsc) | Schema | `avsc` | `Type.forSchema` + `toBuffer` / `fromBuffer` |
| [bebop](https://github.com/6over3/bebop) | Schema | `bebop` | `BebopView` JSON-model primitives |
| [bser](https://github.com/facebook/watchman) | Binary | `bser` | `dumpToBuffer` / `loadFromBuffer` |
| [bson](https://github.com/mongodb/js-bson) | Binary | `bson` | `BSON.serialize` / `deserialize` |
| [cbor](https://github.com/hildjj/node-cbor) | Binary | `cbor` | `encode` / `decodeFirstSync` |
| [cbor-x](https://github.com/kriszyp/cbor-x) | Binary | `cbor-x` | reused `Encoder` / `Decoder` |
| [devalue](https://github.com/Rich-Harris/devalue) | Native | `devalue` | `stringify` / `parse` |
| [fast-json-stringify](https://github.com/fastify/fast-json-stringify) | JSON | `fast-json-stringify` | compile once + `JSON.parse` |
| [flatbuffers](https://github.com/google/flatbuffers) | Schema | `flatbuffers` | `Builder` / `ByteBuffer` |
| [flexbuffers](https://github.com/google/flatbuffers) | Schema | `flatbuffers` (FlexBuffers) | `encode` / `toObject` |
| [google-protobuf](https://github.com/protocolbuffers/protobuf-javascript) | Schema | `google-protobuf` | official jspb `serializeBinary` / `deserializeBinary` |
| [json-pack-msgpack](https://github.com/jsonjoy-com/json-pack) | Binary | `@jsonjoy.com/json-pack` | `MsgPackEncoder` / `MsgPackDecoder` |
| [JSON.stringify](https://github.com/nodejs/node) | JSON | builtin | `JSON.stringify` / `JSON.parse` |
| [msgpackr](https://github.com/kriszyp/msgpackr) | Binary | `msgpackr` | reused `Packr` / `Unpackr` |
| [protobuf-es](https://github.com/bufbuild/protobuf-es) | Schema | `@bufbuild/protobuf` | `create` + `toBinary` / `fromBinary` |
| [protobufjs](https://github.com/protobufjs/protobuf.js) | Schema | `protobufjs` | real fixture `Type.encode` / `decode` |
| [sia](https://github.com/TimeleapLabs/sia) | Binary | `@timeleap/sia` | typed-tag JSON-model over Sia primitives |
| [simdjson-parse+JSON.stringify](https://github.com/simdjson/simdjson) | JSON | `simdjson` (optional) | ser: `JSON.stringify`; deser: `simdjson.parse` |
| [v8-serializer](https://github.com/nodejs/node) | Native | `node:v8` | `v8.serialize` / `v8.deserialize` |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [@msgpack/msgpack](https://github.com/msgpack/msgpack-javascript) · `3.1.3`

The official MessagePack JavaScript implementation (`@msgpack/msgpack`). MessagePack was created as compact binary JSON. This package is the reference encode/decode API for JS.

#### [avsc](https://github.com/mtth/avsc) · `5.7.9`

avsc brings Apache Avro to JavaScript. Avro was created for compact, schema-driven records in data pipelines. avsc solves the JS side with `Type.forSchema` and buffer encode/decode.

#### [bebop](https://github.com/6over3/bebop) · `3.2.3`

Bebop is a schema-driven binary format created as a simpler, faster alternative to protobuf-like IDL stacks for games and services. The problem was heavy generated code and slow encoders. Bebop solves it with a compact schema and generated writers.

#### [bser](https://github.com/facebook/watchman) · `2.1.1`

BSER is Facebook Watchman's binary protocol: a compact encoding for the watchman's client/server messages. The problem was JSON overhead in a local file-watching daemon. This row times the Node `bser` dump/load path.

#### [bson](https://github.com/mongodb/js-bson) · `6.10.4`

BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.

#### [cbor](https://github.com/hildjj/node-cbor) · `9.0.2`

node-cbor implements IETF CBOR (RFC 8949) for Node. CBOR exists as the IETF's binary JSON-like format. The library is a full encode/decode implementation of that RFC.

#### [cbor-x](https://github.com/kriszyp/cbor-x) · `1.6.6`

cbor-x is a high-performance CBOR encoder/decoder for JS, from the same author as msgpackr. The problem was slow or allocating CBOR stacks in Node. It solves that with reusable Encoder/Decoder instances.

#### [devalue](https://github.com/Rich-Harris/devalue) · `5.9.2`

devalue was written (SvelteKit and friends) to stringify richer JavaScript values than JSON allows — dates, maps, cyclical graphs — without `eval`. The problem was JSON's limited types and `eval`-based hydrators. devalue solves it with a custom text format.

#### [fast-json-stringify](https://github.com/fastify/fast-json-stringify) · `6.4.0`

fast-json-stringify was created in the Fastify ecosystem to serialize JSON from a JSON Schema much faster than `JSON.stringify`. The problem was that schema-known objects still paid for a fully dynamic walk. It compiles a serializer once and reuses it; this suite decodes with `JSON.parse`.

#### [flatbuffers](https://github.com/google/flatbuffers) · `24.12.23`

FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.

#### [flexbuffers](https://github.com/google/flatbuffers) · `24.12.23`

FlexBuffers is the schemaless cousin of FlatBuffers. It was created so you can have a FlatBuffers-family binary without compiling a schema. The same Google repository implements it.

#### [google-protobuf](https://github.com/protocolbuffers/protobuf-javascript) · `3.21.4`

This is Google's official JavaScript protobuf runtime (`google-protobuf` / jspb). It exists so the same `.proto` contracts can run in JS. The suite times `serializeBinary` / `deserializeBinary`.

#### [json-pack-msgpack](https://github.com/jsonjoy-com/json-pack) · `18.30.0`

json-pack (jsonjoy) is a family of binary codecs including MessagePack. It was written to give JavaScript a fast, modular binary JSON toolkit. This row times the MsgPack encoder/decoder.

#### [JSON.stringify](https://github.com/nodejs/node) · `node-24.15.0`

`JSON.stringify` / `JSON.parse` are the ECMAScript standard JSON APIs. They exist so every JavaScript host can speak RFC 8259 without a library. This row times Node's V8 implementation.

#### [msgpackr](https://github.com/kriszyp/msgpackr) · `1.12.1`

msgpackr was written for high-throughput MessagePack in Node, with reusable Packr/Unpackr instances. The problem was that generic MessagePack libraries allocated too much per call. msgpackr solves that with a performance-oriented encoder/decoder.

#### [protobuf-es](https://github.com/bufbuild/protobuf-es) · `2.15.0`

protobuf-es is Buf's Protocol Buffers implementation for ECMAScript. The problem was that existing JS protobuf stacks did not match modern TypeScript and the official proto3 feature set. It generates TypeScript and times `toBinary` / `fromBinary`.

#### [protobufjs](https://github.com/protobufjs/protobuf.js) · `7.6.6`

protobuf.js is a popular JavaScript Protocol Buffers implementation that can work from a `.proto` or a JSON descriptor. The problem was that Google's JS protobuf was awkward in Node. protobuf.js solves it with a JS-native API.

#### [sia](https://github.com/TimeleapLabs/sia) · `2.3.0`

Sia is Timeleap's compact binary tag format for JS values. It was created as a project-specific, typed binary encoding rather than a public interchange standard. This row times those primitive writers.

#### [simdjson-parse+JSON.stringify](https://github.com/simdjson/simdjson) · `0.9.2`

simdjson was created to parse JSON at memory-bandwidth speeds using SIMD. The problem was that conventional parsers were far from hardware limits. This row uses simdjson only for parse; serialize is still `JSON.stringify`. Only deserialize uses SIMD; serialize is stdlib `JSON.stringify`.

#### [v8-serializer](https://github.com/nodejs/node) · `v8-13.6.233.17-node.48`

Node's `v8.serialize` / `v8.deserialize` snapshot V8 values. They exist so the engine can persist structured clones, not as a portable wire format. This row times that Node-only API.

### Stream I/O

**Not measured.** The Node suite times the same buffer `serialize` / `deserialize` path for every codec; there is no distinct stream API loop. The benchmark runner emits **bytes only** so the Dashboard / this runner does not claim a second I/O mode. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).

### Notes

- **simdjson-parse+JSON.stringify** (optional native addon; omitted from the run if not installed): only **deserialize** uses SIMD; serialize is stdlib `JSON.stringify` (honest leaderboard label).
- **protobuf-es** / **google-protobuf** use generated code from `javascript/schemas/js_fixtures.proto` (field shapes match JS data types; string timestamps). Google stubs live under `src/generated/google/` (`npm run generate:google-protobuf`).
- **flatbuffers / flexbuffers:** fixture support via tables / FlexBuffers; see the benchmark runner for float/array workarounds.
- **bebop** / **sia** encode a JSON-shaped model via each library’s primitive writers.
- **devalue** is a framework-oriented value codec (SvelteKit), not a portable wire standard.
- **prepare()** builds native messages and compiles schemas outside the timed path.

Also: [`javascript/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/javascript/README.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=javascript&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
