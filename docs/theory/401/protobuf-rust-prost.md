# 4.4 Rust: `prost` Monomorphized Path

## Problem Statement

Unlike descriptor-driven runtimes that look up field numbers in metadata tables on every encode or decode (`google.protobuf` in Python and `protobuf-c` in C), Rust's **`prost`** crate compiles a `.proto` schema directly into **monomorphized, per-type Rust methods**. Understanding how `prost-build` separates size computation (`encoded_len`), raw emission (`encode_raw`), and generated tag dispatch (`merge_field`) clarifies both `prost`'s allocation discipline and its contrast with descriptor interpreters.

This chapter traces `prost` / `prost-build` (pinned at `0.13` in `rust/Cargo.toml`).[^1]

---

## Architecture: Compile-Time Specialization

```text
  .proto ──prost-build (build.rs)──► generated Rust struct + impl prost::Message
                                              │
                     encoded_len() + encode_raw() ──► BufMut / Vec<u8> (owned)
                     Default::default() + merge() ◄── Buf / &[u8] (borrowed)
```

In Rust, **monomorphization** emits specialized machine code for each concrete struct type and buffer type (`Buf` / `BufMut`). Field numbers, wire types, and branch targets become compile-time constants—no runtime descriptor table is consulted on the hot path.

---

## Client Path (`build.rs` and Usage)

A Cargo build script compiles `.proto` definitions into Rust modules under `OUT_DIR`:

```rust
// rust/build.rs
prost_build::Config::new().compile_protos(
    &["../schemas/v2/protobuf/benchmark_v2.proto"],
    &["../schemas"],
)?;
```

Include the generated module and call `prost::Message` trait methods (illustrated here on a locally compiled `mini.proto` defining `MiniUser`):

```rust
use prost::Message;

let user = pb::MiniUser {
    id: 1,
    name: "Ada".into(),
    manager: None,
    tags: vec![],
};
let buf: Vec<u8> = user.encode_to_vec();      // b"\x08\x01\x12\x03Ada"
let parsed = pb::MiniUser::decode(&buf[..])?;
```

Rust identifiers follow `snake_case` naming conventions, while wire identity remains strictly the field numbers in `.proto`.

---

## Internal Execution Trace

### Serialization: Two-Pass Sizing and Emission

`prost` divides encoding into two generated trait methods on `prost::Message`:

1. **`encoded_len(&self) -> usize`:** Recursively sums `key_len(tag) + payload_len(field)` for every non-default field and nested submessage.
2. **`encode_raw(&self, buf: &mut impl BufMut)`:** Writes tags and payloads directly into `buf` using primitives in `prost::encoding` (varints, little-endian fixed widths, and `LEN` prefixes whose inner lengths were computed by `encoded_len`).

The public convenience wrappers combine both steps:

- `encode(&self, buf: &mut impl BufMut)` checks that `buf.remaining_mut() >= self.encoded_len()`, failing cleanly instead of writing partial output if a fixed buffer is too small, then invokes `encode_raw`.
- `encode_to_vec(&self)` calls `Vec::with_capacity(self.encoded_len())`—performing **exactly one heap allocation**—then invokes `encode_raw`.
- `encode_length_delimited(&self, buf)` prepends the message's varint byte length for framing (used in streaming protocols and gRPC).

### Deserialization: Generated `merge_field` Loop

1. **Entry (`decode`):** Instantiates `Self::default()` and calls `merge(buf)`.
2. **Tag loop (`prost::encoding::merge_loop`):** Decodes `(field_number, wire_type)` via `decode_key(buf)` and dispatches to the struct's generated `merge_field(tag, wire_type, buf, ctx)`.
3. **Generated `match` dispatch:** `merge_field` compiles into a static `match tag` jump table:
   - **Known tags** call specialized decoders (`uint32::merge`, `string::merge` with UTF-8 validation, `message::merge` slicing exactly `len` bytes for recursion, or packed/unpacked repeated push).
   - **Unknown tags** invoke `skip_field(wire_type, tag, buf, ctx)`, advancing the cursor safely by wire type without retaining unknown fields.
4. **Safety and errors:** `DecodeContext` enforces a recursion-depth limit (default 100) to prevent stack overflow on hostile nesting. Truncated buffers, invalid varints, malformed UTF-8, or recursion limit breaches return `Err(prost::DecodeError)`.

---

## Buffer Ownership and Crate Roles

| Crate / Artifact | Responsibility |
|---|---|
| `prost` | `Message` trait, `prost::encoding` wire primitives, `DecodeError`, `DecodeContext` |
| `prost-build` | Invokes `protoc` at build time and generates Rust source in `OUT_DIR` |
| `prost-derive` | Procedural macro implementing `Message` for annotated structs |
| Output `Vec<u8>` | Caller-owned; single allocation via `encoded_len()` |
| Input `&[u8]` / `Buf` | Borrowed only for the duration of `decode`; output struct owns its `String`/`Vec` fields |

In this suite (`rust/src/serializers/prost_ser.rs`, log name `prost`), `prepare` maps the suite domain record into the generated `prost` struct outside the timer, and the timed loop runs `encode` (into a reusable buffer) and `decode`. See the [Rust Protocol Buffers Dashboard slice](../../dashboard/index.html?lang=rust&standard=protobuf&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=prost&ser=prost#detailed-analytics).

---

## Exercises

1. **Why two passes on encode?** `prost` walks a message twice during `encode_to_vec()`—once in `encoded_len()` and once in `encode_raw()`. Why is this two-pass design often faster than a single-pass growing buffer when encoding deeply nested messages?

??? note "Solution"
    First, `Vec::with_capacity(encoded_len)` performs a single exact allocation with zero reallocations or copies. Second, because Protocol Buffers places every nested message's varint length *before* its payload (`[key][len][payload]`), knowing `encoded_len` upfront lets `encode_raw` write the entire nested tree straight forward into one contiguous buffer without staging intermediate temporary buffers per submessage.

2. **Unknown-field round-tripping:** Unlike `google.protobuf` in Python and `protobuf-c` in C, `prost` discards unknown fields during `skip_field` rather than storing them on the struct. When does that design choice cause a production defect?

??? note "Solution"
    In a **proxy, gateway, or read-modify-write relay** running an older `.proto` schema that decodes a message, modifies one field, and re-encodes it downstream: `prost` will silently strip unknown fields added by newer upstream producers. Proxy services that must forward unknown fields verbatim must either pass raw byte slices through without full re-encoding or use a runtime that preserves unknown fields.

3. **Descriptor interpreter vs. monomorphized code:** What trade-off does `prost`'s compile-time monomorphization make compared with `protobuf-c`'s single runtime descriptor loop?

??? note "Solution"
    Monomorphization eliminates indirect descriptor table lookups and allows LLVM to inline per-field reads/writes aggressively (higher throughput), at the cost of **larger compiled binary size** (proportional to the number of generated message types) and **no dynamic runtime schema reflection** without adding an auxiliary crate such as `prost-reflect`.

---

## References

[^1]: Tokio Contributors. *`prost`: A Protocol Buffers Implementation for the Rust Language*. <https://github.com/tokio-rs/prost>
