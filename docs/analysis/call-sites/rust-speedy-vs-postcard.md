# Rust: `Speedy` vs. `Postcard`

This note compares the Rust `speedy` and `postcard` binary adapters on the `document` ($n = 1$, `bytes` mode) payload. Both omit field names and write into runner-reused byte vectors; the comparison isolates fixed-width native stores (`Speedy`, **214 B**) against compact variable-length integers via `serde` (`Postcard`, **114 B**).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=rust&standard=custom&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=speedy&ser=speedy&ser=postcard#compare) · [Rust overview](../../rust/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `speedy` | `postcard` |
|---|---|---|
| Standard | `custom` (Rust-only fixed-width binary) | `custom` (`no_std`-oriented varint binary) |
| Encoded size (`document`, $n = 1$) | **214 B** | **114 B** (−100 B) |
| Integer & length encoding | Fixed-width native (`u32` lengths, 4 B `i32`, 8 B `i64`) | Base-128 unsigned/zigzag varints (1 B for values $< 128$) |
| Timed value boundary | Direct `Document` struct (`Writable` / `Readable`) | Runner `Fixture` enum via `serde` (includes variant index) |
| Output buffer policy | Reused `&mut Vec<u8>` (`write_to_stream`) | Reused `Vec<u8>` via `postcard::to_extend` |

## Timed Call Sites

**`speedy`** (`rust/src/serializers/direct.rs`) bypasses `serde` and invokes derived fixed-width traits directly on `Document`:

```rust
v.write_to_stream(&mut *out)?;
// decode:
Document::read_from_buffer(d)
```

**`postcard`** (`rust/src/serializers/binary_serde.rs`) encodes the runner's `Fixture` enum through `serde` into the reused output vector:

```rust
fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let filled = postcard::to_extend(fixture, std::mem::take(out))?;
    *out = filled;
    Ok(())
}
fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
    Ok(postcard::from_bytes(data)?)
}
```

## Mechanistic Analysis and Scope Limits

1. **Exact 100-byte size trade-off (214 B vs. 114 B):** `Speedy` stores every string/vector length as a 4-byte `u32`, every `i32` as 4 bytes, and every `i64` as 8 bytes using unbranched little-endian copies. `Postcard` encodes lengths and integers with continuation-bit varint loops (`varint_u32`), shrinking small counts, `status`, `qty`, and `price_minor` to 1–3 bytes at the cost of per-integer bit-shifting and branching on both encode and decode.
2. **Wrapper asymmetry (`Document` vs. `Fixture`):** Part of the CPU gap reflects `Postcard` routing through `serde` and encoding the outer `Fixture` enum discriminant, whereas `Speedy` operates directly on `Document` (the same documented asymmetry examined in [4.9 Rust: `Speedy` vs. `Bincode`](../../theory/401/rust-speedy-vs-bincode.md)). Even among `serde` crates, `Postcard`'s thin encoder and `to_extend` reuse typically outperform `Bincode`'s `standard()` configuration.
3. **Evolution trade-off:** Neither positional format carries field tags; reordering struct fields breaks existing wire bytes. For a cross-language schema-evolving Rust codec, see `prost` ([4.4 Rust: `prost`](../../theory/401/protobuf-rust-prost.md)).
