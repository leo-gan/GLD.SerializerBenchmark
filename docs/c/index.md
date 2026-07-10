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
| cJSON | JSON | `cJSON_PrintPreallocated` / `cJSON_ParseWithLength` | no print malloc; length-aware parse |
| yyjson | JSON | `yyjson_mut_write` / `yyjson_read` | recommended export + non-insitu read |
| jansson | JSON | `json_dumpb` / `json_loadb` | buffer dump; length-aware load |
| parson | JSON | `json_serialize_to_buffer` / `json_parse_string` | buffer serialize; symbol-prefixed vs jansson |
| json-c | JSON | `json_object_to_json_string_length` / `json_tokener_parse_ex` | length without second strlen |
| mpack | Binary | `mpack_writer_*` / `mpack_tree_*` | **native field maps** (fixed buffer writer) |
| msgpack-c | Binary | `msgpack_pack_*` + fixed write cb / `msgpack_unpack_*` | **native maps**; no sbuffer realloc |
| tinycbor | Binary | `cbor_encoder_*` / `cbor_value_map_find_value` | **native CBOR maps** (prefixed) |
| cbor-encode | Binary | `cbor_serialize` / `cbor_load` | **native** libcbor DOM → caller buffer |
| qcbor | Binary | `QCBOREncode_*` / spiffy `Get*InMapSZ` | **native maps** |
| ubj | Binary | in-tree UBJSON map codec | kind + payload bytes (minimal) |
| libbson | Binary | `bson_append_*` / `bson_iter_*` | **native documents** |
| custom-binary | Binary | hand-packed structs | baseline (not a third-party lib) |
| nanopb | Schema | `pb_ostream_from_buffer` + `pb_encode_tag` / `pb_istream` decode | real stream API (not unused link) |
| protobuf-c | Schema | standard protobuf wire (`fixture_pb_full.h`) | shared field layout with upb |
| upb | Schema | standard protobuf wire | **in-tree wire codec** (Google upb not linked) |
| flatcc | Schema | reused `flatcc_builder_*` + table reader | builder reset; payload vector for fidelity |
| avro-c | Schema | cached `avro_value_iface_t` + `avro_value_write/read` | iface built once in `prepare` |
| zcbor | Schema | `zcbor_map_*_encode/decode` | **native structured maps** |

Pins: [`c/third_party/VERSIONS.md`](../../c/third_party/VERSIONS.md).

## Caveats

- **Real APIs only:** a serializer is registered only when its library is linked (see CMake configure log `serializer: … REAL`).
- **Symbol prefixing:** `parson` and `tinycbor` are linked with renamed symbols so they co-exist with `jansson` and `libcbor`.
- Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.
- **Full nested fidelity:** JSON, mpack, msgpack-c, tinycbor, libcbor (`cbor-encode`), qcbor, libbson, zcbor, and nanopb encode suite fixtures with **library-native field structure** where implemented.
- **Still payload-wrapped:** `ubj`, `flatcc`, and `avro-c` may keep a compact kind + binary payload (or builder vector) without full schema codegen. Avro and flatcc still apply cached iface / reused builder call paths.
- **`nanopb` vs `protobuf-c` / `upb`:** nanopb uses real `pb_ostream`/`pb_istream` helpers. `protobuf-c` and `upb` share the in-tree wire codec; Google upb is not linked.

## Tests

```bash
cmake -S c -B c/build -DCMAKE_BUILD_TYPE=Release
cmake --build c/build --target c_serializer_tests
./c/build/c_serializer_tests
```

Round-trip + anti-opaque-payload + determinism checks cover all registered serializers.

Also: [`c/README.md`](../../c/README.md). [Serialization Categories](../analysis/serialization_categories.md).
