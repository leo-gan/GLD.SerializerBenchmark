# C

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs). The harness uses **Data Model v2 only** (`message` · `document` · `telemetry` · `strings` · `event`).

## Harness

- `c/` (repository root)
- Logs: `logs/c/YYYY-MM-DD-HHMMSS.csv`
- Build: CMake, C11 (+ C++17 for Google libprotobuf)
- Deps: `c/scripts/fetch-and-build-deps.sh`; Google protobuf: `cpp/scripts/setup-protobuf-sysroot.sh`
- Registration: [`c/src/register_serializers.c`](../../c/src/register_serializers.c)

## Serializers (20)

All rows use **native library encode/decode APIs** on **Data Model v2** fixtures (`message` / `document` / `telemetry` / `strings` / `event`).

| Name | Category | Native timed path |
|------|----------|-------------------|
| cJSON, yyjson, jansson, parson, json-c | JSON | Library DOM build + print / parse |
| mpack, msgpack-c | Binary | Fixed-buffer map pack + tree/object unpack |
| tinycbor, cbor-encode (libcbor), qcbor, zcbor | Binary/schema | Native CBOR map encode; decode via tinycbor map walker (standard CBOR interop) where noted |
| libbson | Binary | `bson_append_*` / `bson_iter_*` |
| ubj | Binary | In-tree UBJSON markers around suite V2 binary payload |
| custom-binary | Binary | Suite length-prefixed V2 baseline (**this is** the native path) |
| **protobuf** | Schema | **Google libprotobuf** `SerializeToArray` / `ParseFromArray` on `benchmark_v2.proto` |
| nanopb | Schema | Real `pb_ostream` / field encode for all V2 types (proto3 tags) |
| protobuf-c, protobuf-wire | Schema | Standard **proto3 wire** for V2 (`fixture_pb_v2.h` / same field tags as shared `.proto`) |
| flatcc, avro-c | Schema | Real flatcc builder / avro-c iface write-read wrapping V2 payload bytes |

## Suite types

Only: `message`, `document`, `telemetry`, `strings`, `event`.  
**Removed:** Person, SimpleObject, Integer, EDI_835, ObjectGraph, and all V1 kinds.

## Tests

```bash
cmake -S c -B c/build -DCMAKE_BUILD_TYPE=Release
cmake --build c/build --target c_serializer_tests
./c/build/c_serializer_tests
```
