# 4.9 Case Study: Direct Fixed-Width vs. Generic Visitor (Rust)

## Problem Statement

On this suite's `document` payload ($n = 1$, `bytes` mode), Rust's **`Speedy`** completes roughly $2.2\times$ more encode+decode cycles per second than **`Bincode`**, yet emits a payload **75% larger** (214 bytes vs. 122 bytes). Both crates compile to native Rust code and emit schema-free positional binary without field names.

Opening the timed call sites and crate internals exposes a fundamental systems trade-off: **compile-time specialized fixed-width stores** (`Speedy`) versus **generic visitor indirection plus variable-length integer branching** (`Bincode` via `Serde`).

> **Illustrative L1 snapshot (`document`, $n = 1$, `bytes` mode):** Live authoritative numbers belong to the [Rust Dashboard comparison](../../dashboard/index.html?lang=rust&standard=custom&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=speedy&ser=speedy&ser=bincode#compare) ([Claims L1](../../analysis/CLAIMS_AND_REPLICATION.md) · [Rust Overview](../../rust/index.md)).

| Metric (Quoted L1 Snapshot) | `Speedy` 0.8.7 | `Bincode` 2.0.1 (`Serde` + `standard()`) |
|---|---:|---:|
| Throughput (encode + decode) | **2.84M ops/s** | 1.29M ops/s |
| Encode latency | **88 ns** | 203 ns |
| Decode latency | **264 ns** | 573 ns |
| Encoded wire size | 214 B | **122 B** |

*(For comparison, `Postcard` sits between them at ~1.73M ops/s and 114 B; see [Rust: Speedy vs. Postcard](../../analysis/call-sites/rust-speedy-vs-postcard.md).)*

---

## Source-Level Call Sites

Inspecting the Rust runner immediately reveals both a **wrapper asymmetry** and two distinct crate architectures:

### 1. `Speedy` (`rust/src/serializers/direct.rs`)

Type dispatch (`Document` vs. `Message`) occurs once in untimed `prepare`. The timed encode/decode functions operate directly on the concrete `Document` struct:[^1]

```rust
fn speedy_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else { bail!("speedy: expected Document"); };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
// decode: Document::read_from_buffer(d)
```

### 2. `Bincode` (`rust/src/serializers/binary_serde.rs`)

Encodes the outer `Fixture` enum through `Serde` using `bincode::config::standard()` (little-endian + **variable-length integer encoding**):[^2][^3]

```rust
fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    bincode::serde::encode_into_std_write(fixture, out, self.config)?;
    Ok(())
}
fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
    let (v, _): (Fixture, usize) = bincode::serde::decode_from_slice(data, self.config)?;
    Ok(v)
}
```

**Wrapper asymmetry note:** `Bincode` encodes a leading enum discriminant for `Fixture::Document` that `Speedy` omits ([Timing honesty](../../analysis/TIMING_HONESTY.md)). That discriminant accounts for a small fraction of the gap; the dominant cause lies inside the two encoders.

---

## Mechanistic Analysis

### What `Speedy` Compiles To

`#[derive(Writable, Readable)]` generates straight-line per-field writes directly onto the output buffer (`speedy-derive` defaults to fixed `u32` lengths):

- Every `i32` copies 4 bytes unconditionally (`write_u32`); every `i64` copies 8 bytes.
- Every string or `Vec` writes a 4-byte `u32` length followed by `memcpy` of the raw bytes.
- On little-endian x86_64/ARM64 hosts, byte-swapping is a compile-time no-op. After LLVM inlining, encoding `Document` collapses into a tight sequence of unbranched fixed stores and copies.

### What `Bincode` (`Serde` + `standard()`) Executes

Three abstraction layers sit between `Document` and the output bytes: `Fixture`'s `serde::Serialize` impl $\to$ `SerdeEncoder` (`serde::Serializer`) $\to$ `bincode::enc::EncoderImpl`. More importantly, `bincode::config::standard()` selects `IntEncoding::Variable`:

```rust
// bincode 2.0.1, src/varint/encode_unsigned.rs (conceptual)
if val <= SINGLE_BYTE_MAX as _ {
    writer.write(&[val as u8])
} else if val <= u16::MAX as _ {
    writer.write(&[U16_BYTE])?; /* + 2 bytes */
} else {
    writer.write(&[U32_BYTE])?; /* + 4 bytes */
}
```

Every integer (`status`, `meta.version`, vector/string lengths, `qty`, `price_minor` across 8 items) executes magnitude comparisons and tag branches. Small integers collapse to 1 byte (shrinking total wire size from 214 B down to 122 B), at the expense of per-integer branching and `Serde` visitor dispatch on both encode and decode.

| Operation on One `i32` Field | `Speedy` | `Bincode` (`Serde` + `standard()`) |
|---|---|---|
| **Dispatch** | Direct generated `self.status.write_to(w)` | `Serde::serialize_i32` $\to$ `IntEncoding::Variable` |
| **Wire bytes** | Always 4 bytes | 1, 3, or 5 bytes depending on magnitude |
| **Branching** | Zero magnitude branches on little-endian hosts | $\ge 2$ magnitude comparisons + tag write |

---

## Trade-Off Summary

| Engineering Axis | `Speedy` (Direct Fixed-Width) | `Bincode` (`Serde` + `standard()`) |
|---|---|---|
| **CPU latency** | Minimal (straight-line copies) | Higher (visitor + varint branches) |
| **Wire compactness** | Larger (214 B) due to fixed 32/64-bit widths | Compact (122 B) via variable-length integers |
| **Ecosystem reuse** | Requires dedicated `Readable`/`Writable` derives | Reuses universal `Serde` traits shared with JSON, CBOR, MessagePack |
| **Cross-language / evolution** | Neither crate provides field numbers or cross-language specs | Rust-centric positional binary; breaks on middle-field insertions |

---

## Exercises

1. **Hand-compute `Speedy` wire size:** On a little-endian host, compute the exact byte count `Speedy` writes for a single `DocumentItem { sku: "A", qty: 1_i32, price_minor: 2_i64 }` (where string length is a `u32`).

??? note "Solution"
    - `sku` length (`u32`): 4 bytes (`01 00 00 00`)
    - `sku` UTF-8 bytes (`"A"`): 1 byte (`41`)
    - `qty` (`i32`): 4 bytes (`01 00 00 00`)
    - `price_minor` (`i64`): 8 bytes (`02 00 00 00 00 00 00 00`)
    - **Total:** $4 + 1 + 4 + 8 = \mathbf{17\text{ bytes}}$. (By contrast, `Bincode` `standard()` encodes the same item in $1 + 1 + 1 + 1 = \mathbf{4\text{ bytes}}$!)

2. **Two targeted experiments on `Bincode`:** Name *(a)* one change to the `Bincode` runner that narrows the **speed gap** while keeping 122-byte varint output, and *(b)* one configuration change that trades away `Bincode`'s **size advantage** to approach `Speedy`'s speed.

??? note "Solution"
    - *(a)* Encode the inner `Document` directly via `Bincode` 2's native `#[derive(bincode::Encode, bincode::Decode)]` instead of going through the `Fixture` enum and `Serde` visitor.
    - *(b)* Switch `bincode::config::standard()` to `bincode::config::legacy()` (or `.with_fixed_int_encoding()`), eliminating per-integer varint branching while expanding wire size toward `Speedy`'s 214 bytes.

3. **Payload sensitivity:** Why would the $2.2\times$ speed ratio between `Speedy` and `Bincode` narrow sharply on a payload containing a single 64 KB UTF-8 string and two integers?

??? note "Solution"
    On a 64 KB string, both libraries spend >99% of encode/decode time inside `memcpy` and UTF-8 validation of the string bytes. Per-integer varint branching and `Serde` visitor overhead on two integers become negligible as a fraction of total runtime.

---

## References

[^1]: Bujak, J. (`koute`). *`speedy`: Fast Rust Binary Serialization*. <https://github.com/koute/speedy>
[^2]: Bincode Contributors. *`bincode` 2.0 Configuration and Varint Encoding*. <https://github.com/bincode-org/bincode>
[^3]: Tryzelaar, E., & Tolnay, D. *Serde Data Model and Trait Architecture*. <https://serde.rs/>
