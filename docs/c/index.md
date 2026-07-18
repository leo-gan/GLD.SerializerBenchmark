# C

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs). The harness uses **Data Model v2 only** (`message` · `document` · `telemetry` · `strings` · `event`).

## Harness

- `c/` (repository root)
- Logs: `logs/c/YYYY-MM-DD-HHMMSS.csv`
- Build: CMake, C11 (+ C++17 for Google libprotobuf)
- Deps: `c/scripts/fetch-and-build-deps.sh`; Google protobuf: `cpp/scripts/setup-protobuf-sysroot.sh`
- Registration: [`c/src/register_serializers.c`](../../c/src/register_serializers.c)

## Serializers (20)

| Name | Category | Notes |
|------|----------|-------|
| cJSON | JSON | Real cJSON encode/decode of V2 field graphs |
| yyjson, jansson, parson, json-c | JSON | V2 domain; some still share suite binary envelope (native field maps may lag) |
| mpack, msgpack-c, tinycbor, cbor-encode, qcbor, ubj, libbson | Binary | V2 domain payloads |
| custom-binary | Binary | Suite length-prefixed V2 baseline |
| **protobuf** | Schema | **Google libprotobuf** + `schemas/v2/protobuf/benchmark_v2.proto` |
| nanopb | Schema | Real nanopb stream API for `message`; other types via suite envelope |
| protobuf-c, protobuf-wire | Schema | V2 domain; suite wire helper (not full protoc-gen-c / Google upb) |
| flatcc, avro-c, zcbor | Schema | V2 domain |

## Suite types

Only: `message`, `document`, `telemetry`, `strings`, `event`.  
**Removed:** Person, SimpleObject, Integer, EDI_835, ObjectGraph, and all V1 kinds.

## Tests

```bash
cmake -S c -B c/build -DCMAKE_BUILD_TYPE=Release
cmake --build c/build --target c_serializer_tests
./c/build/c_serializer_tests
```
