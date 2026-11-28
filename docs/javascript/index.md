---
title: "JavaScript"
---

# JavaScript

The JavaScript runner executes under Node.js (V8) and compares built-in C++ JSON (`JSON.stringify` / `JSON.parse`) and structured-clone binary (`node:v8`) against pure-JS and native-addon libraries for MessagePack, CBOR, BSON, Ion, AMF, YAML, TOON, three Protocol Buffers runtimes, Avro, FlatBuffers, Dagr, Arrow IPC, Parquet, and WebAssembly HDF5.

## Runtime & Environment

Measurements run on the **Node.js** CLI host (not a browser engine), embedding Google's V8 JavaScript engine with optimizing JIT compilation, generational garbage collection, `Buffer`, and optional C++ native addons. Timings are collected with `performance.now()` and converted to nanoseconds. Hot functions optimize after initial calls, and codecs that reuse `Encoder` / `Packr` instances (`cbor-x`, `msgpackr`) avoid per-call allocation overhead. The language is specified by [ECMA-262](https://tc39.es/ecma262/) and the host runtime by the [Node.js API documentation](https://nodejs.org/api/).

| Property | Configuration |
|---|---|
| Language / spec | ECMAScript (ECMA-262) on Node.js 18+ (V8) |
| Build & toolchain | Node.js 18+ and `npm install`; protobuf codegen via `npm run generate:protobuf`; Dagr TS bundled with `esbuild` (`npm run generate:dagr`) |
| Memory model | V8 generational tracing garbage collector |
| Runner & logs | `javascript/scripts/run-benchmarks.sh` → `logs/javascript/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`javascript/src/serializers/`](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/master/javascript/src/serializers) |
| Data sets | `suite`, `columnar`, `graph`, `array`, `tensor` |

## Registered Serializers

Every row in the JavaScript runner measures the in-memory `bytes` API only; no separate stream I/O mode is emitted.

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [@msgpack/msgpack](https://github.com/msgpack/msgpack-javascript) | `msgpack` | `suite` | `bytes only` | Official JS MessagePack `encode` / `decode` |
| [amf-codec](https://github.com/csimi/amf-codec) | `amf0` | `suite` | `bytes only` | `toAMF` / `fromAMF` on plain JS objects (AMF0 only) |
| [arrow-ipc](https://arrow.apache.org/docs/js/) | `arrow` | `columnar` | `bytes only` | `apache-arrow` `tableToIPC(..., 'stream')`; batch built in `serialize`; `table_project` reads `f_float_0` |
| [avsc](https://github.com/mtth/avsc) | `avro` | `suite`, `columnar` | `bytes only` | `Type.forSchema` in `prepare`; `toBuffer` / `fromBuffer` |
| [bebop](https://github.com/6over3/bebop) | `bebop` | `suite` | `bytes only` | `BebopView` JSON-model primitives |
| [biorate-amf](https://www.npmjs.com/package/@biorate/amf) | `amf3` | `suite` | `bytes only` | `@biorate/amf` AMF3 `encode` / `decode` on plain objects |
| [bser](https://github.com/facebook/watchman) | `custom` | `suite` | `bytes only` | Watchman BSER `dumpToBuffer` / `loadFromBuffer` |
| [bson](https://github.com/mongodb/js-bson) | `bson` | `suite` | `bytes only` | Official `js-bson` `BSON.serialize` / `deserialize` |
| [cbor](https://github.com/hildjj/node-cbor) | `cbor` | `suite` | `bytes only` | `node-cbor` `encode` / `decodeFirstSync` |
| [cbor-x](https://github.com/kriszyp/cbor-x) | `cbor` | `suite` | `bytes only` | Reused `Encoder` / `Decoder` instances |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `bytes only` | Generated arena in `prepare`; timed `writeInto` + lazy accessor→domain |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `bytes only` | Direct builder `writeInto` reused `Builder` + lazy accessor→domain |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `bytes only` | Direct builder `writeInto` reused `Builder` + lazy accessor→domain |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `bytes only` | Generated arena in `prepare`; timed `writeInto` + lazy accessor→domain |
| [devalue](https://github.com/Rich-Harris/devalue) | `custom` | `suite` | `bytes only` | SvelteKit value codec `stringify` / `parse` (non-portable JS text format) |
| [fast-json-stringify](https://github.com/fastify/fast-json-stringify) | `json` | `suite` | `bytes only` | Compiled JSON Schema encoder + stdlib `JSON.parse` on decode |
| [flatbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite`, `columnar` | `bytes only` | Official `Builder` / `ByteBuffer` on generated tables |
| [flexbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite` | `bytes only` | Schemaless FlexBuffers `encode` / `toObject` |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `bytes only` | `@apache-fory/core` with pre-registered struct/list schemas |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-typescript) | `kiln` | `suite`, `tensor` | `bytes only` | Positional `Writer.encode` / `decode`; `tensor_view` borrows payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `array`, `tensor` | `bytes only` | Pure x86-64 Assembly Kiln v2 codec via Node N-API addon (`libkiln_asm_bench.a`); `TableColumns` + `KILN_OPT_EMBEDDED` O(1) skip; KLNT v2 `grid_window` & zero-copy `subarray` `tensor_view` |
| [google-protobuf](https://github.com/protocolbuffers/protobuf-javascript) | `protobuf` | `suite` | `bytes only` | Official `jspb` `serializeBinary` / `deserializeBinary` |
| [h5wasm](https://github.com/usnistgov/h5wasm) | `hdf5` | `array` | `bytes only` | WebAssembly `libhdf5` on in-memory Emscripten FS; hyperslab read for `grid_window` |
| [ion-js](https://github.com/amazon-ion/ion-js) | `ion` | `suite` | `bytes only` | Official Ion binary `dumpBinary` / `load`; DOM→object untimed |
| [js-yaml](https://github.com/nodeca/js-yaml) | `yaml` | `suite` | `bytes only` | `js-yaml` `dump` / `load` |
| [json-pack-msgpack](https://github.com/jsonjoy-com/json-pack) | `msgpack` | `suite` | `bytes only` | `@jsonjoy.com/json-pack` `MsgPackEncoder` / `MsgPackDecoder` |
| [JSON.stringify](https://github.com/nodejs/node) | `json` | `suite`, `columnar` | `bytes only` | V8 built-in `JSON.stringify` / `JSON.parse` |
| [msgpackr](https://github.com/kriszyp/msgpackr) | `msgpack` | `suite` | `bytes only` | Reused `Packr` / `Unpackr` instances |
| [parquet](https://github.com/hyparam/hyparquet-writer) | `parquet` | `columnar` | `bytes only` | `hyparquet-writer` (default Snappy) + `hyparquet` `parquetReadObjects`; `table_project` projects `f_float_0` |
| [parquet-uncompressed](https://github.com/hyparam/hyparquet-writer) | `parquet` | `columnar` | `bytes only` | Same `hyparquet-writer` with `codec: 'UNCOMPRESSED'` |
| [protobuf-es](https://github.com/bufbuild/protobuf-es) | `protobuf` | `suite` | `bytes only` | `@bufbuild/protobuf` `create` + `toBinary` / `fromBinary` |
| [protobufjs](https://github.com/protobufjs/protobuf.js) | `protobuf` | `suite`, `columnar` | `bytes only` | `protobuf.js` `Type.encode` / `decode` |
| [sia](https://github.com/TimeleapLabs/sia) | `custom` | `suite` | `bytes only` | `@timeleap/sia` typed-tag primitives over JSON model |
| [simdjson-parse+JSON.stringify](https://github.com/simdjson/simdjson) | `json` | `suite` | `bytes only` | Optional native addon: SIMD `simdjson.parse` on decode, stdlib `JSON.stringify` on encode |
| [toon](https://github.com/toon-format/toon) | `toon` | `suite` | `bytes only` | Official `@toon-format/toon` (spec 4.4); size in UTF-8 bytes |
| [v8-serializer](https://github.com/nodejs/node) | `custom` | `suite` | `bytes only` | Node-only `v8.serialize` / `v8.deserialize` |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[@msgpack/msgpack](https://github.com/msgpack/msgpack-javascript)** — The official MessagePack JavaScript implementation (`@msgpack/msgpack`). MessagePack was created as compact binary JSON. This package is the reference encode/decode API for JS.
    - **[amf-codec](https://github.com/csimi/amf-codec)** — amf-codec is a small AMF0 encoder and decoder for Node. AMF0 is the command encoding inside RTMP. The timed path is toAMF and fromAMF on one plain object. It does not write AMF3.
    - **[arrow-ipc](https://arrow.apache.org/docs/js/)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times the apache-arrow IPC stream writer and reader (tableToIPC with type stream) inside the suite's bytes mode, not the Arrow file format. Schema objects are selected in prepare. Row-to-column conversion stays inside serialize. table_project deserialize reads f_float_0 only. No compliance decoder.
    - **[avsc](https://github.com/mtth/avsc)** — avsc brings Apache Avro to JavaScript. Avro was created for compact, schema-driven records in data pipelines. avsc solves the JS side with `Type.forSchema` and buffer encode/decode.
    - **[bebop](https://github.com/6over3/bebop)** — Bebop is a schema-driven binary format created as a simpler, faster alternative to protobuf-like IDL stacks for games and services. The problem was heavy generated code and slow encoders. Bebop solves it with a compact schema and generated writers.
    - **[biorate-amf](https://www.npmjs.com/package/@biorate/amf)** — @biorate/amf is an AMF3 encoder and decoder for JavaScript. AMF3 adds a short integer and shared strings. The timed path is encode and decode on one plain object. It is a separate row from amf-codec because that library writes AMF0.
    - **[bser](https://github.com/facebook/watchman)** — BSER is Facebook Watchman's binary protocol: a compact encoding for the watchman's client/server messages. The problem was JSON overhead in a local file-watching daemon. This row times the Node `bser` dump/load path.
    - **[bson](https://github.com/mongodb/js-bson)** — BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.
    - **[cbor](https://github.com/hildjj/node-cbor)** — node-cbor implements IETF CBOR (RFC 8949) for Node. CBOR exists as the IETF's binary JSON-like format. The library is a full encode/decode implementation of that RFC.
    - **[cbor-x](https://github.com/kriszyp/cbor-x)** — cbor-x is a high-performance CBOR encoder/decoder for JS, from the same author as msgpackr. The problem was slow or allocating CBOR stacks in Node. It solves that with reusable Encoder/Decoder instances.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.
    - **[devalue](https://github.com/Rich-Harris/devalue)** — devalue was written (SvelteKit and friends) to stringify richer JavaScript values than JSON allows — dates, maps, cyclical graphs — without `eval`. The problem was JSON's limited types and `eval`-based hydrators. devalue solves it with a custom text format.
    - **[fast-json-stringify](https://github.com/fastify/fast-json-stringify)** — fast-json-stringify was created in the Fastify ecosystem to serialize JSON from a JSON Schema much faster than `JSON.stringify`. The problem was that schema-known objects still paid for a fully dynamic walk. It compiles a serializer once and reuses it; this suite decodes with `JSON.parse`.
    - **[flatbuffers](https://github.com/google/flatbuffers)** — FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.
    - **[flexbuffers](https://github.com/google/flatbuffers)** — FlexBuffers is the schemaless cousin of FlatBuffers. It was created so you can have a FlatBuffers-family binary without compiling a schema. The same Google repository implements it.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses @apache-fory/core with registered struct/list schemas and the bytes API.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-typescript)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) bound via Node.js N-API addon statically linking shared `libkiln_asm_bench.a`. Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), `array` (KLNT v2 `grid` + strided `grid_window`), and `tensor` (KLNT v2 with zero-copy `Buffer.subarray` `tensor_view`).
    - **[google-protobuf](https://github.com/protocolbuffers/protobuf-javascript)** — This is Google's official JavaScript protobuf runtime (`google-protobuf` / jspb). It exists so the same `.proto` contracts can run in JS. The suite times `serializeBinary` / `deserializeBinary`.
    - **[h5wasm](https://github.com/usnistgov/h5wasm)** — h5wasm compiles HDF5 to WebAssembly. This row times one float64 dataset named grid in the WASM memory filesystem. grid_window reads a dataset slice, which is a libhdf5 hyperslab. The row does not time the five suite types.
    - **[ion-js](https://github.com/amazon-ion/ion-js)** — Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. ion-js is the official JavaScript implementation. This row times binary dump/load; the Ion DOM is turned into plain objects outside the timer.
    - **[js-yaml](https://github.com/nodeca/js-yaml)** — js-yaml is the usual Node YAML 1.2 parser/dumper. YAML exists as a human-friendly config language. js-yaml solves the JavaScript side with a widely deployed implementation.
    - **[json-pack-msgpack](https://github.com/jsonjoy-com/json-pack)** — json-pack (jsonjoy) is a family of binary codecs including MessagePack. It was written to give JavaScript a fast, modular binary JSON toolkit. This row times the MsgPack encoder/decoder.
    - **[JSON.stringify](https://github.com/nodejs/node)** — `JSON.stringify` / `JSON.parse` are the ECMAScript standard JSON APIs. They exist so every JavaScript host can speak RFC 8259 without a library. This row times Node's V8 implementation.
    - **[msgpackr](https://github.com/kriszyp/msgpackr)** — msgpackr was written for high-throughput MessagePack in Node, with reusable Packr/Unpackr instances. The problem was that generic MessagePack libraries allocated too much per call. msgpackr solves that with a performance-oriented encoder/decoder.
    - **[parquet](https://github.com/hyparam/hyparquet-writer)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times hyparquet-writer parquetWriteBuffer at the library default codec, Snappy, and hyparquet 1.31.2 parquetReadObjects. A nested_table value (struct plus a list of structs, int32 not widened) round-tripped, which is why the row is registered. table_project passes columns ['f_float_0'] on read. SerializerVersion is the writer package. No compliance decoder.
    - **[parquet-uncompressed](https://github.com/hyparam/hyparquet-writer)** — This is the same hyparquet-writer path as parquet, with codec UNCOMPRESSED. That switch changes the column codec metadata and the bytes. Encodings stay at the library default. It is the same writer, not a second Parquet library. No compliance decoder.
    - **[protobuf-es](https://github.com/bufbuild/protobuf-es)** — protobuf-es is Buf's Protocol Buffers implementation for ECMAScript. The problem was that existing JS protobuf stacks did not match modern TypeScript and the official proto3 feature set. It generates TypeScript and times `toBinary` / `fromBinary`.
    - **[protobufjs](https://github.com/protobufjs/protobuf.js)** — protobuf.js is a popular JavaScript Protocol Buffers implementation that can work from a `.proto` or a JSON descriptor. The problem was that Google's JS protobuf was awkward in Node. protobuf.js solves it with a JS-native API.
    - **[sia](https://github.com/TimeleapLabs/sia)** — Sia is Timeleap's compact binary tag format for JS values. It was created as a project-specific, typed binary encoding rather than a public interchange standard. This row times those primitive writers.
    - **[simdjson-parse+JSON.stringify](https://github.com/simdjson/simdjson)** — simdjson was created to parse JSON at memory-bandwidth speeds using SIMD. The problem was that conventional parsers were far from hardware limits. This row uses simdjson only for parse; serialize is still `JSON.stringify`.
    - **[toon](https://github.com/toon-format/toon)** — @toon-format/toon is the official TypeScript codec and the reference for TOON specification 4.4. The timed path is encode and decode of UTF-8 text. The Size column is that byte length. A token count is not part of the measurement.
    - **[v8-serializer](https://github.com/nodejs/node)** — Node's `v8.serialize` / `v8.deserialize` snapshot V8 values. They exist so the engine can persist structured clones, not as a portable wire format. This row times that Node-only API.

## Measurement Caveats

- **Bytes-only runner:** Every JavaScript adapter operates on in-memory buffers; the runner does not emit stream rows so no adapted stream is misreported as streaming I/O.
- **Optional native addon (`simdjson`):** `simdjson-parse+JSON.stringify` registers only when the native `simdjson` addon loads. Its row name explicitly discloses that encode remains `JSON.stringify`.
- **Non-portable formats:** `v8-serializer` and `devalue` are Node.js/JavaScript-specific value encodings rather than cross-language wire standards.
- **Protobuf schema source:** `protobuf-es` and `google-protobuf` generate stubs from `javascript/schemas/js_fixtures.proto` (matching JS shapes with string timestamps).
- **Dagr bundling & decode path:** `dagr build` emits TypeScript bundled via `esbuild` into `src/generated/dagr_bundle.js`. Direct builders (`dagr-packed`, `dagr-frozen-packed`) and arenas (`dagr-regular`, `dagr-frozen`) are prepared in `prepare()`, writing into a reused `Builder`; decode materializes domain values from lazy accessors inside the timed path, with $N > 1$ framed as `[u32 count][u32 len][record]`.
- **Columnar libraries:** `parquet` uses `hyparquet-writer` 0.16.10 + `hyparquet` 1.31.2 (`parquet-wasm` is not registered). Row-to-column conversion runs inside timed `serialize` per [Timing contract rule 8](../analysis/TIMING_HONESTY.md).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (JavaScript)](../dashboard/index.html?lang=javascript&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (JavaScript)](../dashboard/index.html#compliance)
- **Source-level analyses:** [JavaScript: `JSON.stringify` vs. `google-protobuf`](../analysis/call-sites/javascript-json-vs-protobuf.md) · [4.11 JavaScript: three Protobufs](../theory/401/javascript-three-protobufs.md)
- **Build & run guide:** [`javascript/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/javascript/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
