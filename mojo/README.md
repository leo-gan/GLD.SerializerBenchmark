# Mojo Serializer Benchmark

Native Mojo 1.1 benchmark runner for Data Model v2 fixtures (`message`, `document`, `telemetry`, `strings`, `event`, plus columnar `table`, `table_project`, `nested_table`, and `signal`).

## Serializers (17)

| Name | Category | Package | Notes |
|------|----------|---------|-------|
| EmberJson | JSON | emberjson 0.3.4 | Reflection `serialize` / `deserialize` (vendored sources; the conda package is a Mojo 1.0 binary) |
| ehsanmok-json | JSON | ehsanmok/json 0.4.0 | `serialize_json` encode; `loads` + Value walk decode |
| mojo-json | JSON | leo-gan/gld-json 0.5.0 | Typed WireWriter / WireReader encode / decode (vendored sources) |
| mojo-cbor | Binary | leo-gan/gld-cbor 0.8.0 | `CborDatum` encode / decode (vendored sources) |
| mojo-protobuf | Schema | leo-gan/gld-protobuf 0.7.0 | Generated suite messages (vendored sources) |
| mojo-flatbuffers | Schema | leo-gan/gld-flatbuffers 0.4.0 | Reused Builder and generated tables from `cpp/schemas/benchmark.fbs` (vendored sources) |
| mojo-avro | Schema | leo-gan/gld-avro 0.4.0 | `AvroDatum` encode / decode (vendored sources) |
| mojo-toml | Text | DataBooth/mojo-toml | `to_toml` / `parse` (vendored source). Not gld-toml. |
| gld-toml | Text | [leo-gan/gld-toml](https://github.com/leo-gan/gld-toml) 0.1.0 | `encode_toml` / `decode_toml` (vendored as `gldtoml`, so it does not collide with DataBooth's `toml` package) |
| gld-yaml | Text | [leo-gan/gld-yaml](https://github.com/leo-gan/gld-yaml) 0.6.0 | `yaml.encode` / `yaml.decode` on suite types (vendored sources) |
| mojo-msgpack | Binary | leo-gan/gld-messagepack 0.4.0 | WireWriter / WireReader (vendored sources) |
| mojo-bson | Binary | leo-gan/gld-bson 0.1.0 | WireWriter / WireReader (vendored sources) |
| mojo-ion | Binary | leo-gan/gld-ion 0.2.0 | Ion 1.0 binary `encode` / `decode` on a document (vendored sources) |
| mojo-smile | Binary | leo-gan/gld-smile 0.2.0 | Smile `encode_doc` / `decode_bytes` on a document (vendored sources) |
| arrow-ipc | Columnar | leo-gan/gld-arrow 0.2.0 | IPC stream `encode_ipc_stream` / `decode_ipc_stream` on columnar types (vendored sources) |
| parquet | Columnar | leo-gan/gld-parquet 0.2.0 | Parquet file with Snappy pages (vendored sources) |
| parquet-uncompressed | Columnar | leo-gan/gld-parquet 0.2.0 | Same writer with page compression off |

JSON, CBOR, Protobuf, YAML, MessagePack, FlatBuffers, Avro, BSON, Ion, Smile, Arrow, and Parquet are compiled from `vendor/` with colliding internals renamed (`runtime`, `wire`, `compress`, and the rest) so they can live in one process. `./mojo/scripts/fetch-vendors.sh` prefers sibling checkouts under `…/GLD/gld-*` and falls back to GitHub. The vendored ehsanmok/json tree spells `Array` where v0.4.0 still says `InlineArray`, which Mojo 1.1 removed. Columnar rows run from `config/library/columnar.yaml` with an allow-list. They are not in the default suite matrix.

## Host tools

```bash
./scripts/install-host-requirements.sh mojo
```

That installs [pixi](https://pixi.sh) if needed and runs `pixi install` in `mojo/` (Mojo 1.1 and EmberJson).

## Run

```bash
./mojo/scripts/run-benchmarks.sh smoke
./mojo/scripts/run-benchmarks.sh all-single
./mojo/scripts/run-benchmarks.sh all-single EmberJson message
```

I/O mode is **bytes only**. Times are nanoseconds. `Language=mojo`.
