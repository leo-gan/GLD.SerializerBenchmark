---
title: "Rust"
---

Rust
====

Rust serialization is dominated by the **serde** data model: libraries implement `Serialize`/`Deserialize` once, then plug in format backends. A second tier (**rkyv**, FlatBuffers, Cap’n Proto) targets zero-copy access.

## Runtime

### What it is

Rust compiles to **native machine code**. There is no virtual machine and no garbage collector. Memory is released when values go out of scope. That rule is called **ownership**. Because of it, a Rust microsecond is a different kind of number from a C#, Java, or Python microsecond.

| | This suite |
|---|---|
| Edition | Rust **2021** |
| Host toolchain | `rustc` and `cargo`, usually installed with rustup |
| Prepare | `./scripts/install-host-requirements.sh rust` |
| Run | `cargo build --release` through `rust/scripts/run-benchmarks.sh` |
| Memory | Ownership. No garbage collector. |

### What this suite runs

The `--release` flag turns on optimizations. A `cargo run` without `--release` uses the Debug profile and is not comparable to the Dashboard. `prost` code is generated at build time by `build.rs`. Most rows go through **serde**, which is Rust’s shared serialize-and-deserialize trait. A few libraries (`minicbor`, `rkyv`, `nanoserde`, `speedy`, `prost`) use their own traits instead.

### What changes the numbers

Building without `--release` is the error that changes the numbers the most, because Debug Rust is far slower than optimized Rust. After that, the useful comparison is still inside one family: JSON with JSON, not JSON with a zero-copy schema codec.

`rkyv` deserialize on the timed path **builds owned values** so the suite can check fidelity. A pure zero-copy `access` of the archived bytes would be faster and is not what this row measures. `simd-json` only accelerates parse; serialize still goes through `serde_json`.

### Suite-specific gotchas

Stream mode is native only where the serializer table says so. Elsewhere the stream path is the bytes path written through a cursor.

These times cannot be ranked against a garbage-collected language as one contest.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`rust/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/rust/README.md). The language overview is [The Rust Book](https://doc.rust-lang.org/book/).

## Benchmark runner

- Directory: `rust/` (repository root)
- Output: monorepo `logs/rust/YYYY-MM-DD-HHMMSS.csv` (`Language=rust`, times in **nanoseconds**)
- Runner: `rust/scripts/run-benchmarks.sh {smoke|all-single|full|research}` or `cargo run --release -- <reps>`
- Registration: [`rust/src/serializers/mod.rs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/rust/src/serializers/mod.rs) (family modules under `serializers/`)

## Serializers

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
| prost | Schema | `prost` + build | Protobuf messages in `prepare` | adapted | De-facto Rust Protobuf (no Google-owned Rust runtime; `prost-build` + fixture/`shared` protos) |
| rkyv | Zero-copy | `rkyv` 0.8 | **Full** `Archive` on structs | adapted | Timed deser **materializes** owned `T` for fidelity |
| rmp-serde | MessagePack | `rmp-serde` | `to_vec_named` | adapted | Named maps |
| serde_avro_fast | Schema | `serde_avro_fast` | Serde one-pass datum; reused `SerializerConfig` | native | Prefer over official `apache-avro` (Value intermediate is multi-× slower than JSON on small records) |
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

These notes explain odd-looking correctness or speed edges on Rust only:

- **prost** maps ISO timestamps through millisecond integers; the benchmark runner allows date-string drift on types that carry timestamps (message, event, document, telemetry).
- **rkyv** timed deserialize **builds owned values** for comparison; a pure zero-copy `access` path would be faster.
- **simd-json** serialize still goes through `serde_json` (the crate focuses on parse speed).
- **flatbuffers / capnp:** not registered yet (codegen weight); flexbuffers partially covers FB-family schemaless use.
- Stream mode is **native** only where noted; others are adapted bytes+cursor.

Also: [`rust/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/rust/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## How to rank

Compare serializers **inside the same family** only (JSON with JSON, not JSON with a zero-copy schema codec). Rank in **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). Stream mode is left out of this ranking.

| Family | Members |
|--------|---------|
| JSON | `serde_json`, `simd-json`, `sonic-rs` |
| Rust-centric binary | `bincode`, `postcard`, `bitcode`, `nanoserde`, `speedy` |
| Schema / zero-copy | `flexbuffers`, `rkyv`, `prost` |
| Schemaless binary (interop) | `bson`, `ciborium`, `minicbor`, `rmp-serde` |

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=rust&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

## Design choices

1. **Prepare outside the loop** — configs, buffers, prost messages, kind tags.
2. **Optimal APIs** — crate-recommended encode/decode; no pretty-print.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **Concrete types** for non-Serde stacks (minicbor, rkyv, nanoserde, speedy, prost).
