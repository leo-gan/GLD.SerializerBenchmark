# C

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs). The harness normalizes fixtures into C structs, then times library-specific encode/decode.

## Harness

- `c/` (repository root)
- Logs: `logs/c/YYYY-MM-DD-HHMMSS.csv`
- Build: CMake, C11
- Registration: [`c/src/register_serializers.c`](../../c/src/register_serializers.c)

## Serializers (12)

| Name | Category | Real optimal API (target) | Default build |
|------|----------|---------------------------|---------------|
| cbor-encode | Binary | `cbor_serialize_alloc` / `cbor_load` | tagged binary |
| cJSON | JSON | `cJSON_PrintUnformatted` / `cJSON_Parse` | minimal JSON |
| custom-binary | Binary | hand-packed C structs | direct struct dump |
| flatcc | Schema | `flatcc_builder_*` / verifier | tagged binary |
| jansson | JSON | `json_dumps` / `json_loads` | minimal JSON (or `-DHAS_JANSSON`) |
| mpack | Binary | `mpack_writer_*` / `mpack_tree_*` | tagged binary envelope |
| nanopb | Schema | `pb_encode` / `pb_decode` | field-1 protobuf-style |
| parson | JSON | `json_serialize_to_string` / `json_parse_string` | minimal JSON |
| protobuf-c | Schema | `protobuf_c_message_pack` / `unpack` | tagged binary |
| tinycbor | Binary | `cbor_encoder_*` / `cbor_value_*` | tagged binary |
| ubj | Binary | `ubjw_*` / `ubjr_*` | tagged binary |
| yyjson | JSON | `yyjson_mut_write` / `yyjson_read` | minimal JSON |

## Caveat

Default CI build uses **portable minimal codecs** labeled with real library names so the pipeline runs without distro packages. For paper results, vendor/link real libraries and replace `json_write_fixture` / envelope wrappers in `register_serializers.c` with real APIs.

Also: [`c/README.md`](../../c/README.md). [Serialization Categories](../analysis/serialization_categories.md).
