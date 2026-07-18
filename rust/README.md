# Rust Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Module layout

```text
rust/src/serializers/
  mod.rs           # trait, helpers, all_serializers()
  kinded.rs        # shared kind-tracked direct codec macro
  json.rs          # serde_json, simd-json, sonic-rs
  binary_serde.rs  # rmp-serde, ciborium, bincode, postcard, bitcode, flexbuffers, bson
  direct.rs        # minicbor, rkyv, nanoserde, speedy
  prost_ser.rs     # prost + fixture conversion
```

## Serializers (15)

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
| minicbor | CBOR | direct `Encode`/`Decode` |
| rkyv | Zero-copy | timed path materializes owned `T` for fidelity |
| prost | Protobuf | convert in `prepare`; timed codec only |
| nanoserde | Binary | `SerBin` / `DeBin` |
| speedy | Binary | `Writable` / `Readable` |

### Call-path contract

1. `prepare` — untimed  
2. `serialize_bytes` / `deserialize_bytes` — timed  
3. Stream: **native** or **adapted**

### Not yet in suite

- **flatbuffers** / **capnp** (separate IDL codegen)  
- **miniserde** (JSON-only niche)

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

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
