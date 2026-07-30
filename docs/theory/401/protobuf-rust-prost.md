# Rust: prost path

## Why this article exists

Rust has more than one Protocol Buffers stack. Examples include `prost`, the `protobuf` crate, and others. Client use of `encode` and `decode` looks short. Serializer developers need a deeper picture. How do **`prost::Message`**, **code generation**, and the **encoding modules** actually turn structs into wire bytes and back?

In this article you will follow the path from a `.proto` file through `prost-build` at compile time. You will then follow `encoded_len`, `encode_raw`, and the decode `merge` loop. After reading it, you should be able to explain how prost differs from a descriptor-driven interpreter such as protobuf-c. In prost, the schema is baked into specialized Rust code. It is not consulted from a runtime table on every field.

## Short answer

**`prost-build`** runs at compile time and emits Rust structs with an `impl Message` (or a derived equivalent). That implementation provides **`encode_raw`**, **`encoded_len`**, **`merge_field`**, and **`clear`**.

The public methods `encode`, `encode_to_vec`, and `decode` are thin wrappers. For writing, they compute length, ensure capacity, and call `encode_raw`. For reading, they start from `Default` and run a **`merge`** tag loop. Low-level primitives live in `prost::encoding` (varint, wire type, length-delimited helpers). They follow the [Protobuf encoding guide](https://protobuf.dev/programming-guides/encoding/).

In this suite, **`prepare`** builds messages outside the timed path. Timed work is encode and decode.

This article assumes the [wire format](protobuf-wire-format.md) article. Crate: [tokio-rs/prost](https://github.com/tokio-rs/prost) (`Message` lives in `prost/src/message.rs`).

**Suite pin (this shared code repository for many projects):** `prost` / `prost-build` **0.13** in `rust/Cargo.toml`.

## Prerequisites

- Intermediate Rust: ownership, `Vec<u8>`, traits.
- Serialization 201: schema-dependent encoding.
- Soft: [301 untrusted input](../301/untrusted-input.md) (recursion limits and hostile nesting).

## Mental model

**Codegen** (code generation) here means running a build script that turns `.proto` files into Rust source. **Monomorphization** means the Rust compiler specializes generic or trait-based code for each concrete message type. Encode and decode become ordinary per-type functions rather than a single interpreter loop.

```text
  .proto ──prost-build──► generated struct + Message impl
                              │
                    encoded_len / encode_raw ──► BufMut (Vec<u8>)
                    merge_field loop ◄──────── Buf (&[u8])
```

## Client path (what you write)

### 1. Codegen (`build.rs`)

In this step, a Cargo build script invokes prost-build so that generated Rust appears under `OUT_DIR` when you compile.

```rust
prost_build::Config::new()
    .compile_protos(
        &["../schemas/v2/protobuf/benchmark_v2.proto"],
        &["../schemas"],
    )?;
```

Projects often set `PROTOC` through `protoc-bin-vendored` (as this suite does in `rust/build.rs`).

### 2. Include generated code

```rust
pub mod pb {
    // Generated module name follows the .proto package (suite: benchmark.v2 → e.g. benchmark.v2.rs)
    include!(concat!(env!("OUT_DIR"), "/benchmark.v2.rs"));
}
```

### 3. Encode / decode

```rust
use prost::Message;

let person = pb::MiniUser {  // teaching type; suite uses message/document/…
    first_name: "Ada".into(),
    last_name: "Lovelace".into(),
    age: 36,
    ..Default::default()
};
let buf = person.encode_to_vec();
let parsed = pb::MiniUser::decode(&buf[..])?;
```

Field names are Rust-ified (snake_case and similar conventions). **Tags on the wire still come from the field numbers in the `.proto` file.** For the teaching [MiniUser](lab-mini-protobuf-encoder.md) message, compile a separate tiny `mini.proto`. It is not part of the suite `schemas/v2/protobuf/benchmark_v2.proto`.

## How prost implements serialization (step-by-step)

prost turns a Rust struct into wire bytes using **compile-time knowledge** of the schema. There is no runtime descriptor table on the code path that runs on every request under load. Instead, the code is **monomorphized**. The compiler specializes encode and decode for each concrete message type.

### S1 — Codegen bakes the schema into Rust code

`prost-build` runs at `cargo build` time. It invokes `protoc`, reads the descriptor, and emits a Rust struct plus `impl Message` with per-field `encode_raw` and `merge_field` bodies. After this step, field numbers and wire types are compile-time constants. No descriptor table is consulted at encode time.

### S2 — `encoded_len` (dry-run size)

`encoded_len()` walks the struct’s fields and sums `tag_len + payload_len` for every present field. Nested messages recurse. The result tells the caller (or `encode`) how many bytes to reserve. This matters because Rust prefers to allocate a `Vec` of the right size once, rather than growing repeatedly.

### S3 — `encode_raw` (write tags + payloads)

`encode_raw(&self, buf: &mut impl BufMut)` emits one tag-plus-payload pair per present field into the output buffer. It uses helpers from `prost::encoding` (varint, fixed, length-delimited). Nested messages call their own `encode_raw` inside a length-delimited frame. In other words, nested encode is ordinary recursion with a length prefix around the inner bytes.

### S4 — Public wrappers

`encode(&self, buf: &mut impl BufMut)` calls `encoded_len` for a capacity check, then `encode_raw`. `encode_to_vec(&self)` allocates a `Vec<u8>` of exactly the right size, then runs `encode_raw` into it. `encode_length_delimited` prepends the message’s length as a varint (used by streaming and gRPC framing).

```text
  Rust struct
       │
       ▼
  S1  codegen (build-time; field tags as constants)
       │
       ▼
  S2  encoded_len()  →  capacity check
       │
       ▼
  S3  encode_raw()  →  tag (varint) + payload  →  BufMut
       │
       ▼
  S4  Vec<u8> (caller-owned)
```

### When prost fits

Use prost when you want typed, monomorphized encode and decode in a Rust binary with build-time code generation. Prefer other crates if you need fully dynamic messages at runtime or a different codegen style. This page does not rank the alternatives.

## How prost implements deserialization (step-by-step)

### D1 — `decode` / `decode_length_delimited` entry

`decode(buf: impl Buf)` creates a **`Default::default()`** instance of the target struct, then calls `merge(buf)` on it. `decode_length_delimited` first reads a length varint and limits the merge to that many bytes. Both return a `Result<Self, DecodeError>`.

### D2 — Tag loop (`merge`)

`merge` reads the input buffer in a loop:

1. Call `decode_key(buf)` to get `(field_number, wire_type)`.
2. Pass both plus the remaining buffer to `merge_field`.
3. Repeat until the buffer is exhausted.

A `DecodeContext` tracks **recursion depth** to protect against malicious nesting (the limit is configurable). Bound untrusted input size as well ([301 untrusted input](../301/untrusted-input.md)).

### D3 — `merge_field` dispatch (generated)

`merge_field` is generated per message type. It contains a `match` on `field_number`:

- **Known tag** → call the type-appropriate decoder from `prost::encoding` (for example `uint32::merge`, `string::merge`, `message::merge`).
- **Unknown tag** → skip the payload by wire type (consume a varint, fixed bytes, or a length-delimited blob) so the loop can continue.

Because `merge_field` is monomorphized code (not a runtime descriptor lookup), the compiler can inline and optimize each branch.

### D4 — Type-specific merge

| Field kind | Behavior |
|------------|----------|
| Singular scalar | Overwrite with the decoded value |
| Singular message | Decode length-delimited; merge into the nested struct |
| Repeated | Decode one element and `push` (or expand a packed block) |
| String | Validate UTF-8; store a `String` |
| `oneof` | Match the variant tag; decode into the enum arm |

### D5 — Length-delimited messages

`decode_length_delimited` and nested decode read a length prefix, then merge only that many bytes. That is the same idea as LEN wire payloads in the encoding guide. Nested messages stay bounded because the outer decoder slices the buffer before it recurses.

### D6 — Errors

Insufficient data, an invalid varint, a recursion-limit hit, or bad UTF-8 all become `DecodeError`. The entire `decode` buffer is expected to be consumed (no trailing garbage). Length-delimited variants stop at the declared length.

```text
  Buf
       │
       ▼
  D1  Default::default() + merge
       │
       ▼
  D2  decode_key loop
       │
       ▼
  D3  merge_field(tag) → known: type decode / unknown: skip
       │
       ▼
  filled struct (owned)
```

## Generated code vs runtime crate

| Piece | Role |
|-------|------|
| **prost** | `Message` trait, varint and wire helpers, errors |
| **prost-build** | Invoke protoc plugins and emit Rust at build time |
| **prost-derive** | Derive support for custom or annotated types |
| **Generated module** | Per-schema structs plus `encode_raw` / `merge_field` bodies |

The path that runs on every request under load is **monomorphized** encode and decode per type. It is not a single reflective interpreter that walks a descriptor table at runtime.

## Buffers and ownership (simple diagram)

In Rust, **ownership** is explicit. Each value has one owner, and borrows must not outlive that owner. For prost, that means the output `Vec<u8>` is yours after encode. The input slice must remain valid only for the duration of decode.

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
| Generated struct | You (owned `String` / `Vec` fields) |
| `encode_to_vec()` result | You own the `Vec<u8>` |
| Decode input slice | Must remain valid for the duration of the call |

## In this suite

| Location | Role |
|----------|------|
| `rust/build.rs` | `prost-build` on `schemas/v2/protobuf/benchmark_v2.proto` |
| `rust/src/serializers/prost_ser.rs` (`ProstSer`) | `prepare` builds a message; timed path encodes/decodes |
| Log name | `prost` |
| Pin | `prost` / `prost-build` 0.13 |
| [Rust Results](../../rust/results.md) | Schema-driven comparisons |

Do not cross-rank language Results without controlling for language ([cross-language fidelity](protobuf-cross-language-fidelity.md)).

## Common mistakes

- Hand-editing files under `OUT_DIR`.
- Ignoring recursion limits on deep hostile input.
- Cross-language Results comparisons without controlling for language.
- Assuming field emission order is part of the contract (decoders must accept any order).

## What this article is not

- `tonic` / gRPC.
- A full prost versus `protobuf` crate comparison.
- A manual subset codec (see the [lab](lab-mini-protobuf-encoder.md)).

## Key takeaways

- **Trait split:** `encoded_len` plus `encode_raw` for writing; `merge` plus `merge_field` for reading.
- **Codegen** bakes field tags into Rust code. There is no descriptor table on the path that runs on every request under load.
- **decode** is `Default` plus a tag loop—the same wire model as other languages.
- Parallel articles: [Python](protobuf-python.md), [C protobuf-c](protobuf-c-protobuf-c.md).
