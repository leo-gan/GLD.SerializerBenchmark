# Rust: Speedy versus Postcard — fixed widths versus compact integers

## Why this article exists

[Speedy versus Bincode](rust-speedy-vs-bincode.md) showed that leaving Serde and writing fixed-width integers makes encode fast and messages **larger**. A student can fairly ask whether compactness requires leaving Serde. **Postcard** stays on Serde, writes variable-length integers, and on this suite’s **document** fixture it is both smaller than Bincode and faster than Bincode. It is still slower than Speedy.

This page holds “no field names” still and compares two compact binaries: Speedy’s native `Writable` with four- and eight-byte integers, versus Postcard’s Serde encoder with postcard-varints.

Numbers are from the committed Rust **Results** snapshot (document, one instance). See [Rust Results](../../rust/results.md).

## Short answer

Both omit names. Speedy copies each integer at its native width and each length as a `u32`. Postcard writes a **variable-length integer** (seven data bits per byte, high bit continues) for integers, lengths, and the `Fixture` variant index. Small numbers become one byte. That is why Postcard is **114 bytes** and Speedy is **214**. Speedy still wins the stopwatch because it never asks “how many bytes does this need?” and it never visits Serde.

| | Speedy 0.8.7 | Postcard 1.1.3 | Bincode 2.0.1 |
|--|--------------|----------------|---------------|
| Mean encode + decode | **2.84 million / s** | 1.73 million / s | 1.29 million / s |
| Encode | **88 ns** | 163 ns | 203 ns |
| Decode | **264 ns** | 414 ns | 573 ns |
| Encoded size | 214 B | **114 B** | 122 B |

Postcard is the size winner of the fast Rust binaries. Speedy is the speed winner. Bincode is neither.

## The two timed call sites

**Speedy** writes a `Document` (`rust/src/serializers/direct.rs`):

```rust
v.write_to_stream(&mut *out)?;
// decode:
Document::read_from_buffer(d)
```

**Postcard** writes the `Fixture` enumeration through Serde (`rust/src/serializers/binary_serde.rs`):

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

`to_extend` appends into an existing `Vec<u8>` (Postcard 1.1.3, `src/ser/mod.rs`). That is kinder to allocation than “return a new vector.” It is still a Serde visit of `Fixture`, which begins with a variant index. Speedy never writes that index. Part of the time gap is this wrapper. The larger part is integer width.

## What Speedy stores

A derived `write_to` emits, for each string, a **32-bit length** and the bytes; for each `i32`, four bytes; for each `i64`, eight. On a little-endian host those stores are copies. See the Speedy/Bincode page for the generated skeleton and `write_u32`.

## What Postcard stores

Postcard (James Munns and the Ferrous Systems community, late 2010s) was written for **embedded** programs: `no_std`, small messages, no heap required if you encode into a stack buffer. Compactness is the point. Integers use a postcard-varint — the same family as Protocol Buffers varints:

```rust
// postcard 1.1.3, src/varint.rs
pub fn varint_u32(n: u32, out: &mut [u8; varint_max::<u32>()]) -> &mut [u8] {
    let mut value = n;
    for i in 0..varint_max::<u32>() {
        out[i] = value.to_le_bytes()[0];
        if value < 128 {
            return &mut out[..=i];
        }
        out[i] |= 0x80;
        value >>= 7;
    }
    &mut out[..]
}
```

The Serde serializer calls that helper for `u16`/`u32`/`u64`, for string lengths, and for sequence lengths (`src/ser/serializer.rs`). A `status` of `1` is one byte. Speedy always writes four. Eight line items, each with a small `qty` and a modest `price_minor`, add up to the 100-byte gap.

Decode walks the same varints in reverse (`try_take_varint_u32`). Each integer is a short loop rather than a four-byte load. That is the 414 ns versus 264 ns.

**History.** Variable-length integers are an old density trick: ASN.1 length octets, then Protocol Buffers varints (Google, 2000s), then Avro zigzag, then Postcard for microcontrollers. Speedy’s fixed widths are the other old trick: XDR and packed records. This pair is those two bets on the same Rust `Document`. See [Historical perspective](../101/historical_perspective.md).

## Side-by-side: one small `i32`

| Step | Speedy | Postcard |
|------|--------|----------|
| How the field is reached | Generated `write_to` | Serde `serialize_i32` |
| Bytes for `qty = 2` | 4 (`02 00 00 00`) | 1 (`02`) |
| Bytes for a length 3 string | 4 + 3 | 1 + 3 |
| Branches | Endian swap if needed (none here) | “Is it less than 128?” per integer |

Postcard still beats Bincode because its Serde encoder is thinner (no `standard()` width tags such as “this is a two-byte int”) and because `to_extend` reuses the runner’s vector. The idea — variable-length integers — is the same family as Bincode’s `standard()` config. The engineering is tighter.

## What you give up

| Axis | Speedy | Postcard |
|------|--------|----------|
| Size on this document | Larger | Smaller |
| Encode/decode time | Smaller | Larger |
| Another language | No public spec | Documented postcard layout, still Rust-first |
| Embedded / `no_std` | Possible, not the design centre | The design centre |
| Evolution | Reorder breaks readers | Reorder breaks readers (no field numbers) |

Neither library is a multi-language service contract. For that, this suite’s `prost` row (155 B, 841 thousand / s on this fixture) is the Protocol Buffers answer. Postcard versus Speedy is a lesson about **width**, not about schemas.

## Self-check

1. Using `varint_u32`, how many bytes is `qty = 2`? How many is Speedy’s `i32`?
2. Name one reason Postcard can stay on Serde and still beat Bincode.
3. Why is this pair a better “size versus speed” lesson than Speedy versus Bincode alone?
