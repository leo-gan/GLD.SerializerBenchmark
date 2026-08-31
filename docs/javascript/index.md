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
| @msgpack/msgpack | Binary | `@msgpack/msgpack` | `encode` / `decode` |
| avsc | Schema | `avsc` | `Type.forSchema` + `toBuffer` / `fromBuffer` |
| bebop | Schema | `bebop` | `BebopView` JSON-model primitives |
| bser | Binary | `bser` | `dumpToBuffer` / `loadFromBuffer` |
| bson | Binary | `bson` | `BSON.serialize` / `deserialize` |
| cbor | Binary | `cbor` | `encode` / `decodeFirstSync` |
| cbor-x | Binary | `cbor-x` | reused `Encoder` / `Decoder` |
| devalue | Native | `devalue` | `stringify` / `parse` |
| fast-json-stringify | JSON | `fast-json-stringify` | compile once + `JSON.parse` |
| flatbuffers | Schema | `flatbuffers` | `Builder` / `ByteBuffer` |
| flexbuffers | Schema | `flatbuffers` (FlexBuffers) | `encode` / `toObject` |
| google-protobuf | Schema | `google-protobuf` | official jspb `serializeBinary` / `deserializeBinary` |
| json-pack-msgpack | Binary | `@jsonjoy.com/json-pack` | `MsgPackEncoder` / `MsgPackDecoder` |
| JSON.stringify | JSON | builtin | `JSON.stringify` / `JSON.parse` |
| msgpackr | Binary | `msgpackr` | reused `Packr` / `Unpackr` |
| protobuf-es | Schema | `@bufbuild/protobuf` | `create` + `toBinary` / `fromBinary` |
| protobufjs | Schema | `protobufjs` | real fixture `Type.encode` / `decode` |
| sia | Binary | `@timeleap/sia` | typed-tag JSON-model over Sia primitives |
| simdjson-parse+JSON.stringify | JSON | `simdjson` (optional) | ser: `JSON.stringify`; deser: `simdjson.parse` |
| v8-serializer | Native | `node:v8` | `v8.serialize` / `v8.deserialize` |

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
