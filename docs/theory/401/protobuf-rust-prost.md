# Rust: prost path

## Problem

Rust Protobuf stacks differ (`prost`, `protobuf` crate, …). Client use of `encode` / `decode` is short; serializer developers need how **`prost::Message`**, **codegen**, and **encoding modules** actually turn structs into wire bytes and back.

## Short answer

`prost-build` emits Rust structs with a derived/`impl Message` that implements **`encode_raw`**, **`encoded_len`**, **`merge_field`**, and **`clear`**. Public `encode` / `encode_to_vec` / `decode` are thin wrappers: compute length, ensure capacity, call `encode_raw`; or `Default` + **`merge`** tag loop. Low-level primitives live in `prost::encoding` (varint, wire type, length-delimited) per the [Protobuf encoding guide](https://protobuf.dev/programming-guides/encoding/). Suite `prepare` builds messages untimed; timed path is encode/decode.

Assumes [wire format](protobuf-wire-format.md). Crate: [tokio-rs/prost](https://github.com/tokio-rs/prost) (`Message` in `prost/src/message.rs`).

**Suite pin (this monorepo):** `prost` / `prost-build` **0.13** in `rust/Cargo.toml`.

## Prerequisites

- Intermediate Rust (ownership, `Vec<u8>`, traits).  
- 201 schema-dependent encoding.  
- Soft: [301 untrusted input](../301/untrusted-input.md) (recursion limits and hostile nesting).

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
        &["../schemas/v2/protobuf/benchmark_v2.proto"],
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

let person = pb::MiniUser {  // teaching type; suite uses message/document/…
    first_name: "Ada".into(),
    last_name: "Lovelace".into(),
    age: 36,
    ..Default::default()
};
let buf = person.encode_to_vec();
let parsed = pb::MiniUser::decode(&buf[..])?;
```

Field names are Rust-ified; **tags** still come from `.proto` numbers. For the teaching [MiniUser](lab-mini-protobuf-encoder.md) message, compile a separate tiny `mini.proto`—it is not part of suite `benchmark_data.proto`.

## How prost implements serialization (step-by-step)

prost turns a Rust struct into wire bytes using **compile-time knowledge** of the schema. There is no runtime descriptor table — the hot path is monomorphized per message type.

### S1 — Codegen bakes the schema into Rust code

`prost-build` runs at `cargo build` time: it invokes `protoc`, reads the descriptor, and emits a Rust struct plus `impl Message` with per-field `encode_raw` / `merge_field` bodies. After this step, field numbers and wire types are compile-time constants — no descriptor table is consulted at encode time.

### S2 — `encoded_len` (dry-run size)

`encoded_len()` walks the struct's fields and sums `tag_len + payload_len` for every present field. Nested messages recurse. The result tells the caller (or `encode`) how many bytes to reserve.

### S3 — `encode_raw` (write tags + payloads)

`encode_raw(&self, buf: &mut impl BufMut)` emits one tag + payload pair per present field into the output buffer, using helpers from `prost::encoding` (varint, fixed, length-delimited). Nested messages call their own `encode_raw` inside a length-delimited frame.

### S4 — Public wrappers

`encode(&self, buf: &mut impl BufMut)` calls `encoded_len` for a capacity check, then `encode_raw`. `encode_to_vec(&self)` allocates a `Vec<u8>` of exactly the right size, then `encode_raw` into it. `encode_length_delimited` prepends the message's length varint (used by streaming / gRPC framing).

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

Use prost when you want typed, monomorphized encode/decode in a Rust binary with build-time codegen. Prefer other crates if you need fully dynamic messages at runtime or a different codegen style—this page does not rank alternatives.

## How prost implements deserialization (step-by-step)

### D1 — `decode` / `decode_length_delimited` entry

`decode(buf: impl Buf)` creates a **`Default::default()`** instance of the target struct, then calls `merge(buf)` on it. `decode_length_delimited` first reads a length varint and limits the merge to that many bytes. Both return a `Result<Self, DecodeError>`.

### D2 — Tag loop (`merge`)

`merge` reads the input buffer in a loop:

1. Call `decode_key(buf)` → `(field_number, wire_type)`.
2. Pass both plus the remaining buffer to `merge_field`.
3. Repeat until the buffer is exhausted.

A `DecodeContext` tracks **recursion depth** to protect against malicious nesting (configurable limit). Bound untrusted input size as well ([301 untrusted input](../301/untrusted-input.md)).

### D3 — `merge_field` dispatch (generated)

`merge_field` is generated per message type. It contains a `match` on `field_number`:

- **Known tag** → call the type-appropriate decoder from `prost::encoding` (e.g. `uint32::merge`, `string::merge`, `message::merge`).
- **Unknown tag** → skip the payload by wire type (consume varint, fixed bytes, or length-delimited blob) so the loop can continue.

Because `merge_field` is monomorphized code (not a runtime descriptor lookup), the compiler can inline and optimize each branch.

### D4 — Type-specific merge

| Field kind | Behavior |
|------------|----------|
| Singular scalar | Overwrite with decoded value |
| Singular message | Decode length-delimited; merge into nested struct |
| Repeated | Decode one element and `push` (or expand packed) |
| String | Validate UTF-8; store `String` |
| `oneof` | Match variant tag; decode into the enum arm |

### D5 — Length-delimited messages

`decode_length_delimited` / nested decode read a length prefix, then merge only that many bytes — same as LEN wire payloads in the encoding guide. This is how nested messages are bounded: the outer decoder slices the buffer before recursing.

### D6 — Errors

Insufficient data, invalid varint, recursion limit, bad UTF-8 → `DecodeError`. The entire `decode` buffer is expected to be consumed (no trailing garbage); length-delimited variants stop at the declared length.

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
| Pin | `prost` / `prost-build` 0.13 |
| [Rust Results](../../rust/results.md) | Schema-driven comparisons |

Do not cross-rank language Results without controlling for language ([cross-language fidelity](protobuf-cross-language-fidelity.md)).

## Common mistakes

- Hand-editing `OUT_DIR` generated files.  
- Ignoring recursion limits on deep hostile input.  
- Cross-language Results comparisons without controlling for language.  
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
