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

Source of truth for the trait API: [`prost/src/message.rs`](https://github.com/tokio-rs/prost/blob/master/prost/src/message.rs). Encoding helpers: `prost` encoding module (varint, wire types) documented as implementing the official encoding guide.

### S1 — Codegen produces a concrete `Message` impl

For each message type, prost-build (with `prost-derive` patterns) generates roughly:

- A **struct** with owned Rust fields (`String`, `Vec<T>`, `Option`/presence rules for proto3, nested structs).  
- An **`impl Message`** whose methods know each field’s **tag number** and **wire type**.

There is **no runtime reflection table** like protobuf-c descriptors for the hot path: field knowledge is **compiled into** `encode_raw` / `merge_field`.

### S2 — `encoded_len`: dry-run sizing

```text
encoded_len(message) =
  sum over present fields of
    key_len(tag) + payload_len(value)
```

Used so `encode` can check `BufMut::remaining_mut` and so `encode_to_vec` can `Vec::with_capacity(encoded_len())` and avoid realloc churn.

### S3 — Public `encode` / `encode_to_vec`

From the trait (logic, not a line-for-line quote):

1. `required = self.encoded_len()`.  
2. If the output buffer’s remaining capacity `< required` → `EncodeError` (or, for `encode_to_vec`, allocate exactly).  
3. Call **`encode_raw(&mut buf)`** — the method that actually writes.  
4. `encode_to_vec` is: allocate `Vec` with capacity `encoded_len()`, `encode_raw`, return the vec.

`encode_length_delimited` prefixes a varint length (for embedding this message as a LEN field elsewhere).

### S4 — `encode_raw`: field-by-field write

Generated/hand-specialized code (conceptually):

```text
for each field that should appear on the wire:
  encode_key(field_number, wire_type) into buf   // varint tag
  encode_payload(field_type, value) into buf
```

Payload helpers (in `prost::encoding`):

| Kind | Helper behavior |
|------|-----------------|
| Varint types | `encode_varint` |
| Fixed32/64 | little-endian raw stores |
| String / bytes | length delimiter + raw bytes |
| Nested message | nested `encoded_len` + length delimiter + nested `encode_raw` |
| Repeated | loop (unpacked) or packed block |
| Map | as repeated map-entry messages |

This is the same tag/payload model as [wire format](protobuf-wire-format.md).

### S5 — `bytes::{Buf, BufMut}`

prost writes through the [`bytes`](https://github.com/tokio-rs/bytes) traits so the destination can be a `Vec<u8>`, a pre-sized buffer, or other `BufMut` types—without reimplementing growth for every backend.

```text
  struct fields  →  encoded_len  →  encode_raw (tags+payloads)  →  BufMut
```

## How prost implements deserialization (step-by-step)

### D1 — `decode` = default + `merge`

```text
decode(buf):
  message = Default::default()
  merge(&mut message, buf)
  return message
```

So decode never “constructs field-by-field from a schema registry”; it **fills a default struct**.

### D2 — `merge`: the tag loop

From `Message::merge` (same source file):

```text
while buf still has bytes:
  (tag, wire_type) = decode_key(buf)   // read tag varint, split number / wire type
  message.merge_field(tag, wire_type, buf, ctx)?
```

`DecodeContext` tracks **recursion depth** for nested messages (default recursion limit; `no-recursion-limit` feature exists). Hostility/depth is a real concern ([301 untrusted input](../301/untrusted-input.md)).

### D3 — `merge_field`: generated match on tag

Each message’s `merge_field` is essentially:

```text
match tag:
  1 => decode this field’s wire_type into self.field_1
  2 => ...
  _ => skip unknown field given wire_type  // or retain, per version/features
```

Wrong `wire_type` for a known tag → `DecodeError`.

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

## Buffers & ownership

| Value | Notes |
|-------|--------|
| Generated struct | Fully owned Rust data |
| `encode_to_vec` output | Owned `Vec<u8>` |
| `decode` input | Borrowed `impl Buf` for the call duration |
| Nested decode | Recursion context decrements depth |

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
