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
| [bincode](https://github.com/bincode-org/bincode) | Binary | `bincode` 2 | Serde; config in `prepare` | adapted | Config not rebuilt per call |
| [bitcode](https://github.com/SoftbearStudios/bitcode) | Binary | `bitcode` | Serde | adapted | Bit-packed |
| [bson](https://github.com/mongodb/bson-rust) | Document | `bson` | Serde | adapted | Document DB interop |
| [ciborium](https://github.com/enarx/ciborium) | CBOR | `ciborium` | Serde | native | Reused write buffer |
| [flexbuffers](https://github.com/google/flatbuffers) | FlexBuffers | `flexbuffers` | Serde | adapted | Schemaless FB family |
| [minicbor](https://github.com/twittner/minicbor) | CBOR | `minicbor` | **Direct** `Encode`/`Decode` on structs | adapted | No MessagePack envelope |
| [nanoserde](https://github.com/not-fl3/nanoserde) | Binary | `nanoserde` | `SerBin`/`DeBin` | adapted | Zero-dep style binary |
| [postcard](https://github.com/jamesmunns/postcard) | Binary | `postcard` | Serde | adapted | no_std-friendly format |
| [prost](https://github.com/tokio-rs/prost) | Schema | `prost` + build | Protobuf messages in `prepare` | adapted | De-facto Rust Protobuf (no Google-owned Rust runtime; `prost-build` + fixture/`shared` protos) |
| [rkyv](https://github.com/rkyv/rkyv) | Zero-copy | `rkyv` 0.8 | **Full** `Archive` on structs | adapted | Timed deser **materializes** owned `T` for fidelity |
| [rmp-serde](https://github.com/3Hren/msgpack-rust) | MessagePack | `rmp-serde` | `to_vec_named` | adapted | Named maps |
| [serde_avro_fast](https://github.com/Ten0/serde_avro_fast) | Schema | `serde_avro_fast` | Serde one-pass datum; reused `SerializerConfig` | native | Prefer over official `apache-avro` (Value intermediate is multi-× slower than JSON on small records) |
| [serde_json](https://github.com/serde-rs/json) | JSON | `serde_json` | Serde `Fixture` | native | Baseline |
| [simd-json](https://github.com/simd-lite/simd-json) | JSON | `simd-json` | SIMD **parse**; ser via serde_json | adapted | Honest split responsibilities |
| [sonic-rs](https://github.com/cloudwego/sonic-rs) | JSON | `sonic-rs` | Serde-compatible SIMD JSON | adapted | Hot-path JSON |
| [speedy](https://github.com/koute/speedy) | Binary | `speedy` | `Writable`/`Readable` | adapted | Fast binary framework |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [bincode](https://github.com/bincode-org/bincode) · `2.0.1`

bincode is a compact binary format for serde. It was created so Rust programs could pack serde types without a public schema. It is a Rust-centric encoding, not a cross-language standard.

#### [bitcode](https://github.com/SoftbearStudios/bitcode) · `0.6.9`

bitcode is a bit-packed binary format for serde. It was written to squeeze serialized Rust values smaller than typical byte-aligned packers.

#### [bson](https://github.com/mongodb/bson-rust) · `2.15.0`

BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.

#### [ciborium](https://github.com/enarx/ciborium) · `0.2.2`

ciborium is a CBOR implementation for serde (Enarx). CBOR is the IETF binary JSON-like format. The crate exists to give Rust a serde CBOR backend.

#### [flexbuffers](https://github.com/google/flatbuffers) · `2.0.0`

FlexBuffers is the schemaless cousin of FlatBuffers. It was created so you can have a FlatBuffers-family binary without compiling a schema. The same Google repository implements it.

#### [minicbor](https://github.com/twittner/minicbor) · `0.25.1`

minicbor is a compact, often no_std CBOR codec with its own Encode/Decode traits. The problem was serde overhead and no_std needs. It implements RFC 8949 directly on structs.

#### [nanoserde](https://github.com/not-fl3/nanoserde) · `0.1.37`

nanoserde is a tiny, dependency-light serializer for Rust (SerBin/DeBin). The problem was serde's compile-time and dependency weight in constrained crates. nanoserde generates a minimal binary path.

#### [postcard](https://github.com/jamesmunns/postcard) · `1.1.3`

postcard is a compact, no_std-friendly binary format for serde (James Munns). It was created for embedded Rust where alloc and self-describing formats are too heavy.

#### [prost](https://github.com/tokio-rs/prost) · `0.13.5`

prost is the de-facto Protocol Buffers implementation for Rust (tokio-rs). The problem was that Google does not ship an official Rust runtime. prost-build generates Rust from `.proto` and times encode/decode on those messages.

#### [rkyv](https://github.com/rkyv/rkyv) · `0.8.18`

rkyv is a zero-copy deserialization framework for Rust. The problem was that even fast binary codecs still allocate an owned value on decode. rkyv archives data so it can be accessed in place; this suite still materializes owned `T` for fidelity.

#### [rmp-serde](https://github.com/3Hren/msgpack-rust) · `1.3.1`

rmp-serde is MessagePack for serde (msgpack-rust). MessagePack exists as compact binary JSON. This crate maps serde types to named MessagePack maps.

#### [serde_avro_fast](https://github.com/Ten0/serde_avro_fast) · `2.1.1`

serde_avro_fast is a high-performance Avro datum codec for serde. Avro exists for compact, schema-driven records. This crate avoids the official apache-avro Value intermediate, which is multi-× slower on small records.

#### [serde_json](https://github.com/serde-rs/json) · `1.0.151`

serde_json is the standard JSON backend for Rust's serde. Serde was created so Rust types could implement Serialize/Deserialize once and plug in many formats. serde_json is the JSON instance of that idea.

#### [simd-json](https://github.com/simd-lite/simd-json) · `0.14.3`

simd-json is a SIMD JSON parser for Rust (the simdjson port). The problem was parse speed vs serde_json. This row uses SIMD for parse; serialize still goes through serde_json.

#### [sonic-rs](https://github.com/cloudwego/sonic-rs) · `0.3.17`

sonic-rs is a SIMD-oriented JSON library for Rust, in the same family as ByteDance sonic. The problem was JSON cost on the hot path. It offers a serde-compatible encode/decode.

#### [speedy](https://github.com/koute/speedy) · `0.8.7`

speedy is a fast binary framework for Rust with its own Writable/Readable traits. It was written to beat generic serde binaries on the encode/decode hot path.

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
