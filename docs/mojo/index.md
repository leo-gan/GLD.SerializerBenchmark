---
title: "Mojo"
---

Mojo
====

Mojo’s serialization stack is still young. This runner times **pure-Mojo** libraries: EmberJson and ehsanmok/json for JSON, DataBooth/mojo-toml and leo-gan/gld-toml for TOML, and the leo-gan **gld-** libraries for JSON, CBOR, BSON, Protocol Buffers, FlatBuffers, Avro, YAML, MessagePack, Ion, Smile, Arrow IPC, and Parquet, and Dagr (generated Mojo from the suite's Dagr schema). The gld libraries target Mojo 1.1. `mojo-toml` and `gld-toml` are different libraries; the gld package is vendored as `gldtoml` so it does not share DataBooth’s `toml` module name.

## Runtime

### What it is

Mojo compiles to **native machine code**. This suite targets **Mojo 1.1.0** on Linux x86_64 through a `pixi` environment (`mojo/pixi.toml`).

| | This suite |
|---|---|
| Tools | Mojo **1.1.0** via `pixi` (`https://conda.modular.com/max`) |
| Build | `pixi run mojo run -I src -I src/gen/dagr -I vendor/... src/main.mojo` |
| Prepare | `./scripts/install-host-requirements.sh mojo` |
| Run | `mojo/scripts/run-benchmarks.sh` |
| Memory | Manual ownership / compiler-managed, not a tracing GC |

### What this suite runs

The runner is timed in an optimized `mojo run` / `mojo build` path. EmberJson uses official reflection `serialize` / `deserialize`. ehsanmok/json times official `serialize_json` on suite types (v0.3.1 reflects `Int32` and `List[struct]` on the write path) except `telemetry`, which builds a `Value` tree because `serialize_json` mis-matches `List[Float64]`. Decode is `loads` plus a `Value` walk (`List[struct]` deserialize is still unsupported). CBOR and Avro time `encode` / `decode` on suite types that implement `CborDatum` / `AvroDatum`. Protobuf converts suite objects to generated messages **outside** the timer, then times `encode` / `decode`. FlatBuffers keeps one `Builder`. Timed serialize is `clear`, generated `pack`, and `finish`. Timed deserialize is `unpack` into the suite value. Dagr keeps one generated `Builder` per graph and `reset()`s it per instance. `dagr-packed` and `dagr-frozen-packed` encode every graph through the generated direct builder (value structs, no arena). `dagr-regular` and `dagr-frozen` have no direct builder (the generator emits it for packed-rooted graphs only), so they build the generated arena (one per instance) and write it with the generated arena serializer. The conversion from the suite value is timed in every Dagr row. Timed deserialize is the generated lazy reader materialized into the suite value.

### What changes the numbers

Mojo 1.1 is a young compiler. A nightly compiler or a different pixi lock can move these numbers a lot. The gld libraries, including Avro, are compiled from vendored sources with renamed internal packages (`cbor_runtime`, `pb_runtime`, `avro_runtime`, …) so they can share one process.

### Suite-specific gotchas

I/O mode is **bytes only**. None of the registered libraries expose a native stream API that is not a label on the bytes path.

There is no native XML library in this wave. Columnar rows are separate from the five suite types. `arrow-ipc` is gld-arrow 0.2.0 (IPC stream). `parquet` and `parquet-uncompressed` are gld-parquet 0.2.0 (Snappy, and the same writer with compression off). `gld-hdf5` times the array data set (`grid` and `grid_window`), not the five suite types. `gld-netcdf` and `gld-adios2` stay on those suite types. TOML is two rows: `mojo-toml` (DataBooth/mojo-toml 0.9.1) and `gld-toml` (leo-gan/gld-toml 0.1.0). BSON is `mojo-bson` (gld-bson 0.1.0). Ion is `mojo-ion` (gld-ion 0.2.0) and Smile is `mojo-smile` (gld-smile 0.2.0). Kiln is `gld-kiln` (gld-kiln 0.2.0), a positional little-endian encoding of the suite structs and of every type in the tensor data set. The wire spec is [Kiln wire v2](https://leo-gan.github.io/gld-kiln/spec/). Compliance scores that version with gld-kiln 0.3.0. This timed row stays on 0.2.0.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`mojo/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/README.md). Language overview: [Mojo](https://www.modular.com/mojo).

## Benchmark runner

- Directory: `mojo/`
- Output: `logs/mojo/YYYY-MM-DD-HHMMSS.csv` (`Language=mojo`, times in **nanoseconds**)
- Runner: `mojo/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`mojo/src/bench/runner.mojo`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/src/bench/runner.mojo)

## Serializers

| Serializer | Category | Package | Stream | Notes |
|------------|----------|---------|--------|-------|
| [EmberJson](https://github.com/bgreni/EmberJson) | JSON | emberjson 0.3.4 | bytes only | Reflection `serialize` / `deserialize` |
| [ehsanmok-json](https://github.com/ehsanmok/json) | JSON | ehsanmok/json 0.4.0 | bytes only | `serialize_json` encode; `loads` + Value walk decode (CPU parser) |
| [mojo-json](https://github.com/leo-gan/gld-json) | JSON | leo-gan/gld-json 0.5.0 | bytes only | Typed WireWriter / WireReader (vendored as `gldjson`) |
| [mojo-cbor](https://github.com/leo-gan/gld-cbor) | Binary | leo-gan/gld-cbor 0.8.0 | bytes only | `CborDatum` encode / decode |
| [gld-kiln](https://github.com/leo-gan/gld-kiln) | Binary | leo-gan/gld-kiln 0.2.0 | bytes only | Positional `encode` / `decode` on the suite structs and every tensor type |
| [mojo-protobuf](https://github.com/leo-gan/gld-protobuf) | Schema | leo-gan/gld-protobuf 0.7.0 | bytes only | Generated from suite `.proto` |
| [mojo-flatbuffers](https://github.com/leo-gan/gld-flatbuffers) | Schema | leo-gan/gld-flatbuffers 0.4.0 | bytes only | Reused `Builder` and generated tables from the suite `.fbs` |
| [mojo-avro](https://github.com/leo-gan/gld-avro) | Schema | leo-gan/gld-avro 0.4.0 | bytes only | `AvroDatum` encode / decode |
| [mojo-toml](https://github.com/DataBooth/mojo-toml) | Text | DataBooth/mojo-toml 0.9.1 | bytes only | `to_toml` / `parse` |
| [gld-toml](https://github.com/leo-gan/gld-toml) | Text | leo-gan/gld-toml 0.1.0 | bytes only | `encode_toml` / `decode_toml` (vendored as `gldtoml`) |
| [gld-yaml](https://github.com/leo-gan/gld-yaml) | Text | [leo-gan/gld-yaml](https://github.com/leo-gan/gld-yaml) 0.6.0 | bytes only | `yaml.encode` / `yaml.decode` on suite types |
| [mojo-msgpack](https://github.com/leo-gan/gld-messagepack) | Binary | leo-gan/gld-messagepack 0.4.0 | bytes only | WireWriter / WireReader |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | Schema | dagr 2026.10.1 (generator) | bytes only | Generated from `schemas/v2/dagr/schema.py` into `src/gen/dagr/`; generated direct builder into one reused `Builder` (`write_{root}_graph_direct`); lazy reader decode (`read_{root}_root`) |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | Schema | dagr 2026.10.1 (generator) | bytes only | Same schema, `regular` layout (`<Type>RegularGraph`); generated arena + `write_{root}_graph` into a reused `Builder`; lazy reader decode |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | Schema | dagr 2026.10.1 (generator) | bytes only | Same schema, `frozen` layout (`<Type>FrozenGraph`); generated arena + `write_{root}_graph` into a reused `Builder`; lazy reader decode |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | Schema | dagr 2026.10.1 (generator) | bytes only | Same schema, `frozen+packed` layout (`<Type>FrozenPackedGraph`); generated direct builder into one reused `Builder`; lazy reader decode |
| [mojo-bson](https://github.com/leo-gan/gld-bson) | Binary | leo-gan/gld-bson 0.1.0 | bytes only | WireWriter / WireReader |
| [mojo-ion](https://github.com/leo-gan/gld-ion) | Binary | leo-gan/gld-ion 0.2.0 | bytes only | Ion 1.0 binary document encode / decode |
| [mojo-smile](https://github.com/leo-gan/gld-smile) | Binary | leo-gan/gld-smile 0.2.0 | bytes only | Smile document encode / decode |
| [gld-hdf5](https://github.com/leo-gan/gld-hdf5) | Binary | leo-gan/gld-hdf5 0.2.0 | bytes only | One contiguous float64 dataset named `grid`. The window is a slice of the decoded file |
| [gld-netcdf](https://github.com/leo-gan/gld-hdf5) | Binary | leo-gan/gld-hdf5 0.2.0 | bytes only | NetCDF-4 float64 variables. Dimension names differ from variable names |
| [gld-adios2](https://github.com/leo-gan/gld-hdf5) | Binary | leo-gan/gld-hdf5 0.2.0 | bytes only | BP5 directory framed as bytes. One float64 variable |
| [arrow-ipc](https://github.com/leo-gan/gld-arrow) | Columnar | leo-gan/gld-arrow 0.2.0 | bytes only | IPC stream on `table`, `table_project`, `nested_table`, and `signal` |
| [parquet](https://github.com/leo-gan/gld-parquet) | Columnar | leo-gan/gld-parquet 0.2.0 | bytes only | Parquet file, Snappy pages |
| [parquet-uncompressed](https://github.com/leo-gan/gld-parquet) | Columnar | leo-gan/gld-parquet 0.2.0 | bytes only | Same writer with page compression off |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [EmberJson](https://github.com/bgreni/EmberJson) · `0.3.4`

EmberJson is a Mojo JSON library using language reflection. Mojo is a young language; EmberJson exists to give it a community JSON serialize/deserialize path. This row times that reflection API.

#### [ehsanmok-json](https://github.com/ehsanmok/json) · `0.4.0`

ehsanmok/json is a Mojo JSON parser/serializer. It was written to give Mojo a JSON stack with a Value tree and a `serialize_json` path. Decode in this suite is `loads` plus a Value walk.

#### [mojo-json](https://github.com/leo-gan/gld-json) · `0.5.0`

gld-json (leo-gan) is a typed JSON WireWriter/Reader for Mojo. It was created because Mojo lacked a suite-ready, typed JSON codec aligned with this benchmark's domain types.

#### [mojo-cbor](https://github.com/leo-gan/gld-cbor) · `0.8.0`

gld-cbor (leo-gan) implements CBOR for Mojo via a `CborDatum` trait. CBOR is the IETF binary JSON-like format. The library exists to give Mojo a first-class CBOR encode/decode.

#### [gld-kiln](https://github.com/leo-gan/gld-kiln) · `0.2.0`

gld-kiln (leo-gan) is a positional little-endian codec for Mojo. The encoder is generated from the struct fields at compile time and writes into a reused buffer. This row times encode and decode of the suite structs. There are no field tags on the wire. On the tensor data set this row runs every type. encode writes the struct. tensor_view uses Reader.take and does not copy the matrix.

#### [mojo-protobuf](https://github.com/leo-gan/gld-protobuf) · `0.7.0`

gld-protobuf (leo-gan) is a Protocol Buffers implementation for Mojo. Protobuf exists as a language-neutral IDL. This library generates Mojo from the suite `.proto` and times encode/decode.

#### [mojo-flatbuffers](https://github.com/leo-gan/gld-flatbuffers) · `0.4.0`

gld-flatbuffers (leo-gan) is a FlatBuffers implementation for Mojo. FlatBuffers exists so a reader can take fields from the buffer without first copying the whole message into a new object. This row keeps one `Builder`, calls `clear` before each message, and times generated `pack` / `unpack` against the suite tables in `cpp/schemas/benchmark.fbs`.

#### [mojo-avro](https://github.com/leo-gan/gld-avro) · `0.4.0`

gld-avro (leo-gan) implements Apache Avro for Mojo via `AvroDatum`. Avro exists for compact, schema-driven records. The library gives Mojo that encoding.

#### [mojo-toml](https://github.com/DataBooth/mojo-toml) · `0.9.1`

DataBooth/mojo-toml is a TOML library for Mojo. TOML exists as an obvious config language. This row times that library. leo-gan/gld-toml is a different library and is the gld-toml row.

#### [gld-toml](https://github.com/leo-gan/gld-toml) · `0.1.0`

gld-toml (leo-gan) is a from-scratch TOML 1.1 library for Mojo. It is not DataBooth/mojo-toml. The benchmark vendors it as gldtoml so its package name does not collide with DataBooth's toml package.

#### [gld-yaml](https://github.com/leo-gan/gld-yaml) · `0.6.0`

gld-yaml (leo-gan) implements YAML encode/decode for Mojo. YAML exists as a human-friendly config language. The library was written so Mojo can speak YAML on suite types.

#### [mojo-msgpack](https://github.com/leo-gan/gld-messagepack) · `0.4.0`

gld-messagepack (leo-gan) is a MessagePack WireWriter/Reader for Mojo. MessagePack exists as compact binary JSON. The library gives Mojo that format.

#### [dagr-packed](https://codeberg.org/mzaks/dagr) · `2026.10.1`

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.

#### [dagr-regular](https://codeberg.org/mzaks/dagr) · `2026.10.1`

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.

#### [dagr-frozen](https://codeberg.org/mzaks/dagr) · `2026.10.1`

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.

#### [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) · `2026.10.1`

Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back. This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.

#### [mojo-bson](https://github.com/leo-gan/gld-bson) · `0.1.0`

gld-bson (leo-gan) is a from-scratch BSON codec for Mojo. BSON exists so MongoDB can store JSON-like documents in a binary, traversable layout. This row times WireWriter / WireReader on suite types.

#### [mojo-ion](https://github.com/leo-gan/gld-ion) · `0.2.0`

gld-ion (leo-gan) is a from-scratch Amazon Ion codec for Mojo. Ion exists as a typed superset of JSON with text and binary encodings. This row times Ion 1.0 binary encode and decode of a document built from the suite value.

#### [mojo-smile](https://github.com/leo-gan/gld-smile) · `0.2.0`

gld-smile (leo-gan) is a from-scratch Smile codec for Mojo. Smile exists as a compact binary form of JSON. This row times `encode_doc` and `decode_bytes` on a document built from the suite value.

#### [gld-hdf5](https://github.com/leo-gan/gld-hdf5) · `0.2.0`

gld-hdf5 is a from-scratch HDF5 library for Mojo. HDF5 exists to store typed arrays in a portable file. This row times one contiguous float64 dataset named grid. The first dimension is x and the second is y. grid_window copies the interior window after read_hdf5 returns the whole file, because this library has no hyperslab. It does not link libhdf5 and does not time the five suite types.

#### [gld-netcdf](https://github.com/leo-gan/gld-hdf5) · `0.2.0`

gld-netcdf is a registered serializer in the mojo suite. This page links its upstream source; the language inventory table describes the timed call path.

#### [gld-adios2](https://github.com/leo-gan/gld-hdf5) · `0.2.0`

gld-adios2 is a registered serializer in the mojo suite. This page links its upstream source; the language inventory table describes the timed call path.

#### [arrow-ipc](https://github.com/leo-gan/gld-arrow) · `0.2.0`

Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. gld-arrow (leo-gan) is a from-scratch Arrow library for Mojo. This row times `encode_ipc_stream` and `decode_ipc_stream`: the IPC stream, not the Arrow file. The record batch is built inside serialize. gld-arrow has no included-fields reader, so table_project decodes the stream and then materializes f_float_0 only. Suite columns are required because these rows have no nulls.

#### [parquet](https://github.com/leo-gan/gld-parquet) · `0.2.0`

Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. gld-parquet (leo-gan) is a from-scratch Parquet library for Mojo. The library default is uncompressed, so this row sets Snappy, the suite page codec. table_project decodes the file and then reads f_float_0 only, because decode_table has no column projection. Lists use the standard three-level group.

#### [parquet-uncompressed](https://github.com/leo-gan/gld-parquet) · `0.2.0`

This is the same gld-parquet writer as parquet, with the page codec left uncompressed. Encodings stay at the library default. The name is the override.

### Call-path contract

```text
prepare(fixture)                 # untimed: schema, generated message
serialize_bytes                  # timed
deserialize_bytes                # timed (+ domain conversion for protobuf)
fidelity                         # untimed, float-tolerant
```

### Caveats

- Stream mode is not claimed (`stream_policy: bytes_only`).
- dagr's generated modules import each other by bare module name, so every Mojo build adds `-I src/gen/dagr`. Do not hand-edit `src/gen/dagr/`; regenerate with `dagr build` in `schemas/v2/dagr/`.
- EmberJson 0.3.4 is the modular-community package. The newer `from_json` / `to_json` API on EmberJson main is not what this row times.
- ehsanmok/json is vendored as `ehsanmok_json` so it does not collide with the other JSON packages. GPU/`max` is stubbed; the timed path is the default CPU parser. v0.3.1 added `Value.object()` / `Value.array()` so adapters no longer parse `"{}"` / `"[]"` per node. This suite times **v0.4.0**.
- `arrow-ipc`, `parquet`, and `parquet-uncompressed` run only on `table`, `table_project`, `nested_table`, and `signal`. Invoke them with `BENCHMARK_RUN_CONFIG=config/library/columnar.yaml`.
- `f0cii/mojo-csv` last moved in 2024 (Magic-era nightly) and does not compile on Mojo 1.1.
- `forfudan/decimojo` is a decimal-math library. Its old tomlmojo parser is not a standalone serializer.

Also: [`mojo/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/README.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=mojo&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
