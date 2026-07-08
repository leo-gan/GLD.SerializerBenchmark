# Rust: prost path

## Problem

Rust Protobuf stacks differ: pure Rust codegen (`prost`), `protobuf` crate, and others. This suite uses **`prost` + `prost-build`** against the shared `.proto`. Integrators need the encode trait path and how build.rs feeds types into the harness.

## Short answer

`prost-build` runs at compile time (often with a vendored `protoc`) and emits Rust structs implementing **`prost::Message`**. Encode with `encode` / `encode_to_vec`; decode with `decode`. The suite’s `prepare` builds prost messages from fixtures (untimed); timed path is `Message::encode` / `decode`.

Assumes [wire format](protobuf-wire-format.md). Crate: `prost` (see `rust/Cargo.toml` / lockfile versions on Results).

## Prerequisites

- Intermediate Rust (ownership, `Vec<u8>`).  
- 201 schema-dependent encoding.  
- Soft: [301](../301/index.md) for when Protobuf is the product choice.

## Mental model

```text
  schemas/benchmark_data.proto
           │
           ▼  build.rs: prost_build (+ optional protoc-bin-vendored)
  generated Rust modules (OUT_DIR)
           │
  fixture ──prepare──► prost message ──encode──► Vec<u8>
                       prost message ◄─decode──  &[u8]
```

## Step-by-step

### 1. Codegen in `build.rs`

Suite pattern (simplified from `rust/build.rs`):

```rust
prost_build::Config::new()
    .compile_protos(
        &["../schemas/benchmark_data.proto"],
        &["../schemas"],
    )?;
```

Often set `PROTOC` to a vendored binary so CI does not require a system install.

### 2. Include generated code

```rust
pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/benchmark_data.rs"));
}
```

(Exact module path depends on package name in the `.proto`.)

### 3. Populate and encode

```rust
use prost::Message;

let mut person = pb::Person {
    first_name: "Ada".into(),  // prost may snake_case fields
    last_name: "Lovelace".into(),
    age: 36,
    ..Default::default()
};
let mut buf = Vec::new();
person.encode(&mut buf)?;
// or: let buf = person.encode_to_vec();
```

Field naming: prost maps proto names to Rust conventions; **wire numbers** still come from the `.proto`.

### 4. Decode

```rust
let parsed = pb::Person::decode(&buf[..])?;
```

### 5. Traits and buffers

- `Message::encode` writes into an implementor of `BufMut` (commonly `Vec<u8>`).  
- `decode` reads from a `Buf` / byte slice.  
- No reflection in the default prost path—unknown fields handling follows prost’s current behavior; check crate docs when preserving unknowns matters.

## Buffers & ownership

| Value | Notes |
|-------|--------|
| Generated struct | Owned fields (`String`, `Vec`, nested structs) |
| Encode output | You own the `Vec<u8>` |
| Decode input | Borrowed `&[u8]` for the call; result is owned struct |

## In this suite

| Location | Role |
|----------|------|
| `rust/build.rs` | `prost-build` on shared proto |
| `rust/src/serializers.rs` (`ProstSer`) | `prepare` maps `Fixture` → prost message; `serialize_bytes` calls `encode` |
| Log name | `prost` |
| [Rust Results](../../rust/results.md) | Schema-driven comparisons |

`supports` excludes fixtures Protobuf cannot express cleanly (e.g. bare integer / object graph)—see Overview notes.

## Common mistakes

- Hand-editing generated sources under `OUT_DIR`.  
- Comparing prost Results to Python without fixing language ([301 using this suite](../301/using-this-suite.md)).  
- Forgetting rebuild when `.proto` changes (`cargo:rerun-if-changed`).  
- Assuming field order in `Vec` matches another language’s encoder (decoders must not require order).

## What this article is not

- `tonic`/gRPC service layout.  
- Full comparison of prost vs `protobuf` crate vs `pbjson`.  
- Manual wire encoding (see [lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- Path: **prost-build → `Message` → encode/decode**.  
- Shared `.proto` keeps field numbers aligned with Python/C harnesses.  
- Suite `prepare` is outside timed encode.  
- Parallel tour: [Python](protobuf-python.md), [C protobuf-c](protobuf-c-protobuf-c.md).
