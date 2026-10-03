# Rust Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Module layout

```text
rust/src/serializers/
  mod.rs           # trait, helpers, all_serializers()
  kinded.rs        # shared kind-tracked direct codec macro
  json.rs          # serde_json, simd-json, sonic-rs
  binary_serde.rs  # rmp-serde, ciborium, bincode, postcard, bitcode, flexbuffers, bson, ion-rs
  direct.rs        # minicbor, rkyv, nanoserde, speedy
  prost_ser.rs     # prost + fixture conversion
  avro_ser.rs      # serde_avro_fast (Avro binary datum)
  columnar.rs      # arrow-ipc, parquet, parquet-uncompressed
  sbe_ser.rs       # sbe-tool 1.40.2 flyweights (vendored rust/gen/sbe)
```

## Serializers (22)

`all_serializers()` registers 22 rows. The previous heading said 17 and did not list `serde_yaml`, which was already registered (18). The four columnar rows are `arrow-ipc`, `parquet`, `parquet-uncompressed`, and `sbe`.

| Name | Category | Call path notes |
|------|----------|-----------------|
| serde_json | JSON | `to_vec` / `from_slice`; native stream |
| simd-json | JSON | SIMD parse; ser via `serde_json` |
| sonic-rs | JSON | `to_vec` / `from_slice` |
| rmp-serde | MessagePack | `to_vec_named` / `from_slice` |
| ciborium | CBOR | reusable buffer; native stream |
| bincode | Binary | config reused in `prepare` |
| postcard | Binary | `to_allocvec` / `from_bytes` |
| bitcode | Binary | `serialize` / `deserialize` |
| flexbuffers | FlexBuffers | Serde flexbuffers path |
| bson | Document binary | `bson::to_vec` / `from_slice` |
| ion-rs | Binary | `experimental-serde` `to_binary` / `from_ion` (allocating; stream adapted) |
| minicbor | CBOR | direct `Encode`/`Decode` |
| rkyv | Zero-copy | timed path materializes owned `T` for fidelity |
| prost | Protobuf | convert in `prepare`; timed codec only |
| serde_avro_fast | Schema | schema + `SerializerConfig` once; `to_datum` / `from_datum_slice` |
| nanoserde | Binary | `SerBin` / `DeBin` |
| speedy | Binary | `Writable` / `Readable` |
| serde_yaml | YAML | serde YAML (registered; omitted from the old 17-row heading) |
| arrow-ipc | Columnar | arrow 60.0.0 IPC **stream** in the bytes API (not the Arrow file). Schema in `prepare`. `RecordBatch` built inside `serialize_into`. `table_project` reads field 0 via `StreamReader::try_new(_, Some(vec![0]))`. Adapted stream. No compliance decoder. |
| parquet | Columnar | parquet 60.0.0. Writer properties in `prepare`. `RecordBatch` inside serialize. Page codec is Snappy (`set_compression(SNAPPY)`); arrow-rs 60's own `DEFAULT_COMPRESSION` is UNCOMPRESSED. Encodings are not overridden. `table_project` uses `ProjectionMask::columns(..., ["f_float_0"])`. No compliance decoder. |
| parquet-uncompressed | Columnar | Same writer with `Compression::UNCOMPRESSED` only. Encodings stay at the builder default. |
| sbe | Binary schema | sbe-tool **1.40.2** (logged version; generated crate stays 0.1.0). Flyweight fill is inside serialize. `table`, `table_project`, `signal` only (`nested_table` is false). No compliance decoder. |

### Call-path contract

1. `prepare` — untimed (bind kind-specific encode fns, codec config)  
2. `serialize_into` / `deserialize_bytes` — timed  
3. Stream: **native** or **adapted**

### Timing methodology (issue #59)

| Concern | Policy |
|---------|--------|
| **Output buffer** | Benchmark runner owns a reusable `Vec<u8>`, `clear()`s before each timed encode, reuses capacity across reps. Cold allocation is expected in warmup (rep 0; dropped when `exclude_warmup` is set). Timed work is encode into that buffer. |
| **Optimization barriers** | `std::hint::black_box` on timed inputs and outputs. |
| **Fixture kind** | Direct codecs (`minicbor`, `rkyv`, …) bind a monomorphic encode fn in `prepare` so the timed path is not a multi-way `match fixture`. |
| **Columnar** | Arrow schema and Parquet writer properties are untimed. The `RecordBatch` and the SBE flyweight fill run inside the timed serialize. `table` / `table_project` / `nested_table` / `signal` are one payload for the cell, not the old length-prefix frame. `table_project` deserialize returns `f_float_0` as a sequence of length N (including N=1). |
| **RNG** | `rand_pcg::Lcg64Xsh32` with nothing-up-my-sleeve π digits + suite `BENCHMARK_SEED` mix (within-language determinism only). |

### Not yet in suite

- **flatbuffers** / **capnp** (separate IDL codegen)  
- **miniserde** (JSON-only niche)

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`, `table`, `table_project`, `nested_table`, `signal`.

Serializer filter: empty selects all. No comma keeps a case-insensitive substring match. A comma splits, trims, and keeps case-insensitive exact names, so `parquet` does not pull `parquet-uncompressed` and `json` does not pull `simd-json` or `sonic-rs`.

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
cargo run --release -- 100
```

`LOG_DIR` may be a logs **root** (results under `$LOG_DIR/rust/`).

Analysis: `analyze-benchmarks -l rust`.

## Build notes

- `build.rs` compiles `schemas/v2/protobuf/benchmark_v2.proto` via prost-build.  
- Offline builds need a populated `target/` / vendor cache.
