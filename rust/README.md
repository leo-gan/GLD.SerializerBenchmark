# Rust Serializer Benchmark

Part of the [cross-language serializer benchmark](../README.md).

## Serializers (15)

| Name | Category | Call path notes |
|------|----------|-----------------|
| serde_json | JSON | `to_vec` / `from_slice`; **native** stream via `to_writer` / `from_reader` |
| simd-json | JSON | **deser** via SIMD; **ser** uses `serde_json` (crate focus is parsing) |
| sonic-rs | JSON | `to_vec` / `from_slice` |
| rmp-serde | MessagePack | `to_vec_named` / `from_slice` |
| ciborium | CBOR | reusable buffer; **native** stream write/read |
| bincode | Binary | bincode 2 config **reused** in `prepare` |
| postcard | Binary | `to_allocvec` / `from_bytes` |
| bitcode | Binary | `serialize` / `deserialize` |
| flexbuffers | FlexBuffers | Serde flexbuffers path |
| bson | Document binary | `bson::to_vec` / `from_slice` |
| minicbor | CBOR | **direct** `Encode`/`Decode` on concrete types (no envelope) |
| rkyv | Zero-copy | **full** `Archive` on concrete types; timed path materializes owned `T` for fidelity |
| prost | Protobuf | **`prost-build`** from `schemas/benchmark_data.proto`; convert in `prepare` |
| nanoserde | Binary | `SerBin` / `DeBin` on concrete types |
| speedy | Binary | `Writable` / `Readable` on concrete types |

### Call-path contract (aligned with Python)

1. `prepare(&fixture)` — untimed (codec config, kind tracking, prost message build)
2. `serialize_bytes` / `deserialize_bytes` — timed
3. Stream mode: **native** or **adapted** (see `StreamMode` on each impl)

### Not yet in suite (Priority B remaining)

- **flatbuffers** / **capnp**: multi-lang zero-copy IDL with separate codegen (flexbuffers covers schemaless FB-family partially)
- **miniserde**: JSON-only alternative to full Serde (overlap with nanoserde/sonic story)

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

Or directly (writes under monorepo `logs/rust/`):

```bash
cargo run --release -- 100
```

`LOG_DIR` may point at a logs **root** (results go to `$LOG_DIR/rust/`).

Cross-language analysis: `analyze-benchmarks -l rust` (see root README).

## Build notes

- `build.rs` uses **protoc-bin-vendored** + `prost-build` on `../schemas/benchmark_data.proto`.
- Requires network once to fetch crates/protoc; offline builds need a populated `target/`.
