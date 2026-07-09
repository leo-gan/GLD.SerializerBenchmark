# Rust

Rust serialization is dominated by the **serde** data model: libraries implement `Serialize`/`Deserialize` once, then plug in format backends. A second tier (**rkyv**, FlatBuffers, Cap’n Proto) targets zero-copy access.

## Benchmark harness

- Directory: `rust/` (repository root)
- Output: monorepo `logs/rust/YYYY-MM-DD-HHMMSS.csv` (`Language=rust`, times in **nanoseconds**)
- Runner: `rust/scripts/run-benchmarks.sh {smoke|all-single|full|research}` or `cargo run --release -- <reps>`
- Registration: [`rust/src/serializers/mod.rs`](../../rust/src/serializers/mod.rs) (family modules under `serializers/`)

## Serializers (15)

| Serializer | Category | Crate | Native path | Stream | Notes |
|------------|----------|-------|-------------|--------|-------|
| bincode | Binary | `bincode` 2 | Serde; config in `prepare` | adapted | Config not rebuilt per call |
| bitcode | Binary | `bitcode` | Serde | adapted | Bit-packed |
| bson | Document | `bson` | Serde | adapted | Document DB interop |
| ciborium | CBOR | `ciborium` | Serde | native | Reused write buffer |
| flexbuffers | FlexBuffers | `flexbuffers` | Serde | adapted | Schemaless FB family |
| minicbor | CBOR | `minicbor` | **Direct** `Encode`/`Decode` on structs | adapted | No MessagePack envelope |
| nanoserde | Binary | `nanoserde` | `SerBin`/`DeBin` | adapted | Zero-dep style binary |
| postcard | Binary | `postcard` | Serde | adapted | no_std-friendly format |
| prost | Schema | `prost` + build | Protobuf messages in `prepare` | adapted | From shared `.proto` |
| rkyv | Zero-copy | `rkyv` 0.8 | **Full** `Archive` on structs | adapted | Timed deser **materializes** owned `T` for fidelity |
| rmp-serde | MessagePack | `rmp-serde` | `to_vec_named` | adapted | Named maps |
| serde_json | JSON | `serde_json` | Serde `Fixture` | native | Baseline |
| simd-json | JSON | `simd-json` | SIMD **parse**; ser via serde_json | adapted | Honest split responsibilities |
| sonic-rs | JSON | `sonic-rs` | Serde-compatible SIMD JSON | adapted | Hot-path JSON |
| speedy | Binary | `speedy` | `Writable`/`Readable` | adapted | Fast binary framework |

### Call-path contract (same idea as Python)

```text
prepare(fixture)                 # untimed: config, kind, prost convert
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed
  fidelity(expected, actual)     # untimed
```

### Caveats

- **ObjectGraph:** supported by **all** registered codecs via a flat node table + integer edges (same topology as C#/Python; no live pointer cycles).
- **Integer:** skipped for `prost` (no bare scalar message in schema).
- **simd-json serialize** is `serde_json` (crate optimizes parse).
- **rkyv:** access-only (zero-copy without materialize) would be faster; suite materializes for a fair owned-value fidelity check.
- **prost** date fields go through millisecond timestamps; fidelity allows date string drift on Person/Simple/Telemetry/EDI.
- **flatbuffers / capnp:** not registered yet (codegen weight); flexbuffers partially covers FB-family schemaless use.
- Stream mode is **native** only where noted; others are adapted bytes+cursor (same honesty model as Python).

Also: [`rust/README.md`](../../rust/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Design choices

1. **Prepare outside the loop** — configs, buffers, prost messages, kind tags.
2. **Optimal APIs** — crate-recommended encode/decode; no pretty-print.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **Concrete types** for non-Serde stacks (minicbor, rkyv, nanoserde, speedy, prost).
