---
title: "C++"
---

C++
===

C++ serialization spans **header-only JSON** (nlohmann, RapidJSON, ArduinoJson), **SIMD parse** (simdjson), **C libraries callable from C++** (yyjson), **schemaless binary** (MessagePack, cereal, bitsery, zpp_bits, CBOR/BSON via jsoncons), and **schema / zero-copy** families (official **libprotobuf**, in-tree Protobuf wire, FlatBuffers, FlexBuffers).

## Benchmark runner

- Directory: `cpp/` (repository root)
- Output: monorepo `logs/cpp/YYYY-MM-DD-HHMMSS.csv` (`Language=cpp`, times in **nanoseconds**)
- Runner: `cpp/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Build: CMake **C++20**, deps via `FetchContent` → `cpp/third_party/` (pins in [`cpp/third_party/VERSIONS.md`](../../cpp/third_party/VERSIONS.md))
- Official Protobuf: `cpp/scripts/setup-protobuf-sysroot.sh` (libprotobuf 3.12 + protoc, no root install)
- Registration: [`cpp/src/register.cpp`](../../cpp/src/register.cpp)

## Serializers

| Serializer | Category | Library | Optimal call path | Notes |
|------------|----------|---------|-------------------|-------|
| arduinojson | JSON | ArduinoJson | `serializeJson` / `deserializeJson` (bytes + stream) | Embedded/IoT; **native stream** |
| avro | Schema | suite avro-binary | zigzag/varint + array blocks | **Avro binary encoding** |
| avro_c | Schema | avro-c | cached iface + value_write/read | **Real** Avro C lib from C++; stream adapted |
| bitsery | Binary | bitsery | serializer `object`/`container` | Explicit schema |
| boost_serialization | Binary | Boost.Serialization | binary_o/iarchive (bytes + stream) | Optional (system lib); **native stream** |
| capnproto | Schema | Cap'n Proto | flat array bytes; `writeMessage` / `InputStreamMessageReader` stream | Zero-copy schema; **native stream** |
| cereal | Binary | cereal | `BinaryOutput/InputArchive` on ostream/istream | C++-native archives; **native stream** |
| cista | Binary | Cista++ | `cista::serialize` / `deserialize` | Offset graphs; convert in prepare |
| custom_binary | Binary | harness | length-prefixed fields | Baseline; stream adapted |
| flatbuffers | Schema | flatbuffers | `FlatBufferBuilder` | C++ primary; C uses **flatcc** |
| flexbuffers | Schema | flatbuffers | `flexbuffers::Builder` / `GetRoot` | Schemaless FB family |
| jsoncons_bson | Binary | jsoncons | `bson::encode/decode` on domain structs | BSON document; **native stream** |
| jsoncons_cbor | Binary | jsoncons | `cbor::encode/decode` on domain structs | CBOR; **native stream** |
| jsoncons_msgpack | Binary | jsoncons | `msgpack::encode/decode` on domain structs | MessagePack; **native stream** |
| msgpack | Binary | msgpack-c (C++ API) | `packer` + `sbuffer` / `unpack`; stream packer + unpacker | Official C++ API; **native stream** |
| nlohmann_bson | Binary | nlohmann/json | `to_bson` / `from_bson` (+ ostream/istream) | BSON (object root); **native stream** |
| nlohmann_cbor | Binary | nlohmann/json | `to_cbor` / `from_cbor` (+ ostream/istream) | IETF CBOR; **native stream** |
| nlohmann_json | JSON | nlohmann/json | `dump` / `parse`; stream `<<` / `parse(istream)` | De-facto C++ JSON; **native stream** |
| nlohmann_msgpack | Binary | nlohmann/json | `to_msgpack` / `from_msgpack` (+ ostream/istream) | Multi-format nlohmann; **native stream** |
| nlohmann_ubjson | Binary | nlohmann/json | `to_ubjson` / `from_ubjson` (+ ostream/istream) | UBJSON; **native stream** |
| protobuf | Schema | **libprotobuf** (Google) | `SerializeToArray` / `ParseFromArray` on prepared messages | Official C++ runtime; sysroot via setup script |
| protobuf-wire | Schema | suite wire | proto3 field tags | In-tree codec; same field numbers as shared `.proto` |
| rapidjson | JSON | Tencent/rapidjson | `Writer` + `Document::Parse`; stream O/IStreamWrapper | SAX/DOM hot path; **native stream** |
| simdjson | JSON | simdjson | `dom::parser::parse` | Ser = prepared minified JSON; stream adapted |
| thrift | Schema | suite TBinaryProtocol | field type+id + STOP | Apache Thrift binary; stream adapted |
| yas | Binary | niXman/yas | `yas::save/load` `mem\|binary` | Top-tier microbench staple |
| yyjson | JSON | yyjson | `yyjson_mut_write` / `yyjson_read` | **Also in C suite**; stream adapted |
| zpp_bits | Binary | zpp_bits | `zpp::bits::out` / `in` | Compile-time binary |

### Call-path contract

```text
prepare(fixture)                 # untimed: DOM/maps, buffers, domain convert
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed (codec only)
  to_domain (if needed)          # untimed
  fidelity(expected, actual)     # untimed
```

## C vs C++ — clear separation

| Concern | C benchmark runner (`c/`) | C++ benchmark runner (`cpp/`) |
|---------|------------------|----------------------|
| CBOR | tinycbor, libcbor, QCBOR, zcbor | jsoncons CBOR |
| FlatBuffers | **flatcc** (C) | **google/flatbuffers** (C++) |
| JSON focus | cJSON, yyjson, jansson, parson, json-c | nlohmann, RapidJSON, simdjson, arduinojson, yyjson |
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
   - **C++-only in suite:** nlohmann, RapidJSON, simdjson, arduinojson, cereal, bitsery, zpp_bits, jsoncons, google flatbuffers C++ API.

**Rule of thumb:** If a library is **pure C** and already measured under `Language=c`, re-registering under C++ only makes sense when the C++ call path is a first-class usage mode (yyjson) or when the **API surface differs** (msgpack C vs C++). Do not treat C and C++ rows as interchangeable runtimes for ranking.

## Caveats

- **simdjson** is optimized for parse; serialize is prepared minified JSON (same honesty as Rust/JS suite entries).
- **protobuf** is official **libprotobuf** + protoc-generated stubs from `schemas/v2/protobuf/benchmark_v2.proto` (requires `cpp/scripts/setup-protobuf-sysroot.sh`). Domain→Message conversion is untimed (`prepare` / `to_domain`).
- **protobuf-wire** is the previous in-tree proto3 field-tag codec (no libprotobuf); kept for comparison when the sysroot is absent or for wire-only baselines.
- **flatbuffers** blob-root path embeds suite payload via `FlatBufferBuilder` (typed tables generated when `flatc` runs).
- Stream mode is **native** where the library exposes streams/buffers and the benchmark runner uses them (`VecOutStream`/`VecInStream`, Cap’n Proto `writeMessage`, msgpack packer/unpacker, etc.); others are **adapted** (stream path = bytes path).
- First CMake configure downloads pinned deps into `cpp/third_party/` (network required once).

Also: [`cpp/README.md`](../../cpp/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Design choices

1. **Prepare outside the loop** — DOM trees, packers, flexbuffers builders, domain→wire convert.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print JSON.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **C++20** — ArduinoJson v7 / zpp_bits / modern `std::variant` fixtures.
