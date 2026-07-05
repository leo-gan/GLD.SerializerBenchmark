# Vendored / built C dependency pins

| Library | Version / tag | Role |
|---------|---------------|------|
| cJSON | v1.7.18 | JSON |
| yyjson | 0.10.0 | JSON |
| parson | master (pinned at fetch time) | JSON |
| jansson | v2.14 | JSON |
| json-c | system (pkg-config) | JSON |
| mpack | v1.1 | MessagePack |
| msgpack-c | c-6.0.1 | MessagePack |
| tinycbor | v0.6.0 | CBOR (symbol-prefixed `tc_`) |
| libcbor | v0.11.0 | CBOR (`cbor-encode`) |
| QCBOR | v1.5.1 / master | CBOR |
| ubj | in-tree minimal UBJSON in `ser_ubj.c` | UBJSON |
| libbson | mongo-c-driver 1.27.5 (bson only) | BSON |
| nanopb | 0.4.9 | Protobuf (stream API) |
| protobuf-c | v1.5.0 | Protobuf wire + runtime |
| upb | wire-1.0 in-tree (`ser_upb.c`) | Protobuf wire (not Google upb) |
| flatcc | v0.6.1 | FlatBuffers C |
| avro-c | Apache Avro release-1.11.3 | Avro |
| zcbor | main (Nordic) | CBOR structured API |

Build artifacts live in `third_party/_build/` and `third_party/_prefix/` (gitignored).
Run `c/scripts/fetch-and-build-deps.sh` to populate.
