# C

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs). The harness normalizes fixtures into C structs, then times library-specific encode/decode.

## Harness

- `c/` (repository root)
- Logs: `logs/c/YYYY-MM-DD-HHMMSS.csv`
- Build: CMake, C11
- Deps: `c/scripts/fetch-and-build-deps.sh` (vendors + prebuilds under `c/third_party/`)
- Registration: [`c/src/register_serializers.c`](../../c/src/register_serializers.c) + `c/src/serializers/ser_*.c`

## Serializers (19)

| Name | Category | Real optimal API | Notes |
|------|----------|------------------|-------|
| cJSON | JSON | `cJSON_PrintUnformatted` / `cJSON_Parse` | vendored |
| yyjson | JSON | `yyjson_mut_write` / `yyjson_read` | vendored |
| jansson | JSON | `json_dumps` / `json_loads` | vendored build |
| parson | JSON | `json_serialize_to_string` / `json_parse_string` | symbol-prefixed vs jansson |
| json-c | JSON | `json_object_to_json_string_ext` / `json_tokener_parse` | system `libjson-c` |
| mpack | Binary | `mpack_writer_*` / `mpack_tree_*` | ludocode/mpack |
| msgpack-c | Binary | `msgpack_pack_*` / `msgpack_unpack_*` | official C runtime |
| tinycbor | Binary | `cbor_encoder_*` / `cbor_value_*` | symbol-prefixed vs libcbor |
| cbor-encode | Binary | `cbor_serialize_alloc` / `cbor_load` | libcbor |
| qcbor | Binary | `QCBOREncode_*` / `QCBORDecode_*` | QCBOR + spiffy decode |
| ubj | Binary | in-tree UBJSON map codec | spec type markers |
| libbson | Binary | `bson_append_*` / `bson_iter_*` | mongo-c-driver libbson |
| custom-binary | Binary | hand-packed structs | baseline (not a third-party lib) |
| nanopb | Schema | `pb_ostream` / `pb_istream` field tags | nanopb streams |
| protobuf-c | Schema | standard protobuf wire + protobuf-c runtime | shared field layout with nanopb/upb |
| upb | Schema | standard protobuf wire | **in-tree wire codec** (Google upb not linked; Bazel-heavy) |
| flatcc | Schema | `flatcc_builder_*` + table reader | FlatBuffers binary |
| avro-c | Schema | `avro_value_write` / `avro_value_read` | Apache Avro C |
| zcbor | Schema | `zcbor_map_*_encode/decode` | Nordic zcbor |

Pins: [`c/third_party/VERSIONS.md`](../../c/third_party/VERSIONS.md).

## Caveats

- **Real APIs only:** a serializer is registered only when its library is linked (see CMake configure log `serializer: … REAL`).
- **Symbol prefixing:** `parson` and `tinycbor` are linked with renamed symbols so they co-exist with `jansson` and `libcbor`.
- **Full nested fidelity:** JSON libs encode Person passport/police, Telemetry measurements, and EDI claims/lines. `nanopb` / `protobuf-c` / `upb` share a full protobuf-style wire (`fixture_pb_full.h`). Map-style binary codecs and `flatcc` / `avro-c` / `zcbor` carry a **full** `bin_write_fixture` payload (including EDI claims) inside the library’s native map/blob type so strengthened `fidelity_fx` passes.
- **`upb` name:** encodes standard protobuf binary for the harness field layout; it is **not** linked against Google’s upb (follow-up if a CMake-friendly upb package is adopted). C++ libraries are out of scope (separate language later).
- ObjectGraph is not supported.

Also: [`c/README.md`](../../c/README.md). [Serialization Categories](../analysis/serialization_categories.md).
