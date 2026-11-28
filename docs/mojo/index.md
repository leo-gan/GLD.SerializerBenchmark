---
title: "Mojo"
---

# Mojo

The Mojo runner evaluates pure-Mojo serialization libraries across community packages (`EmberJson`, `ehsanmok/json`, `DataBooth/mojo-toml`), generated `Dagr` graphs, and from-scratch pure-Mojo `gld-*` implementations covering JSON, TOML, YAML, CBOR, BSON, MessagePack, Ion, Smile, Protocol Buffers, FlatBuffers, Avro, Kiln, Arrow IPC, Parquet, HDF5, NetCDF, and ADIOS2.

## Runtime & Environment

Mojo compiles ahead of time to native machine code using compiler-managed ownership rather than a tracing garbage collector. Because Mojo 1.1 is an evolving compiler, toolchain updates or `pixi` lock changes can shift absolute latencies significantly. Vendored `gld-*` packages rename internal runtime modules (`cbor_runtime`, `pb_runtime`, `avro_runtime`, `gldjson`, `gldtoml`, `ehsanmok_json`) so all libraries compile into one process without namespace collisions. Language semantics are documented in the [Mojo Language Reference](https://mojolang.org/docs/reference/) and [Mojo Manual](https://mojolang.org/docs/manual/).

| Property | Configuration |
|---|---|
| Language / spec | Mojo 1.1.0 (Linux x86_64) |
| Build & toolchain | `pixi` (`mojo/pixi.toml`, Modular conda channel); optimized `mojo run` / `mojo build` |
| Memory model | Compiler-managed ownership; no tracing garbage collector |
| Runner & logs | `mojo/scripts/run-benchmarks.sh` → `logs/mojo/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`mojo/src/bench/runner.mojo`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/src/bench/runner.mojo) |
| Data sets | `suite`, `columnar`, `graph`, `array`, `tensor` |

## Registered Serializers

All Mojo adapters run in `bytes` mode only (`stream_policy: bytes_only`), as none expose a distinct native streaming API.

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [arrow-ipc](https://github.com/leo-gan/gld-arrow) | `arrow` | `columnar` | `bytes only` | `gld-arrow` 0.2.0 `encode_ipc_stream` / `decode_ipc_stream`; batch built in `serialize`; `table_project` projects after decode |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `bytes only` | Generated arena + `write_{root}_graph` into reused `Builder`; lazy reader→domain |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `bytes only` | Generated direct builder (`write_{root}_graph_direct`) into reused `Builder`; lazy reader→domain |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `bytes only` | Generated direct builder (`write_{root}_graph_direct`) into reused `Builder`; lazy reader→domain |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `bytes only` | Generated arena + `write_{root}_graph` into reused `Builder`; lazy reader→domain |
| [ehsanmok-json](https://github.com/ehsanmok/json) | `json` | `suite` | `bytes only` | `ehsanmok/json` 0.4.0 CPU path: `serialize_json` (`Value` tree for `telemetry`) + `loads` with `Value` walk |
| [EmberJson](https://github.com/bgreni/EmberJson) | `json` | `suite` | `bytes only` | `emberjson` 0.3.4 reflection `serialize` / `deserialize` |
| [gld-adios2](https://github.com/leo-gan/gld-hdf5) | `adios2` | `suite` | `bytes only` | Pure-Mojo BP5 directory framed in bytes (bundled in `gld-hdf5`) |
| [gld-hdf5](https://github.com/leo-gan/gld-hdf5) | `hdf5` | `array` | `bytes only` | Pure-Mojo contiguous `float64` HDF5 writer/reader; `grid_window` slices after full read (no hyperslab) |
| [gld-kiln](https://github.com/leo-gan/gld-kiln) | `kiln` | `suite`, `tensor` | `bytes only` | `gld-kiln` 0.2.0 compile-time positional `encode` / `decode`; `tensor_view` borrows via `Reader.take` |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `array`, `tensor` | `bytes only` | Pure x86-64 Assembly Kiln v2 C-ABI (`libkiln_asm_bench.so` via `OwnedDLHandle`); `table_project` uses `KILN_OPT_EMBEDDED` O(1) column skip; `tensor_view` borrows payload |
| [gld-netcdf](https://github.com/leo-gan/gld-hdf5) | `netcdf` | `suite` | `bytes only` | Pure-Mojo NetCDF-4 writer/reader (bundled in `gld-hdf5`) |
| [gld-toml](https://github.com/leo-gan/gld-toml) | `toml` | `suite` | `bytes only` | `leo-gan/gld-toml` 0.1.0 from-scratch TOML 1.1 (`encode_toml` / `decode_toml`) |
| [gld-yaml](https://github.com/leo-gan/gld-yaml) | `yaml` | `suite` | `bytes only` | `leo-gan/gld-yaml` 0.6.0 `yaml.encode` / `yaml.decode` |
| [mojo-avro](https://github.com/leo-gan/gld-avro) | `avro` | `suite` | `bytes only` | `leo-gan/gld-avro` 0.4.0 `AvroDatum` `encode` / `decode` |
| [mojo-bson](https://github.com/leo-gan/gld-bson) | `bson` | `suite` | `bytes only` | `leo-gan/gld-bson` 0.1.0 `WireWriter` / `WireReader` |
| [mojo-cbor](https://github.com/leo-gan/gld-cbor) | `cbor` | `suite` | `bytes only` | `leo-gan/gld-cbor` 0.8.0 `CborDatum` `encode` / `decode` |
| [mojo-flatbuffers](https://github.com/leo-gan/gld-flatbuffers) | `flatbuffers` | `suite` | `bytes only` | `leo-gan/gld-flatbuffers` 0.4.0 reused `Builder`, generated `pack` / `unpack` |
| [mojo-ion](https://github.com/leo-gan/gld-ion) | `ion` | `suite` | `bytes only` | `leo-gan/gld-ion` 0.2.0 Ion 1.0 binary encode/decode |
| [mojo-json](https://github.com/leo-gan/gld-json) | `json` | `suite` | `bytes only` | `leo-gan/gld-json` 0.5.0 typed `WireWriter` / `WireReader` |
| [mojo-msgpack](https://github.com/leo-gan/gld-messagepack) | `msgpack` | `suite` | `bytes only` | `leo-gan/gld-messagepack` 0.4.0 `WireWriter` / `WireReader` |
| [mojo-protobuf](https://github.com/leo-gan/gld-protobuf) | `protobuf` | `suite` | `bytes only` | `leo-gan/gld-protobuf` 0.7.0 generated from suite `.proto`; conversion untimed in `prepare` |
| [mojo-smile](https://github.com/leo-gan/gld-smile) | `smile` | `suite` | `bytes only` | `leo-gan/gld-smile` 0.2.0 Smile binary encode/decode |
| [mojo-toml](https://github.com/DataBooth/mojo-toml) | `toml` | `suite` | `bytes only` | `DataBooth/mojo-toml` 0.9.1 `to_toml` / `parse` |
| [parquet](https://github.com/leo-gan/gld-parquet) | `parquet` | `columnar` | `bytes only` | `gld-parquet` 0.2.0 with Snappy pages; `table_project` projects `f_float_0` after full decode |
| [parquet-uncompressed](https://github.com/leo-gan/gld-parquet) | `parquet` | `columnar` | `bytes only` | Same `gld-parquet` writer with page compression disabled |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[arrow-ipc](https://github.com/leo-gan/gld-arrow)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. gld-arrow (leo-gan) is a from-scratch Arrow library for Mojo. This row times `encode_ipc_stream` and `decode_ipc_stream`: the IPC stream, not the Arrow file. The record batch is built inside serialize. gld-arrow has no included-fields reader, so table_project decodes the stream and then materializes f_float_0 only. Suite columns are required because these rows have no nulls.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.
    - **[ehsanmok-json](https://github.com/ehsanmok/json)** — ehsanmok/json is a Mojo JSON parser/serializer. It was written to give Mojo a JSON stack with a Value tree and a `serialize_json` path. Decode in this suite is `loads` plus a Value walk.
    - **[EmberJson](https://github.com/bgreni/EmberJson)** — EmberJson is a Mojo JSON library using language reflection. Mojo is a young language; EmberJson exists to give it a community JSON serialize/deserialize path. This row times that reflection API.
    - **[gld-adios2](https://github.com/leo-gan/gld-hdf5)** — gld-adios2 (leo-gan, bundled in `gld-hdf5`) is a pure-Mojo ADIOS2 BP5 directory encoder and decoder framed into in-memory bytes for float64 variables on the suite types.
    - **[gld-hdf5](https://github.com/leo-gan/gld-hdf5)** — gld-hdf5 is a from-scratch HDF5 library for Mojo. HDF5 exists to store typed arrays in a portable file. This row times one contiguous float64 dataset named grid. The first dimension is x and the second is y. grid_window copies the interior window after read_hdf5 returns the whole file, because this library has no hyperslab. It does not link libhdf5 and does not time the five suite types.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln)** — gld-kiln (leo-gan) is a positional little-endian codec for Mojo. The encoder is generated from the struct fields at compile time and writes into a reused buffer. This row times encode and decode of the suite structs. There are no field tags on the wire. On the tensor data set this row runs every type. encode writes the struct. tensor_view uses Reader.take and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) loaded via `OwnedDLHandle` against shared `libkiln_asm_bench.so`. Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), `array` (KLNT v2 with strided window copy), and `tensor` (KLNT v2 with zero-copy `tensor_view`).
    - **[gld-netcdf](https://github.com/leo-gan/gld-hdf5)** — gld-netcdf (leo-gan, bundled in `gld-hdf5`) is a pure-Mojo NetCDF-4 writer and reader using distinct dimension and variable names for float64 datasets on the suite types.
    - **[gld-toml](https://github.com/leo-gan/gld-toml)** — gld-toml (leo-gan) is a from-scratch TOML 1.1 library for Mojo. It is not DataBooth/mojo-toml. The benchmark vendors it as gldtoml so its package name does not collide with DataBooth's toml package.
    - **[gld-yaml](https://github.com/leo-gan/gld-yaml)** — gld-yaml (leo-gan) implements YAML encode/decode for Mojo. YAML exists as a human-friendly config language. The library was written so Mojo can speak YAML on suite types.
    - **[mojo-avro](https://github.com/leo-gan/gld-avro)** — gld-avro (leo-gan) implements Apache Avro for Mojo via `AvroDatum`. Avro exists for compact, schema-driven records. The library gives Mojo that encoding.
    - **[mojo-bson](https://github.com/leo-gan/gld-bson)** — gld-bson (leo-gan) is a from-scratch BSON codec for Mojo. BSON exists so MongoDB can store JSON-like documents in a binary, traversable layout. This row times WireWriter / WireReader on suite types.
    - **[mojo-cbor](https://github.com/leo-gan/gld-cbor)** — gld-cbor (leo-gan) implements CBOR for Mojo via a `CborDatum` trait. CBOR is the IETF binary JSON-like format. The library exists to give Mojo a first-class CBOR encode/decode.
    - **[mojo-flatbuffers](https://github.com/leo-gan/gld-flatbuffers)** — gld-flatbuffers (leo-gan) is a FlatBuffers implementation for Mojo. FlatBuffers exists so a reader can take fields from the buffer without first copying the whole message into a new object. This row keeps one `Builder`, calls `clear` before each message, and times generated `pack` / `unpack` against the suite tables in `cpp/schemas/benchmark.fbs`.
    - **[mojo-ion](https://github.com/leo-gan/gld-ion)** — gld-ion (leo-gan) is a from-scratch Amazon Ion codec for Mojo. Ion exists as a typed superset of JSON with text and binary encodings. This row times Ion 1.0 binary encode and decode of a document built from the suite value.
    - **[mojo-json](https://github.com/leo-gan/gld-json)** — gld-json (leo-gan) is a typed JSON WireWriter/Reader for Mojo. It was created because Mojo lacked a suite-ready, typed JSON codec aligned with this benchmark's domain types.
    - **[mojo-msgpack](https://github.com/leo-gan/gld-messagepack)** — gld-messagepack (leo-gan) is a MessagePack WireWriter/Reader for Mojo. MessagePack exists as compact binary JSON. The library gives Mojo that format.
    - **[mojo-protobuf](https://github.com/leo-gan/gld-protobuf)** — gld-protobuf (leo-gan) is a Protocol Buffers implementation for Mojo. Protobuf exists as a language-neutral IDL. This library generates Mojo from the suite `.proto` and times encode/decode.
    - **[mojo-smile](https://github.com/leo-gan/gld-smile)** — gld-smile (leo-gan) is a from-scratch Smile codec for Mojo. Smile exists as a compact binary form of JSON. This row times `encode_doc` and `decode_bytes` on a document built from the suite value.
    - **[mojo-toml](https://github.com/DataBooth/mojo-toml)** — DataBooth/mojo-toml is a TOML library for Mojo. TOML exists as an obvious config language. This row times that library. leo-gan/gld-toml is a different library and is the gld-toml row.
    - **[parquet](https://github.com/leo-gan/gld-parquet)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. gld-parquet (leo-gan) is a from-scratch Parquet library for Mojo. The library default is uncompressed, so this row sets Snappy, the suite page codec. table_project decodes the file and then reads f_float_0 only, because decode_table has no column projection. Lists use the standard three-level group.
    - **[parquet-uncompressed](https://github.com/leo-gan/gld-parquet)** — This is the same gld-parquet writer as parquet, with the page codec left uncompressed. Encodings stay at the library default. The name is the override.

## Measurement Caveats

- **Dagr conversion boundary:** In Mojo, conversion from suite structs into Dagr direct builders (`dagr-packed`, `dagr-frozen-packed`) or arenas (`dagr-regular`, `dagr-frozen`) is currently timed inside serialize; decode materializes suite values from lazy readers. Regenerate `src/gen/dagr/` via `dagr build` in `schemas/v2/dagr/` rather than editing generated files.
- **No partial-read projection in `gld-*` array/columnar codecs:** `gld-hdf5` lacks hyperslab reads (`grid_window` slices after reading the whole file), and `gld-arrow` / `gld-parquet` lack column-pruning readers (`table_project` decodes before projecting `f_float_0`).
- **Kiln compliance vs. timed version:** Compliance tests score [Kiln wire v2](https://leo-gan.github.io/gld-kiln/spec/) with `gld-kiln` 0.3.0; the timed Mojo benchmark row pins `gld-kiln` 0.2.0.
- **Package pins and exclusions:** `EmberJson` pins the Modular community 0.3.4 release (not newer `from_json`/`to_json` main). `ehsanmok/json` stubs GPU/`max` and times the CPU path. No native XML library is registered; `f0cii/mojo-csv` does not compile on Mojo 1.1, and `forfudan/decimojo` is a decimal math library rather than a standalone serializer.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Mojo)](../dashboard/index.html?lang=mojo&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Mojo)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Mojo: `EmberJson` vs. `mojo-avro`](../analysis/call-sites/mojo-emberjson-vs-avro.md)
- **Build & run guide:** [`mojo/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
