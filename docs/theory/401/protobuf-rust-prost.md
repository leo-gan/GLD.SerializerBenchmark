# Rust: prost path

## Problem

Rust Protobuf stacks differ (`prost`, `protobuf` crate, …). Client use of `encode` / `decode` is short; serializer developers need how **`prost::Message`**, **codegen**, and **encoding modules** actually turn structs into wire bytes and back.

## Short answer

`prost-build` emits Rust structs with a derived/`impl Message` that implements **`encode_raw`**, **`encoded_len`**, **`merge_field`**, and **`clear`**. Public `encode` / `encode_to_vec` / `decode` are thin wrappers: compute length, ensure capacity, call `encode_raw`; or `Default` + **`merge`** tag loop. Low-level primitives live in `prost::encoding` (varint, wire type, length-delimited) per the [Protobuf encoding guide](https://protobuf.dev/programming-guides/encoding/). Suite `prepare` builds messages untimed; timed path is encode/decode.

Assumes [wire format](protobuf-wire-format.md). Crate: [tokio-rs/prost](https://github.com/tokio-rs/prost) (`Message` in `prost/src/message.rs`).

## Prerequisites

- Intermediate Rust (ownership, `Vec<u8>`, traits).  
- 201 schema-dependent encoding.

## Mental model

```text
  .proto ──prost-build──► generated struct + Message impl
                              │
                    encoded_len / encode_raw ──► BufMut (Vec<u8>)
                    merge_field loop ◄──────── Buf (&[u8])
```

## Client path (what you write)

### 1. Codegen (`build.rs`)

```rust
prost_build::Config::new()
    .compile_protos(
        &["../schemas/benchmark_data.proto"],
        &["../schemas"],
    )?;
```

Often set `PROTOC` via `protoc-bin-vendored` (as in this suite’s `rust/build.rs`).

### 2. Include generated code

```rust
pub mod pb {
    include!(concat!(env!("OUT_DIR"), "/benchmark_data.rs"));
}
```

### 3. Encode / decode

```rust
use prost::Message;

let person = pb::Person {
    first_name: "Ada".into(),
    last_name: "Lovelace".into(),
    age: 36,
    ..Default::default()
};
let buf = person.encode_to_vec();
let parsed = pb::Person::decode(&buf[..])?;
```

Field names are Rust-ified; **tags** still come from `.proto` numbers.

## How prost implements serialization (step-by-step)

prost turns a Rust struct into wire bytes using **compile-time knowledge** of the schema. There is no runtime descriptor table.

### High-level flow

1. Codegen (prost-build) produces a struct + `impl Message`.
2. `encoded_len()` does a dry-run sum of tags + payloads.
3. `encode_raw()` writes the actual tags and payloads into a `BufMut`.
4. Public helpers (`encode`, `encode_to_vec`) add capacity checks and length-delimited framing.

### Decision frame: when prost feels right

- You are in a Rust service or CLI that must speak Protobuf.
- You want zero-cost abstractions and strong typing.
- You are comfortable with build-time code generation.

If you need dynamic messages or extremely small binaries, other Rust crates may fit better.

```text
  Rust struct
       │
       ▼
  encoded_len()  →  capacity check
       │
       ▼
  encode_raw()  →  tag (varint) + payload  →  BufMut
```

## How prost implements deserialization (step-by-step)

### High-level flow

1. `decode(buf)` creates `Default::default()` then calls `merge`.
2. `merge` loops calling `decode_key` then `merge_field`.
3. `merge_field` (generated) matches on tag and decodes into the struct.
4. Unknown fields are skipped (or handled per current prost policy).

```text
  bytes
       │
       ▼
  decode_key loop
       │
       ▼
  merge_field(tag, wire_type)  →  populate struct
```

A `DecodeContext` tracks recursion depth to protect against malicious nesting.

### D4 — Type-specific merge

| Field kind | Behavior |
|------------|----------|
| Singular scalar | Overwrite with decoded value |
| Singular message | Decode length-delimited; merge into nested struct |
| Repeated | Decode one element and `push` (or expand packed) |
| String | Validate UTF-8 when required; store `String` |

### D5 — Length-delimited messages

`decode_length_delimited` / nested decode read a length prefix, then merge only that many bytes—same as LEN wire payloads in the encoding guide.

### D6 — Errors

Insufficient data, invalid varint, recursion limit, bad UTF-8 → `DecodeError`. The entire `decode` buffer is expected to be consumed for `decode` (no trailing garbage depending on API; length-delimited variants stop at the declared length).

```text
  Buf  →  decode_key loop  →  merge_field(tag)  →  filled struct
```

## Generated code vs runtime crate

| Piece | Role |
|-------|------|
| **prost** | `Message` trait, varint/wire helpers, errors |
| **prost-build** | Invoke protoc plugins / emit Rust at build time |
| **prost-derive** | Derive support for custom/annotated types |
| **Generated module** | Per-schema structs + `encode_raw` / `merge_field` bodies |

Hot path = **monomorphized** encode/decode per type, not a single reflective interpreter.

## Buffers & ownership (simple diagram)

```text
Your struct (owned fields)
     │
     ▼ encode
Vec<u8>  (you own the output)
     ▲
     │ decode
&[u8] (borrowed during call) → new owned struct
```

| Value | Owner / Lifetime |
|-------|------------------|
| Generated struct | You (owned `String`/`Vec`) |
| `encode_to_vec()` result | You own the `Vec<u8>` |
| Decode input slice | Must outlive the call |

## In this suite

| Location | Role |
|----------|------|
| `rust/build.rs` | `prost-build` on shared proto |
| `rust/src/serializers.rs` (`ProstSer`) | `prepare` → message; `serialize_bytes` → `encode` |
| Log name | `prost` |
| [Rust Results](../../rust/results.md) | Schema-driven comparisons |

## Common mistakes

- Hand-editing `OUT_DIR` generated files.  
- Ignoring recursion limits on deep hostile input.  
- Comparing prost Results across languages without fixing language.  
- Assuming field emission order is part of the contract (decoders must accept any order).

## What this article is not

- `tonic`/gRPC.  
- Full prost vs `protobuf` crate comparison.  
- Manual subset codec ([lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- **Trait split:** `encoded_len` + `encode_raw` (write); `merge` + `merge_field` (read).  
- **Codegen** bakes field tags into Rust code—no descriptor table on the hot path.  
- **decode** = `Default` + tag loop—same wire model as other languages.  
- Parallel: [Python](protobuf-python.md), [C protobuf-c](protobuf-c-protobuf-c.md).
