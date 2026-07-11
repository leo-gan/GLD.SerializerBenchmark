# C++

C++ serialization spans **header-only JSON** (nlohmann, RapidJSON, ArduinoJson), **SIMD parse** (simdjson), **C libraries callable from C++** (yyjson), **schemaless binary** (MessagePack, cereal, bitsery, zpp_bits, CBOR/BSON via jsoncons), and **schema / zero-copy** families (Protobuf wire, FlatBuffers, FlexBuffers).

## Harness

- Directory: `cpp/` (repository root)
- Output: monorepo `logs/cpp/YYYY-MM-DD-HHMMSS.csv` (`Language=cpp`, times in **nanoseconds**)
- Runner: `cpp/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Build: CMake **C++20**, deps via `FetchContent` → `cpp/third_party/` (pins in [`cpp/third_party/VERSIONS.md`](../../cpp/third_party/VERSIONS.md))
- Registration: [`cpp/src/register.cpp`](../../cpp/src/register.cpp)

## Serializers (23)

| Serializer | Category | Library | Optimal call path | Notes |
|------------|----------|---------|-------------------|-------|
| nlohmann_json | JSON | nlohmann/json | `dump` / `parse` (compact) | De-facto C++ JSON |
| rapidjson | JSON | Tencent/rapidjson | `Writer` + `Document::Parse` | SAX/DOM hot path |
| simdjson | JSON | simdjson | `dom::parser::parse` | Ser = prepared minified JSON |
| arduinojson | JSON | ArduinoJson | `serializeJson` / `deserializeJson` | Embedded/IoT |
| yyjson | JSON | yyjson | `yyjson_mut_write` / `yyjson_read` | **Also in C suite** |
| msgpack | Binary | msgpack-c (C++ API) | `packer` + `sbuffer` / `unpack` | Official C++ API |
| nlohmann_msgpack | Binary | nlohmann/json | `to_msgpack` / `from_msgpack` | Multi-format nlohmann |
| nlohmann_cbor | Binary | nlohmann/json | `to_cbor` / `from_cbor` | IETF CBOR |
| nlohmann_ubjson | Binary | nlohmann/json | `to_ubjson` / `from_ubjson` | UBJSON |
| nlohmann_bson | Binary | nlohmann/json | `to_bson` / `from_bson` | BSON (object root) |
| cereal | Binary | cereal | `BinaryOutput/InputArchive` | C++-native archives |
| bitsery | Binary | bitsery | serializer `object`/`container` | Explicit schema |
| zpp_bits | Binary | zpp_bits | `zpp::bits::out` / `in` | Compile-time binary |
| yas | Binary | niXman/yas | `yas::save/load` `mem\|binary` | Top-tier microbench staple |
| cista | Binary | Cista++ | `cista::serialize` / `deserialize` | Offset graphs; convert in prepare |
| jsoncons_cbor | Binary | jsoncons | `cbor::encode/decode` | DOM multi-format |
| jsoncons_bson | Binary | jsoncons | `bson::encode/decode` | Document binary |
| jsoncons_msgpack | Binary | jsoncons | `msgpack::encode/decode` | DOM MessagePack |
| custom_binary | Binary | harness | length-prefixed fields | Baseline |
| protobuf | Schema | suite wire | proto3 field tags | Shared `.proto` field numbers |
| avro | Schema | suite avro-binary | zigzag/varint + array blocks | **Avro binary encoding** |
| flexbuffers | Schema | flatbuffers | `flexbuffers::Builder` / `GetRoot` | Schemaless FB family |
| flatbuffers | Schema | flatbuffers | `FlatBufferBuilder` | C++ primary; C uses **flatcc** |

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

| Concern | C harness (`c/`) | C++ harness (`cpp/`) |
|---------|------------------|----------------------|
| Language id | `c` | `cpp` |
| Object model | C structs + function pointers | C++20 structs + virtual `ISerializer` |
| JSON focus | cJSON, yyjson, jansson, parson, json-c | nlohmann, RapidJSON, simdjson, arduinojson, yyjson |
| MessagePack | mpack, msgpack-c **C API** | msgpack-c **C++ API** (`msgpack.hpp`) |
| CBOR | tinycbor, libcbor, QCBOR, zcbor | jsoncons CBOR |
| Protobuf | nanopb, protobuf-c, in-tree wire | suite proto3 wire (same field tags as `.proto`) |
| FlatBuffers | **flatcc** (C) | **google/flatbuffers** (C++) |

### Libraries that work for **both** C and C++

Some projects are C libraries with a pure C API. They are valid from C++ via `extern "C"` includes. The suite registers them carefully:

1. **yyjson** (registered in **both** harnesses)
   - **Why:** Written in C, ships `yyjson.h` with C linkage; C++ can call it without a separate C++ port.
   - **How:** C++ includes `yyjson.h` and uses `yyjson_read` / `yyjson_mut_write` (same recommended APIs as the C harness).
   - **Example:**
     ```cpp
     #include <yyjson.h>
     yyjson_doc* doc = yyjson_read(ptr, len, 0);
     char* out = yyjson_write(doc, 0, &out_len);
     ```
     vs C harness `ser_yyjson.c` with the same calls.

2. **msgpack-c** (related but **not** the same registration)
   - **Why:** One repository provides **two** APIs: C (`msgpack.h`) and C++ (`msgpack.hpp`).
   - **How:** C suite uses pack/unpack C functions; C++ suite uses `msgpack::packer` / `msgpack::unpack`.
   - **Wire format:** Compatible MessagePack; **call path and type mapping differ**.

3. **Protobuf family** (shared schema, different runtimes)
   - **Why:** The suite `.proto` is language-agnostic; C and C++ use different encoders for the **same field numbers**.
   - **How:** C → nanopb / protobuf-c; C++ → proto3 wire codec aligned with `schemas/v2/protobuf/benchmark_v2.proto`.
   - **Example field:** `Message.f_int32 = 2` is wire tag `(2<<3)|0` in both.

4. **FlatBuffers family** (shared idea, different codegens)
   - **Why:** Google FlatBuffers is C++-first; **flatcc** is the maintained C implementation.
   - **How:** C harness → flatcc builder/reader; C++ harness → `flatbuffers::FlatBufferBuilder` (+ FlexBuffers).
   - **Not interchangeable binaries** without matching schema/codegen.

5. **Avro family**
   - **Why:** Same **Avro binary encoding** (zigzag ints, length-prefixed strings, array blocks).
   - **How:** C harness → **avro-c**; C++ harness → in-tree Avro binary codec for suite types (Apache avro-cpp is heavy to FetchContent; wire follows Avro 1.x binary).
   - **Example:** `string` = zigzag/`long` length + bytes; arrays end with a zero count block.

6. **Not dual-registered (C-only or C++-only by design)**
   - **C-only in suite:** cJSON, jansson, parson, json-c, mpack, tinycbor, QCBOR, libbson, nanopb, flatcc, avro-c, zcbor.
   - **C++-only in suite:** nlohmann, RapidJSON, simdjson, arduinojson, cereal, bitsery, zpp_bits, jsoncons, google flatbuffers C++ API.

**Rule of thumb:** If a library is **pure C** and already measured under `Language=c`, re-registering under C++ only makes sense when the C++ call path is a first-class usage mode (yyjson) or when the **API surface differs** (msgpack C vs C++). Do not treat C and C++ rows as interchangeable runtimes for ranking.

## Suite fixtures

Type ids: `message`, `document`, `telemetry`, `strings`, `event`.

## Caveats

- **simdjson** is optimized for parse; serialize is prepared minified JSON (same honesty as Rust/JS suite entries).
- **protobuf** uses an in-tree proto3 wire codec for the suite schema (standard tags), not a full `libprotobuf` link — field layout matches `schemas/v2/protobuf/benchmark_v2.proto`.
- **flatbuffers** blob-root path embeds suite payload via `FlatBufferBuilder` (typed tables generated when `flatc` runs).
- Stream mode is **native** where the library exposes streams/buffers naturally; others are **adapted** bytes+buffer.
- First CMake configure downloads pinned deps into `cpp/third_party/` (network required once).

Also: [`cpp/README.md`](../../cpp/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Design choices

1. **Prepare outside the loop** — DOM trees, packers, flexbuffers builders, domain→wire convert.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print JSON.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **C++20** — ArduinoJson v7 / zpp_bits / modern `std::variant` fixtures.
