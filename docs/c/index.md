# C

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs). The benchmark runner uses **Data Model v2 only** (`message` · `document` · `telemetry` · `strings` · `event`).

## Benchmark runner

- `c/` (repository root)
- Logs: `logs/c/YYYY-MM-DD-HHMMSS.csv`
- Build: CMake, C11 (+ C++17 for Google libprotobuf)
- Deps: `c/scripts/fetch-and-build-deps.sh`; Google protobuf: `cpp/scripts/setup-protobuf-sysroot.sh`
- Registration: [`c/src/register_serializers.c`](../../c/src/register_serializers.c)
- **Domain shape:** map-style codecs use a single visitor in [`c/src/v2_codec.c`](../../c/src/v2_codec.c) (`v2_write_fixture` / `v2_read_fixture`). Wrappers implement library ops only—they do not hard-code V2 field graphs.

## Serializers (20)

| Name | Category | Timed path (what the row measures) |
|------|----------|-------------------------------------|
| cJSON, yyjson, jansson, parson, json-c | JSON | Library DOM build + print / parse via visitor ops |
| mpack, msgpack-c | Binary | Fixed-buffer map pack + tree/object unpack via visitor ops |
| tinycbor, cbor-encode (libcbor), qcbor, zcbor | Binary/schema | Native CBOR map encode via visitor ops; decode via tinycbor map walker (standard CBOR interop) where noted |
| libbson | Binary | `bson_append_*` / `bson_iter_*` via visitor ops |
| ubj | Binary | In-tree UBJSON markers around suite V2 binary payload (`bin_*`) |
| custom-binary | Binary | Suite length-prefixed V2 baseline (`bin_write_fixture` / `bin_read_fixture`) |
| **protobuf** | Schema | **Google libprotobuf** `SerializeToArray` / `ParseFromArray` on generated `benchmark_v2.proto` messages |
| nanopb, protobuf-c, protobuf-wire | Schema | Shared in-tree **proto3 wire** for V2 (`fixture_pb_v2.h`, same field tags as `schemas/v2/protobuf/benchmark_v2.proto`). Log names stay separate for historical comparison; **not** full nanopb stream codegen, protoc-gen-c descriptors, or Google upb. |
| flatcc, avro-c | Schema | Real flatcc builder / avro-c iface write-read wrapping V2 payload bytes |

Pins: [`c/third_party/VERSIONS.md`](../../c/third_party/VERSIONS.md).

### Caveats

- **Visitor (map codecs):** JSON / MessagePack / CBOR / BSON serializers only implement library primitives; field layout lives in `v2_codec.c`.
- **Protobuf family honesty:** the official **Google** row is `protobuf` (libprotobuf + sysroot). `nanopb` / `protobuf-c` / `protobuf-wire` currently time the shared `fixture_pb_v2` wire codec (domain encode/decode), not each library’s full generated-message stack. Do not read those three as “full library codegen benchmarks.”
- **Payload-wrapped:** `ubj`, `flatcc`, and `avro-c` keep kind + binary payload (or builder vector) without full multi-type schema codegen.
- **Symbol prefixing:** `parson` and `tinycbor` are linked with renamed symbols so they co-exist with `jansson` and `libcbor`.
- A serializer is registered only when its library is linked (CMake configure log `serializer: … REAL`).

## Suite types

`message`, `document`, `telemetry`, `strings`, `event` (see [Test Data](../analysis/test_data_configuration.md)).

## Tests

```bash
cmake -S c -B c/build -DCMAKE_BUILD_TYPE=Release
cmake --build c/build --target c_serializer_tests
./c/build/c_serializer_tests
```

Also: [`c/README.md`](../../c/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Stream honesty

Stream mode uses an in-memory `FILE*` (`fmemopen`) wrapper around full encode/decode buffers — **`StreamMode=adapted`** for every stream row. It is not a per-library incremental stream API. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).

