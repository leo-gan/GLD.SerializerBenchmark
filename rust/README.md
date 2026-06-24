# Rust Serializer Benchmark

Part of the [cross-language serializer benchmark](../README.md).

## Serializers (12)

| Name | Category | Optimal API |
|------|----------|-------------|
| serde_json | JSON | `to_vec` / `from_slice` |
| simd-json | JSON | `simd_json::serde::from_slice` (mut buffer) |
| sonic-rs | JSON | `sonic_rs::to_vec` / `from_slice` |
| rmp-serde | MessagePack | `to_vec_named` / `from_slice` |
| ciborium | CBOR | `into_writer` / `from_reader` |
| bincode | Binary | `bincode::serde::encode_to_vec` (v2) |
| postcard | Binary | `to_allocvec` / `from_bytes` |
| bitcode | Binary | `bitcode::serialize` / `deserialize` |
| flexbuffers | Schema-ish | `FlexbufferSerializer` / `Reader` |
| minicbor | CBOR | `minicbor::to_vec` / `decode` |
| rkyv | Zero-copy | `rkyv::to_bytes` / `access` + `deserialize` |
| prost-wire | Protobuf-style | minimal field-1 length-delimited payload |

See [docs/rust](../docs/rust/) for rationale and caveats (rkyv/prost wrappers).

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

Or directly:

```bash
cargo run --release -- 100
```

Output: `logs/rust/benchmark-log.csv`
