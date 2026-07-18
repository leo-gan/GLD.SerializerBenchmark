# C++ third-party pin list

Fetched by CMake `FetchContent` into `cpp/third_party/` (gitignored except this file).

| Library | Tag / version | Role |
|---------|---------------|------|
| nlohmann/json | v3.11.3 | JSON + MessagePack/CBOR/UBJSON/BSON binary |
| RapidJSON | v1.1.0 | JSON DOM/SAX |
| simdjson | v3.10.1 | SIMD JSON parse |
| ArduinoJson | v7.2.1 | Embedded/IoT JSON |
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
