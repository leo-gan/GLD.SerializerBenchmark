---
title: "C++"
---

# C++

C++ serialization spans header-only JSON libraries (`nlohmann/json`, `RapidJSON`, `ArduinoJson`, `glaze`), SIMD parsers (`simdjson`), pure-C codecs called via C linkage (`yyjson`), compile-time binary archives (`bitsery`, `zpp_bits`, `yas`, `cereal`, `cista`), IDL/zero-copy runtimes (`libprotobuf`, `FlatBuffers`, `Cap'n Proto`, `SBE`, `Dagr`), and native Apache Arrow columnar writers.

## Runtime & Environment

The C++ runner compiles C++20 code to native machine code using CMake in the Release configuration (`g++` or `clang++`). Memory management follows RAII and explicit heap allocation with no virtual machine or garbage collector; compiler optimization flags and allocation patterns govern throughput. Third-party dependencies are pinned and downloaded via CMake `FetchContent` into `cpp/third_party/` (see [`cpp/third_party/VERSIONS.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/third_party/VERSIONS.md)). The language is specified by ISO/IEC 14882 (C++20 draft [N4861](https://timsong-cpp.github.io/cppwp/n4861/); reference at [cppreference](https://en.cppreference.com/w/cpp)).

| Property | Configuration |
|---|---|
| Language / spec | ISO/IEC 14882 (C++20 required) |
| Build & toolchain | CMake 3.16+ Release (`g++` / `clang++`); `FetchContent` deps; protobuf sysroot via `cpp/scripts/setup-protobuf-sysroot.sh`; optional `-DARROW_ROOT=` (Arrow 25.0.1) |
| Memory model | RAII and manual heap management; no garbage collector |
| Runner & logs | `cpp/scripts/run-benchmarks.sh` → `logs/cpp/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`cpp/src/register.cpp`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/register.cpp) |
| Data sets | `suite`, `columnar`, `graph`, `array`, `tensor` |

## Registered Serializers

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [arduinojson](https://github.com/bblanchon/ArduinoJson) | `json` | `suite` | `native` | Fixed-capacity `serializeJson` / `deserializeJson` |
| [arrow-ipc](https://arrow.apache.org/docs/cpp/ipc.html) | `arrow` | `columnar` | `adapted` | Arrow C++ 25.0.1 `ipc::MakeStreamWriter` (optional `ARROW_ROOT`); batch built in `serialize`; `table_project` uses `included_fields` |
| [avro](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/serializers/ser_avro.cpp) | `avro` | `suite`, `columnar` | `adapted` | In-tree Avro 1.x binary codec (zigzag/varint + array blocks) |
| [avro_c](https://github.com/apache/avro) | `avro` | `suite` | `adapted` | Official `avro-c` library called from C++ with cached iface |
| [bitsery](https://github.com/fraillt/bitsery) | `custom` | `suite` | `adapted` | Explicit-schema binary `object` / `container` into reused buffer |
| [boost_serialization](https://github.com/boostorg/serialization) | `custom` | `suite` (optional) | `native` | `boost::archive::binary_oarchive` / `binary_iarchive` (registered when system Boost is installed) |
| [capnproto](https://github.com/capnproto/capnproto) | `capnp` | `suite` | `native` | `messageToFlatArray` / `writeMessage` on prepared `MallocMessageBuilder`; `to_domain` untimed |
| [cereal](https://github.com/USCiLab/cereal) | `custom` | `suite` | `native` | `BinaryOutputArchive` / `BinaryInputArchive` on `ostream` / `istream` |
| [cista](https://github.com/felixguendling/cista) | `custom` | `suite` | `adapted` | Offset-based `cista::serialize` / `deserialize`; domain conversion in `prepare` |
| [custom_binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/serializers/ser_binary.cpp) | `custom` | `suite` | `adapted` | In-tree length-prefixed little-endian control baseline |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Generated arena in `prepare`; timed `Arena::serialize` + lazy reader→domain |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct value structs in `prepare`; timed `direct::build` + lazy reader→domain |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct value structs in `prepare`; timed `direct::build` + lazy reader→domain |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Generated arena in `prepare`; timed `Arena::serialize` + lazy reader→domain |
| [flatbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite`, `columnar` | `adapted` | Official C++ `FlatBufferBuilder`; columnar types hand-built in matching slots |
| [flexbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite` | `adapted` | Schemaless `flexbuffers::Builder` / `GetRoot` |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | Apache Fory `FORY_STRUCT` native binary mode on registered structs |
| [glaze](https://github.com/stephenberry/glaze) | `json` | `suite` | `adapted` | Compile-time reflection `glz::write_json` / `glz::read_json` (pinned v2.9.5 for C++20) |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-cpp) | `kiln` | `suite`, `tensor` | `adapted` | Positional `Writer::encode` / `decode`; `tensor_view` borrows payload |
| [highfive](https://github.com/highfive-devs/highfive) | `hdf5` | `array` | `adapted` | C++ HighFive wrapper over `libhdf5`; hyperslab read for `grid_window` |
| [jsoncons_bson](https://github.com/danielaparker/jsoncons) | `bson` | `suite` | `native` | `jsoncons::bson::encode_bson` / `decode_bson` on domain structs |
| [jsoncons_cbor](https://github.com/danielaparker/jsoncons) | `cbor` | `suite` | `native` | `jsoncons::cbor::encode_cbor` / `decode_cbor` on domain structs |
| [jsoncons_msgpack](https://github.com/danielaparker/jsoncons) | `msgpack` | `suite` | `native` | `jsoncons::msgpack::encode_msgpack` / `decode_msgpack` on domain structs |
| [msgpack](https://github.com/msgpack/msgpack-c) | `msgpack` | `suite` | `native` | Official `msgpack-c` C++ API (`msgpack::packer` / `msgpack::unpack`) |
| [nlohmann_bson](https://github.com/nlohmann/json) | `bson` | `suite` | `native` | `nlohmann::json::to_bson` / `from_bson` |
| [nlohmann_cbor](https://github.com/nlohmann/json) | `cbor` | `suite` | `native` | `nlohmann::json::to_cbor` / `from_cbor` |
| [nlohmann_json](https://github.com/nlohmann/json) | `json` | `suite`, `columnar` | `native` | `nlohmann::json::dump` / `parse` (`<<` / `parse(istream)` on stream) |
| [nlohmann_msgpack](https://github.com/nlohmann/json) | `msgpack` | `suite` | `native` | `nlohmann::json::to_msgpack` / `from_msgpack` |
| [nlohmann_ubjson](https://github.com/nlohmann/json) | `ubjson` | `suite` | `native` | `nlohmann::json::to_ubjson` / `from_ubjson` |
| [orc](https://arrow.apache.org/docs/cpp/orc.html) | `orc` | `columnar` | `adapted` | Arrow C++ 25.0.1 ORC adapter with `Compression::GZIP` (stored as ORC ZLIB); optional `ARROW_ROOT` |
| [orc-uncompressed](https://arrow.apache.org/docs/cpp/orc.html) | `orc` | `columnar` | `adapted` | Same ORC adapter with `Compression::UNCOMPRESSED` |
| [parquet](https://arrow.apache.org/docs/cpp/parquet.html) | `parquet` | `columnar` | `adapted` | Arrow C++ 25.0.1 `parquet::arrow::WriteTable` with `Compression::SNAPPY`; optional `ARROW_ROOT` |
| [parquet-uncompressed](https://arrow.apache.org/docs/cpp/parquet.html) | `parquet` | `columnar` | `adapted` | Same Parquet writer with `Compression::UNCOMPRESSED` |
| [protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite`, `columnar` | `adapted` | Official Google `libprotobuf` `SerializeToArray` / `ParseFromArray` (sysroot) |
| [protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/serializers/ser_schema.cpp) | `protobuf` | `suite` | `adapted` | In-tree proto3 field-tag codec matching `benchmark_v2.proto` |
| [rapidjson](https://github.com/Tencent/rapidjson) | `json` | `suite` | `native` | SAX `Writer` + `Document::Parse`; `OStreamWrapper` / `IStreamWrapper` on stream |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | `sbe` | `columnar` | `adapted` | Vendored SBE 1.40.2 flyweights (`cpp/gen/sbe/`); `nested_table` unsupported |
| [simdjson](https://github.com/simdjson/simdjson) | `json` | `suite` | `adapted` | Parse-only SIMD library: decode is `dom::parser::parse`; encode uses `nlohmann::json::dump` |
| [thrift](https://github.com/apache/thrift) | `thrift` | `suite` | `adapted` | In-tree `TBinaryProtocol` (field type+id + STOP) |
| [yaml-cpp](https://github.com/jbeder/yaml-cpp) | `yaml` | `suite` | `native` | Official `yaml-cpp` emitter and node parser |
| [yas](https://github.com/niXman/yas) | `custom` | `suite` | `adapted` | `yas::save` / `yas::load` (`mem \| binary`) |
| [yyjson](https://github.com/ibireme/yyjson) | `json` | `suite` | `adapted` | Pure-C `yyjson_mut_write` / `yyjson_read` via C++ call path |
| [zpp_bits](https://github.com/eyalz800/zpp_bits) | `custom` | `suite` | `adapted` | Compile-time template binary `zpp::bits::out` / `in` |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[arduinojson](https://github.com/bblanchon/ArduinoJson)** — ArduinoJson was written so microcontrollers and Arduino-class devices could speak JSON in a tiny RAM budget. The problem was desktop JSON libraries being far too large. It uses a fixed-capacity document model.
    - **[arrow-ipc](https://arrow.apache.org/docs/cpp/ipc.html)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times Arrow C++ 25.0.1 ipc::MakeStreamWriter into a buffer: the IPC stream inside the bytes API, not the Arrow file format. The record batch is built inside serialize_bytes. table_project sets IpcReadOptions.included_fields to f_float_0. The row is omitted when ARROW_ROOT is unset. No compliance decoder.
    - **[avro](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/serializers/ser_avro.cpp)** — Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.
    - **[avro_c](https://github.com/apache/avro)** — Apache Avro was created for Hadoop-era data: a compact binary encoding with the schema stored out of band so field names are not repeated. avro-c is the official C implementation of that encoding.
    - **[bitsery](https://github.com/fraillt/bitsery)** — bitsery is an explicit-schema binary serializer for C++. The problem was that many C++ binaries were either reflection-slow or ad-hoc. bitsery makes the schema the API (`object` / `container`).
    - **[boost_serialization](https://github.com/boostorg/serialization)** — Boost.Serialization is the classic C++ archive framework. It was created so C++ programs could persist object graphs portably across Boost archives. This row times the binary archive.
    - **[capnproto](https://github.com/capnproto/capnproto)** — Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.
    - **[cereal](https://github.com/USCiLab/cereal)** — cereal was created as a C++11 header-only archive library (binary, JSON, XML) in the Boost.Serialization design space, but simpler. The problem was Boost.Serialization's weight. cereal uses output/input archives on existing types.
    - **[cista](https://github.com/felixguendling/cista)** — Cista++ serializes C++ object graphs as offset-based, pointer-free images. The problem was that pointer graphs are not portable or mmap-friendly. Cista writes a relocatable layout.
    - **[custom_binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/serializers/ser_binary.cpp)** — This is the suite's length-prefixed V2 baseline, not a published format. It exists so every language has a simple binary control point: write fields with explicit lengths, read them back, no schema compiler.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type. The C++ code is header-only (`cpp/dagr_gen/`).
    - **[flatbuffers](https://github.com/google/flatbuffers)** — FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.
    - **[flexbuffers](https://github.com/google/flatbuffers)** — FlexBuffers is the schemaless cousin of FlatBuffers. It was created so you can have a FlatBuffers-family binary without compiling a schema. The same Google repository implements it.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses FORY_STRUCT with registered C++ structs and vectors in native mode.
    - **[glaze](https://github.com/stephenberry/glaze)** — glaze was created for extremely fast, reflection-based JSON (and other formats) on modern C++. The problem was that C++ JSON usually meant a DOM or hand-written macros. glaze maps structs directly with compile-time reflection.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-cpp)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[highfive](https://github.com/highfive-devs/highfive)** — HighFive is the header-only C++ API most scientific code uses for HDF5. This row times one contiguous float64 dataset named grid. grid_window reads an interior hyperslab. The buffer is the file. The row does not time the five suite types.
    - **[jsoncons_bson](https://github.com/danielaparker/jsoncons)**, **[jsoncons_cbor](https://github.com/danielaparker/jsoncons)**, **[jsoncons_msgpack](https://github.com/danielaparker/jsoncons)** — jsoncons is a C++ library for JSON and binary JSON-family formats (CBOR, BSON, MessagePack). It was written as a consistent, typed encode/decode toolkit rather than a single DOM.
        - `jsoncons_bson`: This row times jsoncons `bson::encode` / `decode`.
        - `jsoncons_cbor`: This row times jsoncons `cbor::encode` / `decode`.
        - `jsoncons_msgpack`: This row times jsoncons `msgpack::encode` / `decode`.
    - **[msgpack](https://github.com/msgpack/msgpack-c)** — msgpack-c is the official C/C++ implementation of MessagePack. MessagePack was created to be as small and fast as a binary format while staying as simple as JSON. The C library solves that with pack/unpack APIs (and a separate C++ API in the same repository).
    - **[nlohmann_bson](https://github.com/nlohmann/json)**, **[nlohmann_cbor](https://github.com/nlohmann/json)**, **[nlohmann_json](https://github.com/nlohmann/json)**, **[nlohmann_msgpack](https://github.com/nlohmann/json)**, **[nlohmann_ubjson](https://github.com/nlohmann/json)** — nlohmann/json is the de-facto modern C++ JSON library. It was created so C++ could use a JSON value type with an intuitive, STL-like API. The same library also maps that DOM to CBOR, MessagePack, BSON, and UBJSON.
        - `nlohmann_bson`: This row times `to_bson` / `from_bson`.
        - `nlohmann_cbor`: This row times `to_cbor` / `from_cbor`.
        - `nlohmann_msgpack`: This row times `to_msgpack` / `from_msgpack`.
        - `nlohmann_ubjson`: This row times `to_ubjson` / `from_ubjson`.
    - **[orc](https://arrow.apache.org/docs/cpp/orc.html)** — Apache ORC was created as a columnar file with stripe indexes for scans. Arrow C++ 25.0.1 ORC adapter WriteOptions default to UNCOMPRESSED, which is not the Apache ORC Zlib default, so this row sets Compression::GZIP. The adapter stores that value as ORC ZLIB. table_project calls Read of f_float_0. The batch is built inside serialize_bytes. Optional on ARROW_ROOT. No compliance decoder.
    - **[orc-uncompressed](https://arrow.apache.org/docs/cpp/orc.html)** — This is the same Arrow C++ ORC adapter as orc, with WriteOptions.compression set to UNCOMPRESSED. The name is the override. No compliance decoder.
    - **[parquet](https://arrow.apache.org/docs/cpp/parquet.html)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times Arrow C++ 25.0.1 parquet::arrow::WriteTable. WriterProperties on 25.0.1 default to UNCOMPRESSED, so this row sets Compression::SNAPPY. table_project reads leaf column 0. The batch is built inside serialize_bytes. Optional on ARROW_ROOT. No compliance decoder.
    - **[parquet-uncompressed](https://arrow.apache.org/docs/cpp/parquet.html)** — This is the same Arrow C++ Parquet writer as parquet, with WriterProperties compression set to UNCOMPRESSED. Encodings stay at the builder default. The name is the override. No compliance decoder.
    - **[protobuf](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/src/serializers/ser_schema.cpp)** — This row is the suite's in-tree proto3 tag reader/writer. It exists to measure the published Protocol Buffers encoding itself, without a particular vendor runtime. Field numbers match `schemas/v2/protobuf/benchmark_v2.proto`.
    - **[rapidjson](https://github.com/Tencent/rapidjson)** — RapidJSON was written at Tencent for high-performance JSON in C++ with SAX and DOM APIs. The problem was slow or awkward C++ JSON stacks. It became a standard hot-path parser/generator.
    - **[sbe](https://github.com/aeron-io/simple-binary-encoding)** — SBE (Simple Binary Encoding) was created for word-aligned financial messages: a fixed block, then repeating groups, then variable-length data. The problem was tag/length codecs that touch every field on the hot path. This row fills the sbe-tool 1.40.2 C++ flyweight inside serialize_bytes. It encodes table, table_project, and signal. nested_table is not an SBE body. The signal wire order is fixed fields, then the legs group, then symbol and venue. No compliance decoder.
    - **[simdjson](https://github.com/simdjson/simdjson)** — simdjson was created to parse JSON at near memory bandwidth using SIMD. The problem was that conventional parsers left most of the CPU unused. This suite times parse; serialize is prepared minified JSON.
    - **[thrift](https://github.com/apache/thrift)** — Apache Thrift was created at Facebook so many languages could share RPC and serialization from one IDL. The problem was hand-written cross-language services. Thrift solves it with a schema compiler and protocols such as TCompactProtocol.
    - **[yaml-cpp](https://github.com/jbeder/yaml-cpp)** — yaml-cpp is a YAML parser/emitter for C++. YAML exists as a human-friendly config language. yaml-cpp is the usual C++ implementation of that model.
    - **[yas](https://github.com/niXman/yas)** — YAS (Yet Another Serializer) is a high-performance C++ binary archive library. It was written as a microbenchmark staple: serialize structs with very little abstraction cost.
    - **[yyjson](https://github.com/ibireme/yyjson)** — yyjson was written for high-performance JSON in ANSI C: fast parse and print without giving up a usable DOM. The problem was that lightweight C parsers were slow, and fast parsers were often C++ or SAX-only. yyjson solves that with a compact C implementation and mutable/immutable document APIs.
    - **[zpp_bits](https://github.com/eyalz800/zpp_bits)** — zpp_bits is a compile-time binary serializer for modern C++. The problem was runtime reflection and verbose archive APIs. It uses template `out` / `in` over tuples and structs.

## Measurement Caveats

### C vs. C++ separation {#c-vs-c-clear-separation}

C (`c/`) and C++ (`cpp/`) are distinct benchmark runners with different object models (`struct` + function pointers vs. C++20 types + virtual `ISerializer`). Pure-C libraries are dual-registered in C++ only when the C++ call path is a primary usage mode (`yyjson`) or the upstream repository exposes a separate C++ API (`msgpack-c` C vs. `msgpack.hpp`; `flatcc` vs. `google/flatbuffers`).

### Library-specific constraints

- **`simdjson` encode asymmetry:** `simdjson` has no serializer; timed encode calls `nlohmann::json::dump` on a prepared DOM, while timed decode runs `simdjson::dom::parser::parse` followed by a DOM walk (see [4.12 C++: the `simdjson` wrapper](../theory/401/cpp-simdjson-wrapper.md)).
- **`glaze` C++20 pin:** Pinned to v2.9.5 because v3+ requires C++23; only JSON is registered.
- **Optional Arrow & Boost builds:** `arrow-ipc`, `parquet*`, and `orc*` require prebuilt Apache Arrow 25.0.1 via `-DARROW_ROOT=`; without it, those five rows are omitted while `sbe` and all other codecs still build. `boost_serialization` builds only when system Boost is present.
- **Columnar compression defaults:** Arrow C++ 25.0.1 defaults both Parquet and ORC writers to `UNCOMPRESSED`; the `parquet` row explicitly selects `SNAPPY` and `orc` explicitly selects `GZIP` (ORC ZLIB) to match cross-language suite defaults, with `*-uncompressed` rows measuring layout-only sizes. Row-to-column conversion and SBE flyweight filling run inside timed `serialize_bytes` per [Timing contract rule 8](../analysis/TIMING_HONESTY.md).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (C++)](../dashboard/index.html?lang=cpp&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (C++)](../dashboard/index.html#compliance)
- **Source-level analyses:** [C++: `Bitsery` vs. `YAS`](../analysis/call-sites/cpp-bitsery-vs-yas.md) · [4.12 C++: the `simdjson` wrapper](../theory/401/cpp-simdjson-wrapper.md)
- **Build & run guide:** [`cpp/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/cpp/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
