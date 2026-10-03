# C++ third-party pin list

Fetched by CMake `FetchContent` into `cpp/third_party/` (gitignored except this file).

| Library | Tag / version | Role |
|---------|---------------|------|
| nlohmann/json | v3.12.0 | JSON + MessagePack/CBOR/UBJSON/BSON binary |
| glaze | v2.9.5 | Fast struct JSON (last C++20 release; v3+ needs C++23) |
| RapidJSON | v1.1.0 | JSON DOM/SAX |
| simdjson | v3.10.1 | SIMD JSON parse |
| ArduinoJson | v7.4.3 | Embedded/IoT JSON |
| yyjson | 0.10.0 | C JSON (dual C/C++) |
| msgpack-c (cpp) | cpp-6.1.1 | MessagePack C++ API |
| cereal | v1.3.2 | C++ binary archives |
| bitsery | v5.2.4 | Binary schema codec |
| zpp_bits | v4.4.25 | Ultra-fast binary |
| YAS | 7.1.0 | Ultra-fast binary archives |
| Cista++ | v0.15 | Offset / zero-copy oriented binary |
| jsoncons | v0.177.0 | CBOR / BSON / MessagePack |
| flatbuffers | v24.3.25 | FlatBuffers + FlexBuffers |

Official Protobuf C++ (local sysroot, not FetchContent):

| Artifact | Version | How |
|----------|---------|-----|
| libprotobuf + protoc | 3.12.4 (Ubuntu jammy debs) | `cpp/scripts/setup-protobuf-sysroot.sh` → `cpp/third_party/protobuf-sysroot/` |

In-tree codecs (suite schema wire, not third-party pins):

| Codec | Spec | Notes |
|-------|------|-------|
| protobuf-wire | proto3 wire | `schemas/v2/protobuf/benchmark_v2.proto` field tags (no libprotobuf) |
| avro | Avro binary 1.x | zigzag/varint records + array blocks (schema-driven) |
| custom_binary | harness | length-prefixed baseline |

| Cap'n Proto | v1.0.2 | Optional (`BENCH_CPP_CAPNP=ON`, default ON when configured) |
| Boost.Serialization | system | Optional (`libboost-serialization-dev`) |
| avro-c | monorepo `c/third_party` | Optional if C deps built (`avro_c` codec) |

Apache Arrow C++ is not fetched by CMake. When `ARROW_ROOT` (CMake variable or environment) points at a prebuilt prefix with `include/arrow/api.h` and `libarrow.so`, the columnar rows link that package. This tree uses the Apache Arrow apt packages for Ubuntu jammy, `libarrow-dev` / `libparquet-dev` 25.0.1-1 (Arrow 25.0.1), plus the thrift shared library those packages pull in. ORC is inside `libarrow` (`ARROW_ORC`). If the prefix is absent, configure still succeeds and the arrow/parquet/orc rows are skipped. On this 25.0.1 build the Parquet writer default and the ORC adapter `WriteOptions` default are both UNCOMPRESSED. The `parquet` row sets Snappy and the `orc` row sets Arrow `GZIP` (stored as ORC ZLIB) so those names are not a second copy of the uncompressed rows.

| Artifact | Version | How |
|----------|---------|-----|
| libarrow + libparquet (ORC in libarrow) | 25.0.1 (jammy `libarrow-dev` / `libparquet-dev` 25.0.1-1) | `-DARROW_ROOT=` prebuilt prefix, not FetchContent |

SBE codecs are vendored header-only output of sbe-tool, generated from `schemas/v2/sbe/signal.xml`. `nested_table` is not in that schema.

| Artifact | Version | How |
|----------|---------|-----|
| simple-binary-encoding C++ codecs | 1.40.2 | vendored under `cpp/gen/sbe/` (`MessageHeader.h`, `Signal.h`, `Table.h`) |
