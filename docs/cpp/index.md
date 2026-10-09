---
title: "C++"
---

C++
===

C++ serialization spans **header-only JSON** (nlohmann, RapidJSON, ArduinoJson, **glaze**), **SIMD parse** (simdjson), **C libraries callable from C++** (yyjson), **schemaless binary** (MessagePack, cereal, bitsery, zpp_bits, CBOR/BSON via jsoncons), **schema / zero-copy** families (official **libprotobuf**, in-tree Protobuf wire, FlatBuffers, FlexBuffers, SBE, Dagr), and **columnar** Arrow IPC, Parquet, and ORC.

## Runtime

### What it is

C++ compiles to **native machine code**. There is no virtual machine. This runner requires **C++20**. Memory is mostly handled by **RAII** (Resource Acquisition Is Initialization): an object frees its resources in its destructor when it goes out of scope. That is still not a garbage collector. Leaks and extra copies remain the programmer’s problem, and the library’s.

| | This suite |
|---|---|
| Language | **C++20** (required) |
| Build | CMake 3.16 or newer, **Release** configuration, `g++` or `clang++` |
| Dependencies | CMake `FetchContent` downloads into `cpp/third_party/` (network needed once) |
| Prepare | A C++20 compiler and cmake. Check with `./scripts/check-host-requirements.sh cpp`. |
| Run | `cpp/scripts/run-benchmarks.sh` |
| Memory | RAII and the heap. No garbage collector. |

### What this suite runs

The first CMake configure downloads the pinned third-party libraries. Official protobuf is a separate sysroot created by `cpp/scripts/setup-protobuf-sysroot.sh`. It is not the system `libprotobuf`. **glaze** is pinned to v2.9.5 because glaze v3 and later require C++23. Apache Arrow 25.0.1 is an optional prebuilt package (`-DARROW_ROOT=`), not a FetchContent pin. SBE 1.40.2 is vendored header-only output under `cpp/gen/sbe/`.

### What changes the numbers

The compiler’s optimization level changes the numbers more than almost anything else. Header-only JSON (nlohmann) and SIMD parse (simdjson) are different designs. They belong in the same ranking only when you stay inside one family.

A C library called from C++, such as yyjson, is a C++ *call path*. It is not a second measurement of the C suite. See [C vs C++](#c-vs-c-clear-separation).

### Suite-specific gotchas

**simdjson** is optimized for parse. Serialize in this suite is prepared minified JSON, so that row does not claim a SIMD encoder.

These times cannot be ranked against C, C#, or Python as one contest.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`cpp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/README.md). The language reference is [C++ on cppreference](https://en.cppreference.com/w/cpp).

## Benchmark runner

- Directory: `cpp/` (repository root)
- Output: monorepo `logs/cpp/YYYY-MM-DD-HHMMSS.csv` (`Language=cpp`, times in **nanoseconds**)
- Runner: `cpp/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Build: CMake **C++20**, deps via `FetchContent` → `cpp/third_party/` (pins in [`cpp/third_party/VERSIONS.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/third_party/VERSIONS.md))
- Official Protobuf: `cpp/scripts/setup-protobuf-sysroot.sh` (libprotobuf 3.12 + protoc, no root install)
- Apache Arrow 25.0.1: optional prebuilt prefix (`-DARROW_ROOT=` or `ARROW_ROOT`). Same feature set as the jammy apt packages `libarrow-dev` and `libparquet-dev` 25.0.1-1. Not FetchContent. ORC is inside `libarrow`. A missing prefix skips the Arrow rows and still builds the other serializers.
- SBE 1.40.2: header-only codecs vendored in `cpp/gen/sbe/` from `schemas/v2/sbe/signal.xml`
- Registration: [`cpp/src/register.cpp`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/register.cpp). With Arrow present this machine registers **39** codecs (**33** existing rows, the four Dagr rows included, plus `sbe` and five Arrow rows). Without Arrow, `sbe` remains and the five Arrow rows are omitted.

## Serializers

| Serializer | Category | Library | Optimal call path | Notes |
|------------|----------|---------|-------------------|-------|
| [arduinojson](https://github.com/bblanchon/ArduinoJson) | JSON | ArduinoJson | `serializeJson` / `deserializeJson` (bytes + stream) | Embedded/IoT; **native stream** |
| [arrow-ipc](https://github.com/apache/arrow) | Columnar | Apache Arrow 25.0.1 | `ipc::MakeStreamWriter` into a buffer | Uncompressed IPC stream. Row→column conversion is inside timed `serialize_bytes`. `table_project` uses `included_fields`. Stream **adapted**. Optional (`ARROW_ROOT`). No compliance decoder. |
| [avro](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md) | Schema | suite avro-binary | zigzag/varint + array blocks | **Avro binary encoding** |
| [avro_c](https://github.com/apache/avro) | Schema | avro-c | cached iface + value_write/read | **Real** Avro C lib from C++; stream adapted |
| [bitsery](https://github.com/fraillt/bitsery) | Binary | bitsery | serializer `object`/`container` | Explicit schema |
| [boost_serialization](https://github.com/boostorg/serialization) | Binary | Boost.Serialization | binary_o/iarchive (bytes + stream) | Optional (system lib); **native stream** |
| [capnproto](https://github.com/capnproto/capnproto) | Schema | Cap'n Proto | `messageToFlatArray` / `writeMessage` of a prepared `MallocMessageBuilder`; decode is `FlatArrayMessageReader` / `InputStreamMessageReader` | Domain fill is `prepare`; field walk is `to_domain`. **native stream** |
| [cereal](https://github.com/USCiLab/cereal) | Binary | cereal | `BinaryOutput/InputArchive` on ostream/istream | C++-native archives; **native stream** |
| [cista](https://github.com/felixguendling/cista) | Binary | Cista++ | `cista::serialize` / `deserialize` | Offset graphs; convert in prepare |
| [custom_binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md) | Binary | harness | length-prefixed fields | Baseline; stream adapted |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | Schema | dagr + gen (`cpp/dagr_gen`) | direct builder / lazy reader | Direct value structs built in prepare (like protobuf's messages); `direct::build` into one reused `dagr::Builder` timed; lazy accessors → domain timed; N>1 suite frame; stream adapted |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | Schema | dagr + gen (`cpp/dagr_gen`) | arena serializer / lazy reader | Regular (vtable) nodes; generated arena built in prepare; `Arena::serialize` into a reused builder and caches timed; lazy accessors → domain timed; N>1 suite frame |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | Schema | dagr + gen (`cpp/dagr_gen`) | arena serializer / lazy reader | Frozen nodes; same call path as dagr-regular |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | Schema | dagr + gen (`cpp/dagr_gen`) | direct builder / lazy reader | Frozen+packed nodes; same call path as dagr-packed |
| [flatbuffers](https://github.com/google/flatbuffers) | Schema | flatbuffers | `FlatBufferBuilder` | C++ primary; C uses **flatcc** |
| [glaze](https://github.com/stephenberry/glaze) | JSON | stephenberry/glaze | `glz::write_json` / `glz::read_json` on domain structs | Direct-to-memory JSON; **C++20 pin v2.9.5** (v3+ needs C++23); stream adapted |
| [flexbuffers](https://github.com/google/flatbuffers) | Schema | flatbuffers | `flexbuffers::Builder` / `GetRoot` | Schemaless FB family |
| [jsoncons_bson](https://github.com/danielaparker/jsoncons) | Binary | jsoncons | `bson::encode/decode` on domain structs | BSON document; **native stream** |
| [jsoncons_cbor](https://github.com/danielaparker/jsoncons) | Binary | jsoncons | `cbor::encode/decode` on domain structs | CBOR; **native stream** |
| [jsoncons_msgpack](https://github.com/danielaparker/jsoncons) | Binary | jsoncons | `msgpack::encode/decode` on domain structs | MessagePack; **native stream** |
| [msgpack](https://github.com/msgpack/msgpack-c) | Binary | msgpack-c (C++ API) | `packer` + `sbuffer` / `unpack`; stream packer + unpacker | Official C++ API; **native stream** |
| [nlohmann_bson](https://github.com/nlohmann/json) | Binary | nlohmann/json | `to_bson` / `from_bson` (+ ostream/istream) | BSON (object root); **native stream** |
| [nlohmann_cbor](https://github.com/nlohmann/json) | Binary | nlohmann/json | `to_cbor` / `from_cbor` (+ ostream/istream) | IETF CBOR; **native stream** |
| [nlohmann_json](https://github.com/nlohmann/json) | JSON | nlohmann/json | `dump` / `parse`; stream `<<` / `parse(istream)` | De-facto C++ JSON; **native stream** |
| [nlohmann_msgpack](https://github.com/nlohmann/json) | Binary | nlohmann/json | `to_msgpack` / `from_msgpack` (+ ostream/istream) | Multi-format nlohmann; **native stream** |
| [nlohmann_ubjson](https://github.com/nlohmann/json) | Binary | nlohmann/json | `to_ubjson` / `from_ubjson` (+ ostream/istream) | UBJSON; **native stream** |
| [orc](https://github.com/apache/arrow) | Columnar | Apache Arrow 25.0.1 ORC adapter | `WriteOptions.compression = GZIP` | Adapter default is UNCOMPRESSED. This row sets Arrow `GZIP`, which the adapter stores as ORC ZLIB. Stream **adapted**. Optional. No compliance decoder. |
| [orc-uncompressed](https://github.com/apache/arrow) | Columnar | Apache Arrow 25.0.1 ORC adapter | `WriteOptions.compression = UNCOMPRESSED` | Explicit uncompressed ORC. |
| [parquet](https://github.com/apache/arrow) | Columnar | Apache Arrow 25.0.1 | `WriteTable` + `Compression::SNAPPY` | Writer default on 25.0.1 is UNCOMPRESSED, so this row sets Snappy. Stream **adapted**. Optional. No compliance decoder. |
| [parquet-uncompressed](https://github.com/apache/arrow) | Columnar | Apache Arrow 25.0.1 | `WriteTable` + `Compression::UNCOMPRESSED` | Explicit uncompressed Parquet. |
| [protobuf](https://github.com/protocolbuffers/protobuf) | Schema | **libprotobuf** (Google) | `SerializeToArray` / `ParseFromArray` on prepared messages | Official C++ runtime; sysroot via setup script |
| [protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/ser_protobuf_wire.cpp) | Schema | suite wire | proto3 field tags | In-tree codec; same field numbers as shared `.proto` |
| [rapidjson](https://github.com/Tencent/rapidjson) | JSON | Tencent/rapidjson | `Writer` + `Document::Parse`; stream O/IStreamWrapper | SAX/DOM hot path; **native stream** |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | Schema | SBE 1.40.2 | flyweight `wrapAndApplyHeader` inside timed `serialize_bytes` | Vendored codecs from `schemas/v2/sbe/signal.xml`. No `nested_table`. Stream **adapted**. No compliance decoder. |
| [simdjson](https://github.com/simdjson/simdjson) | JSON | simdjson | `dom::parser::parse` | Ser = prepared minified JSON; stream adapted |
| [thrift](https://github.com/apache/thrift) | Schema | suite TBinaryProtocol | field type+id + STOP | Apache Thrift binary; stream adapted |
| [yas](https://github.com/niXman/yas) | Binary | niXman/yas | `yas::save/load` `mem\|binary` | Top-tier microbench staple |
| [yyjson](https://github.com/ibireme/yyjson) | JSON | yyjson | `yyjson_mut_write` / `yyjson_read` | **Also in C suite**; stream adapted |
| [zpp_bits](https://github.com/eyalz800/zpp_bits) | Binary | zpp_bits | `zpp::bits::out` / `in` | Compile-time binary |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [arduinojson](https://github.com/bblanchon/ArduinoJson) · `7.4.3`

ArduinoJson was written so microcontrollers and Arduino-class devices could speak JSON in a tiny RAM budget. The problem was desktop JSON libraries being far too large. It uses a fixed-capacity document model.

#### [arrow-ipc](https://github.com/apache/arrow) · `25.0.1`

Apache Arrow IPC writes a columnar record batch stream. This row uses `arrow::ipc::MakeStreamWriter` into a memory buffer (the stream writer, not the file writer) with no compression. Domain rows are converted to an Arrow table inside timed `serialize_bytes`. `table_project` deserialize sets `IpcReadOptions.included_fields` to the `f_float_0` column instead of reading every column and slicing. Stream calls are adapted to the bytes path. The row is omitted when `ARROW_ROOT` is unset. There is no compliance decoder.

#### [avro](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md) · `binary-1.11`

Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.

#### [avro_c](https://github.com/apache/avro) · `avro-c`

Apache Avro was created for Hadoop-era data: a compact binary encoding with the schema stored out of band so field names are not repeated. avro-c is the official C implementation of that encoding.

#### [bitsery](https://github.com/fraillt/bitsery) · `5.2.4`

bitsery is an explicit-schema binary serializer for C++. The problem was that many C++ binaries were either reflection-slow or ad-hoc. bitsery makes the schema the API (`object` / `container`).

#### [boost_serialization](https://github.com/boostorg/serialization)

Boost.Serialization is the classic C++ archive framework. It was created so C++ programs could persist object graphs portably across Boost archives. This row times the binary archive.

#### [capnproto](https://github.com/capnproto/capnproto) · `1.0.x`

Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.

#### [cereal](https://github.com/USCiLab/cereal) · `1.3.2`

cereal was created as a C++11 header-only archive library (binary, JSON, XML) in the Boost.Serialization design space, but simpler. The problem was Boost.Serialization's weight. cereal uses output/input archives on existing types.

#### [cista](https://github.com/felixguendling/cista) · `0.15`

Cista++ serializes C++ object graphs as offset-based, pointer-free images. The problem was that pointer graphs are not portable or mmap-friendly. Cista writes a relocatable layout.

#### [custom_binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/cpp/index.md) · `harness`

This is the suite's length-prefixed V2 baseline, not a published format. It exists so every language has a simple binary control point: write fields with explicit lengths, read them back, no schema compiler.

#### [dagr-packed](https://codeberg.org/mzaks/dagr)

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).

#### [dagr-regular](https://codeberg.org/mzaks/dagr)

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).

#### [dagr-frozen](https://codeberg.org/mzaks/dagr)

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).

#### [dagr-frozen-packed](https://codeberg.org/mzaks/dagr)

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).

#### [flatbuffers](https://github.com/google/flatbuffers) · `flatbuffers`

FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.

#### [glaze](https://github.com/stephenberry/glaze) · `2.9.5`

glaze was created for extremely fast, reflection-based JSON (and other formats) on modern C++. The problem was that C++ JSON usually meant a DOM or hand-written macros. glaze maps structs directly with compile-time reflection.

#### [flexbuffers](https://github.com/google/flatbuffers) · `flatbuffers-flex`

FlexBuffers is the schemaless cousin of FlatBuffers. It was created so you can have a FlatBuffers-family binary without compiling a schema. The same Google repository implements it.

#### [jsoncons_bson](https://github.com/danielaparker/jsoncons) · `0.177.0`

jsoncons is a C++ library for JSON and binary JSON-family formats (CBOR, BSON, MessagePack). It was written as a consistent, typed encode/decode toolkit rather than a single DOM. This row times jsoncons `bson::encode` / `decode`.

#### [jsoncons_cbor](https://github.com/danielaparker/jsoncons) · `0.177.0`

jsoncons is a C++ library for JSON and binary JSON-family formats (CBOR, BSON, MessagePack). It was written as a consistent, typed encode/decode toolkit rather than a single DOM. This row times jsoncons `cbor::encode` / `decode`.

#### [jsoncons_msgpack](https://github.com/danielaparker/jsoncons) · `0.177.0`

jsoncons is a C++ library for JSON and binary JSON-family formats (CBOR, BSON, MessagePack). It was written as a consistent, typed encode/decode toolkit rather than a single DOM. This row times jsoncons `msgpack::encode` / `decode`.

#### [msgpack](https://github.com/msgpack/msgpack-c) · `msgpack-cxx`

msgpack-c is the official C/C++ implementation of MessagePack. MessagePack was created to be as small and fast as a binary format while staying as simple as JSON. The C library solves that with pack/unpack APIs (and a separate C++ API in the same repository).

#### [nlohmann_bson](https://github.com/nlohmann/json) · `3.12.0`

nlohmann/json is the de-facto modern C++ JSON library. It was created so C++ could use a JSON value type with an intuitive, STL-like API. The same library also maps that DOM to CBOR, MessagePack, BSON, and UBJSON. This row times `to_bson` / `from_bson`.

#### [nlohmann_cbor](https://github.com/nlohmann/json) · `3.12.0`

nlohmann/json is the de-facto modern C++ JSON library. It was created so C++ could use a JSON value type with an intuitive, STL-like API. The same library also maps that DOM to CBOR, MessagePack, BSON, and UBJSON. This row times `to_cbor` / `from_cbor`.

#### [nlohmann_json](https://github.com/nlohmann/json) · `3.12.0`

nlohmann/json is the de-facto modern C++ JSON library. It was created so C++ could use a JSON value type with an intuitive, STL-like API. The same library also maps that DOM to CBOR, MessagePack, BSON, and UBJSON.

#### [nlohmann_msgpack](https://github.com/nlohmann/json) · `3.12.0`

nlohmann/json is the de-facto modern C++ JSON library. It was created so C++ could use a JSON value type with an intuitive, STL-like API. The same library also maps that DOM to CBOR, MessagePack, BSON, and UBJSON. This row times `to_msgpack` / `from_msgpack`.

#### [nlohmann_ubjson](https://github.com/nlohmann/json) · `3.12.0`

nlohmann/json is the de-facto modern C++ JSON library. It was created so C++ could use a JSON value type with an intuitive, STL-like API. The same library also maps that DOM to CBOR, MessagePack, BSON, and UBJSON. This row times `to_ubjson` / `from_ubjson`.

#### [orc](https://github.com/apache/arrow) · `25.0.1`

`orc` writes with `arrow::adapters::orc::ORCFileWriter`. On Arrow 25.0.1 the adapter `WriteOptions` default is **UNCOMPRESSED**, so this row sets `Compression::GZIP`. The adapter stores that value as ORC ZLIB. `orc-uncompressed` sets `Compression::UNCOMPRESSED`. `table_project` calls `Read({"f_float_0"})`. Row→column conversion is inside timed `serialize_bytes`. Stream is adapted. No compliance decoder.

#### [orc-uncompressed](https://github.com/apache/arrow) · `25.0.1`

Same ORC writer as `orc`, with `WriteOptions.compression` set to `arrow::Compression::UNCOMPRESSED`. The name is the override.

#### [parquet](https://github.com/apache/arrow) · `25.0.1`

`parquet` calls `parquet::arrow::WriteTable` with `Compression::SNAPPY`. Arrow C++ `WriterProperties` default on 25.0.1 is **UNCOMPRESSED**, so the suite name sets Snappy explicitly. `parquet-uncompressed` passes `Compression::UNCOMPRESSED`. `table_project` uses `ReadTable` with leaf column `{0}` (`f_float_0`). Conversion is inside timed `serialize_bytes`. Stream is adapted. No compliance decoder.

#### [parquet-uncompressed](https://github.com/apache/arrow) · `25.0.1`

Same Parquet writer as `parquet`, with `WriterProperties::Builder::compression(UNCOMPRESSED)`. The name is the override.

#### [protobuf](https://github.com/protocolbuffers/protobuf) · `3.12.4`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/ser_protobuf_wire.cpp) · `wire-v2`

This row is the suite's in-tree proto3 tag reader/writer. It exists to measure the published Protocol Buffers encoding itself, without a particular vendor runtime. Field numbers match `schemas/v2/protobuf/benchmark_v2.proto`.

#### [rapidjson](https://github.com/Tencent/rapidjson) · `1.1.0`

RapidJSON was written at Tencent for high-performance JSON in C++ with SAX and DOM APIs. The problem was slow or awkward C++ JSON stacks. It became a standard hot-path parser/generator.

#### [sbe](https://github.com/aeron-io/simple-binary-encoding) · `1.40.2`

Simple Binary Encoding is a flyweight codec: the generated C++ headers read and write fields at fixed offsets in a caller-owned buffer. This row vendors sbe-tool 1.40.2 output for `schemas/v2/sbe/signal.xml` (`table` and `signal` only; `nested_table` is not in the schema). `wrapAndApplyHeader` and the field stores run inside timed `serialize_bytes`. Stream is adapted. There is no compliance decoder.

#### [simdjson](https://github.com/simdjson/simdjson) · `3.10.1`

simdjson was created to parse JSON at near memory bandwidth using SIMD. The problem was that conventional parsers left most of the CPU unused. This suite times parse; serialize is prepared minified JSON.

#### [thrift](https://github.com/apache/thrift) · `TBinaryProtocol`

Apache Thrift was created at Facebook so many languages could share RPC and serialization from one IDL. The problem was hand-written cross-language services. Thrift solves it with a schema compiler and protocols such as TCompactProtocol.

#### [yas](https://github.com/niXman/yas) · `7.x`

YAS (Yet Another Serializer) is a high-performance C++ binary archive library. It was written as a microbenchmark staple: serialize structs with very little abstraction cost.

#### [yyjson](https://github.com/ibireme/yyjson) · `0.10.0`

yyjson was written for high-performance JSON in ANSI C: fast parse and print without giving up a usable DOM. The problem was that lightweight C parsers were slow, and fast parsers were often C++ or SAX-only. yyjson solves that with a compact C implementation and mutable/immutable document APIs.

#### [zpp_bits](https://github.com/eyalz800/zpp_bits) · `4.4.25`

zpp_bits is a compile-time binary serializer for modern C++. The problem was runtime reflection and verbose archive APIs. It uses template `out` / `in` over tuples and structs.

### Call-path contract

```text
prepare(fixture)                 # untimed: DOM/maps, buffers, domain convert
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed (codec only)
  to_domain (if needed)          # untimed
  fidelity(expected, actual)     # untimed
```

For Arrow and SBE, `prepare` only stores the fixture. Building the Arrow table (or filling the SBE flyweight) runs inside timed `serialize_bytes`. `table_project` deserialize reads the `f_float_0` column only. Those rows are bytes-only in the columnar run config; the stream methods are adapted and are not a second codec.

## C vs C++ — clear separation

| Concern | C benchmark runner (`c/`) | C++ benchmark runner (`cpp/`) |
|---------|------------------|----------------------|
| CBOR | tinycbor, libcbor, QCBOR, zcbor | jsoncons CBOR |
| FlatBuffers | **flatcc** (C) | **google/flatbuffers** (C++) |
| JSON focus | cJSON, yyjson, jansson, parson, json-c | nlohmann, RapidJSON, simdjson, arduinojson, yyjson, glaze |
| Language id | `c` | `cpp` |
| MessagePack | mpack, msgpack-c **C API** | msgpack-c **C++ API** (`msgpack.hpp`) |
| Object model | C structs + function pointers | C++20 structs + virtual `ISerializer` |
| Protobuf | Google **libprotobuf** (`protobuf`), plus nanopb / protobuf-c / protobuf-wire (shared suite wire helper) | official **libprotobuf** + in-tree protobuf-wire |

### Libraries that work for **both** C and C++

Some projects are C libraries with a pure C API. They are valid from C++ via `extern "C"` includes. The suite registers them carefully:

1. **yyjson** (registered in **both** benchmark runners)
   - **Why:** Written in C, ships `yyjson.h` with C linkage; C++ can call it without a separate C++ port.
   - **How:** C++ includes `yyjson.h` and uses `yyjson_read` / `yyjson_mut_write` (same recommended APIs as the C benchmark runner).
   - **Example:**
     ```cpp
     #include <yyjson.h>
     yyjson_doc* doc = yyjson_read(ptr, len, 0);
     char* out = yyjson_write(doc, 0, &out_len);
     ```
     vs C benchmark runner `ser_yyjson.c` with the same calls.

2. **msgpack-c** (related but **not** the same registration)
   - **Why:** One repository provides **two** APIs: C (`msgpack.h`) and C++ (`msgpack.hpp`).
   - **How:** C suite uses pack/unpack C functions; C++ suite uses `msgpack::packer` / `msgpack::unpack`.
   - **Wire format:** Compatible MessagePack; **call path and type mapping differ**.

3. **Protobuf family** (shared schema, different runtimes)
   - **Why:** The suite `.proto` is language-agnostic; C and C++ use different encoders for the **same field numbers**.
   - **How:** Both benchmark runners register official **libprotobuf** (`protobuf` row, sysroot via `setup-protobuf-sysroot.sh`) plus an in-tree **protobuf-wire** baseline. C also keeps log names `nanopb` / `protobuf-c` that currently time the shared `fixture_pb_v2` wire helper (see [C overview](../c/index.md) caveats)—not full generated nanopb/protoc-gen-c stacks. All field numbers align with `schemas/v2/protobuf/benchmark_v2.proto`.
   - **Example field:** `Message.f_int32 = 2` is wire tag `(2<<3)|0` in both.

4. **FlatBuffers family** (shared idea, different codegens)
   - **Why:** Google FlatBuffers is C++-first; **flatcc** is the maintained C implementation.
   - **How:** C benchmark runner → flatcc builder/reader; C++ benchmark runner → `flatbuffers::FlatBufferBuilder` (+ FlexBuffers).
   - **Not interchangeable binaries** without matching schema/codegen.

5. **Avro family**
   - **Why:** Same **Avro binary encoding** (zigzag ints, length-prefixed strings, array blocks).
   - **How:** C benchmark runner → **avro-c**; C++ benchmark runner → in-tree Avro binary codec for suite types (Apache avro-cpp is heavy to FetchContent; wire follows Avro 1.x binary).
   - **Example:** `string` = zigzag/`long` length + bytes; arrays end with a zero count block.

6. **Not dual-registered (C-only or C++-only by design)**
   - **C-only in suite:** cJSON, jansson, parson, json-c, mpack, tinycbor, QCBOR, libbson, nanopb/protobuf-c log rows, flatcc, avro-c, zcbor.
   - **C++-only in suite:** nlohmann, RapidJSON, simdjson, arduinojson, glaze, cereal, bitsery, zpp_bits, jsoncons, google flatbuffers C++ API, Arrow IPC/Parquet/ORC, SBE.

**Rule of thumb:** If a library is **pure C** and already measured under `Language=c`, re-registering under C++ only makes sense when the C++ call path is a first-class usage mode (yyjson) or when the **API surface differs** (msgpack C vs C++). Do not treat C and C++ rows as interchangeable runtimes for ranking.

## Caveats

- **glaze** is pinned to **v2.9.5**, the last release that builds as C++20. Glaze v3+ requires C++23 (GCC 12+ / Clang 15+). This pin measures JSON via `write_json` / `read_json` on suite structs; CBOR is not registered (it landed after the C++20 line). Stream is **adapted**.
- **simdjson** is optimized for parse; serialize is prepared minified JSON (same honesty as Rust/JS suite entries).
- **protobuf** is official **libprotobuf** + protoc-generated stubs from `schemas/v2/protobuf/benchmark_v2.proto` (requires `cpp/scripts/setup-protobuf-sysroot.sh`). Domain→Message conversion is untimed (`prepare` / `to_domain`).
- **capnproto** follows the same split: `prepare` fills a reused `MallocMessageBuilder`; the timer covers `messageToFlatArray` / `writeMessage` and reader setup; `to_domain` walks fields into suite structs. That matches libprotobuf and the [timing contract](../analysis/TIMING_HONESTY.md).
- **protobuf-wire** is the previous in-tree proto3 field-tag codec (no libprotobuf); kept for comparison when the sysroot is absent or for wire-only baselines.
- **flatbuffers** blob-root path embeds suite payload via `FlatBufferBuilder` (typed tables generated when `flatc` runs). The columnar type ids (`table`, `table_project`, `nested_table`, `signal`) are hand-built in the same slots as the Python FlatBuffers builder; they are not a shared `.fbs`.
- **arrow-ipc**, **parquet**, **parquet-uncompressed**, **orc**, and **orc-uncompressed** require Arrow 25.0.1 via `ARROW_ROOT` (prebuilt `libarrow` / `libparquet`, not FetchContent). ORC symbols live in `libarrow`. Column conversion and the SBE flyweight fill are inside timed `serialize_bytes`. `table_project` reads only `f_float_0` (IPC `included_fields`, Parquet leaf column 0, ORC `Read({"f_float_0"})`). Stream is **adapted**. Columnar configs are bytes only. These rows have no compliance decoder.
- **parquet** sets `Compression::SNAPPY`. On Arrow 25.0.1 the C++ writer default is **UNCOMPRESSED**, so the uncompressed twin is a separate row.
- **orc** sets `Compression::GZIP`. The Arrow ORC adapter default is **UNCOMPRESSED**; the adapter stores `GZIP` as ORC ZLIB. **orc-uncompressed** leaves compression off.
- **sbe** is SBE 1.40.2 header-only codecs vendored from `schemas/v2/sbe/signal.xml`. It supports `table`, `table_project`, and `signal`, and returns false for `nested_table`.
- Stream mode is **native** where the library exposes streams/buffers and the benchmark runner uses them (`VecOutStream`/`VecInStream`, Cap’n Proto `writeMessage`, msgpack packer/unpacker, etc.); others are **adapted** (stream path = bytes path).
- First CMake configure downloads pinned deps into `cpp/third_party/` (network required once).

Also: [`cpp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=cpp&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

## Design choices

1. **Prepare outside the loop** — DOM trees, packers, flexbuffers builders, domain→wire convert.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print JSON.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **C++20** — ArduinoJson v7 / zpp_bits / modern `std::variant` fixtures.
