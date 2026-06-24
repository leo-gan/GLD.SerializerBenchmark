# C Tested Serializers

| Name | Category | Real optimal API (target) | Default build |
|------|----------|---------------------------|---------------|
| cJSON | JSON | `cJSON_PrintUnformatted` / `cJSON_Parse` | minimal JSON |
| yyjson | JSON | `yyjson_mut_write` / `yyjson_read` | minimal JSON |
| jansson | JSON | `json_dumps` / `json_loads` | minimal JSON (or `-DHAS_JANSSON`) |
| parson | JSON | `json_serialize_to_string` / `json_parse_string` | minimal JSON |
| mpack | Binary | `mpack_writer_*` / `mpack_tree_*` | tagged binary envelope |
| tinycbor | Binary | `cbor_encoder_*` / `cbor_value_*` | tagged binary |
| nanopb | Schema | `pb_encode` / `pb_decode` | field-1 protobuf-style |
| protobuf-c | Schema | `protobuf_c_message_pack` / `unpack` | tagged binary |
| flatcc | Schema | `flatcc_builder_*` / verifier | tagged binary |
| ubj | Binary | `ubjw_*` / `ubjr_*` | tagged binary |
| cbor-encode | Binary | `cbor_serialize_alloc` / `cbor_load` | tagged binary |
| custom-binary | Binary | hand-packed C structs | direct struct dump |

## Upgrading to real libraries

1. Vendor sources under `c/third_party/` or `find_package`/`pkg-config`.
2. Replace `json_write_fixture` / `write_env` in `src/register_serializers.c` with real API calls.
3. Keep the `serializer_t` interface and CSV contract unchanged so analysis stays valid.
