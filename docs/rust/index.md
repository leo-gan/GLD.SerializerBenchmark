# Rust

Rust serialization is dominated by the **serde** data model: libraries implement `Serialize`/`Deserialize` once, then plug in format backends.

## Benchmark harness

- Directory: `rust/` (repository root)
- Output: `logs/rust/YYYY-MM-DD-HHMMSS.csv` (`Language=rust`, times in **nanoseconds**)
- Runner: `rust/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`rust/src/serializers.rs`](../../rust/src/serializers.rs)

## Serializers (12)

| Serializer | Category | Crate | Optimal API | Notes |
|------------|----------|-------|-------------|-------|
| serde_json | JSON | `serde_json` | `to_vec` / `from_slice` | Industry standard |
| simd-json | JSON | `simd-json` | `serde::from_slice` on mut buf | SIMD parse; serialize via serde_json |
| sonic-rs | JSON | `sonic-rs` | `to_vec` / `from_slice` | Very fast JSON |
| rmp-serde | MessagePack | `rmp-serde` | `to_vec_named` / `from_slice` | Named maps for struct fidelity |
| ciborium | CBOR | `ciborium` | `into_writer` / `from_reader` | IETF CBOR |
| bincode | Binary | `bincode` 2 | `serde::encode_to_vec` | Compact, Rust-centric |
| postcard | Binary | `postcard` | `to_allocvec` / `from_bytes` | no_std friendly |
| bitcode | Binary | `bitcode` | `serialize` / `deserialize` | Bit-packed |
| flexbuffers | Schema-ish | `flexbuffers` | `FlexbufferSerializer` / `Reader` | FlatBuffers FlexBuffers |
| minicbor | CBOR | `minicbor` | `to_vec` / `decode` | Light CBOR (wrapper path for untagged enum) |
| rkyv | Zero-copy | `rkyv` 0.8 | `to_bytes` / `access` + `deserialize` | Archives MessagePack payload |
| prost-wire | Protobuf-style | `prost` + hand wire | field-1 length-delimited | Stand-in until `.proto` codegen is wired |

### Caveats

- **rkyv** and **prost-wire** measure realistic *patterns* (zero-copy archive, protobuf wire) but are not full `#[derive(Archive)]` / `prost-build` paths.
- **minicbor** encodes an intermediate byte payload as CBOR for untagged `Fixture` compatibility; direct derive types would be fairer for publication.
- **ObjectGraph** is skipped (most serde formats lack cycles without extensions).
- Stream mode currently shares the buffer path; extend with `Write`/`Read` per crate for stricter stream realism.

Also listed in [`rust/README.md`](../../rust/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Design choices

1. **Prepare outside the loop** — fixtures built once with seed `42`.
2. **Optimal APIs** — `to_vec`/`from_slice` style; no pretty-print; named MessagePack maps via `to_vec_named`.
3. **Dual mode** — `bytes` and `stream` (see caveats).
4. **ObjectGraph** — skipped for most formats.
