# Rust: why Speedy outruns Bincode on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **Speedy** finishes about **2.2 times** as many encode-and-decode cycles per second as **Bincode**. Both libraries write a compact binary image of the same Rust struct. Neither prints JSON. Neither looks up field names at run time. A results table therefore cannot tell you *which lines of code* create the gap.

This page walks through the two call paths as they exist in this repository and in the crates those paths invoke. After reading it you should be able to point at the generated Speedy `write_to` body and at Bincode’s Serde encoder and say what extra work Bincode performs on every integer, every string, and every `Document`.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data (`speedy:0.8.7`, `bincode:2.0.1`). They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=rust&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=speedy&ser=speedy&ser=bincode#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Rust overview](../../rust/)

## Short answer

Speedy is faster because it does **less work per field**, not because it has a hidden algorithm.

1. **Speedy writes the concrete `Document`.** The timed function already knows the type. The compiler emits one straight-line `write_to` that stores each field in declaration order.
2. **Bincode writes through Serde.** The timed function accepts the `Fixture` enumeration and asks Serde to *visit* it. Each field becomes a virtual call into `serialize_i32`, `serialize_str`, and so on. Those methods then encode the value.
3. **Speedy stores integers at their native width** (four bytes for `i32`, eight for `i64`) and stores every length as a 32-bit count. There is no per-value size test.
4. **Bincode’s `standard()` configuration uses variable-length integers.** Every number is inspected: “does this fit in one byte? in two? in four?” That saves space (122 bytes versus Speedy’s 214) and costs branches.

The advantage is therefore a pair of engineering choices: **specialize the encode function for one type**, and **never ask “how many bytes does this integer need?”** The cost of the second choice is a larger message.

| | Speedy 0.8.7 | Bincode 2.0.1 |
|--|--------------|---------------|
| Mean encode + decode, document, *n* = 1 | **2.84 million / s** | 1.29 million / s |
| Encode time | 88 ns | 203 ns |
| Decode time | 264 ns | 573 ns |
| Encoded size | 214 B | **122 B** |

Speedy is the speed winner. Bincode is the size winner of this pair. **Postcard** (1.73 million / s, 114 B) sits between them and is the size leader among the fast Rust binaries. This page stays with Speedy versus Bincode, as those two make the design contrast sharpest.

## Prerequisites

- Intermediate Rust: traits, `Vec<u8>`, what a `derive` macro emits.
- [Encode and decode cost](../201/encode-decode-cost.md) (allocation, copying, numeric conversion).
- Optional: [Rust: prost](protobuf-rust-prost.md) if you want the same “per-type specialized code” idea on Protocol Buffers.

## The two timed call sites

Both libraries are registered in the Rust benchmark runner. They do **not** share a call shape.

**Speedy** binds a per-kind function pointer in untimed `prepare`, then writes the inner struct:

```rust
// rust/src/serializers/direct.rs — timed encode
fn speedy_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    use speedy::Writable;
    let Fixture::Document(v) = fx else {
        bail!("speedy: expected Document");
    };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
```

Decode is equally direct:

```rust
// rust/src/serializers/direct.rs — timed decode
Document::read_from_buffer(d)
```

The `match` that distinguishes `Document` from `Message` runs in `prepare`, outside the timed loop (`rust/src/serializers/kinded.rs`). The timed encode is one indirect call to a function that already knows it has a `Document`.

**Bincode** goes through Serde and through the `Fixture` enumeration:

```rust
// rust/src/serializers/binary_serde.rs — timed encode and decode
fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    bincode::serde::encode_into_std_write(fixture, out, self.config)?;
    Ok(())
}
fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
    let (v, _): (Fixture, usize) = bincode::serde::decode_from_slice(data, self.config)?;
    Ok(v)
}
```

`Fixture` is an externally tagged enumeration (`rust/src/data.rs`):

```rust
pub enum Fixture {
    Message(Message),
    Document(Document),
    Telemetry(Telemetry),
    Strings(Strings),
    Event(Event),
}
```

So the first thing Bincode writes is a **variant index**, and the first thing it reads is that index plus a full `Fixture`. Speedy never writes that tag. Part of the measured gap is this wrapper difference. The larger part, as the crate sources show, is still inside the two libraries.

The configuration Bincode uses is `bincode::config::standard()`:

```rust
// rust/src/serializers/binary_serde.rs
impl Default for BincodeSer {
    fn default() -> Self {
        Self {
            config: bincode::config::standard(),
        }
    }
}
```

The crate documents what `standard()` means (`bincode` 2.0.1, `src/config.rs`):

```rust
/// The default config for bincode 2.0. By default this will be:
/// - Little endian
/// - Variable int encoding
pub const fn standard() -> Configuration {
    generate()
}
```

That second bullet is the size/speed fork.

## What Speedy generates for `Document`

`Document` derives Speedy’s `Writable` and `Readable` next to its fields (`rust/src/data.rs`). The derive crate emits an `impl Writable` whose `write_to` is a straight sequence of field writes (`speedy-derive` 0.8.7). For a named struct the skeleton is:

```rust
// speedy-derive 0.8.7 — generated impl skeleton
impl<C_: speedy::Context> speedy::Writable<C_> for Document {
    fn write_to<T_: ?Sized + speedy::Writer<C_>>(
        &self,
        _writer_: &mut T_,
    ) -> Result<(), C_::Error> {
        // one write per field, in declaration order
        Ok(())
    }
}
```

Each string or vector is a **fixed 32-bit length** plus the payload. The derive crate hard-codes that default (`speedy-derive` 0.8.7):

```rust
const DEFAULT_LENGTH_TYPE: BasicType = BasicType::U32;
// ...
speedy::private::write_length_u32(name.len(), _writer_)?;
_writer_.write_slice(name.as_bytes())?;
```

After expansion, writing one `Document` is conceptually:

```text
write u32 length of id;           write id bytes
write i32 status as 4 bytes
write u32 length of meta.region;  write region bytes
write i32 meta.version as 4 bytes
write u32 items.len()
for each item:
    write u32 length of sku; write sku bytes
    write i32 qty as 4 bytes
    write i64 price_minor as 8 bytes
```

An `i32` is always four bytes. There is no “is this value small?” test. The writer copies the bits:

```rust
// speedy 0.8.7, src/writer.rs
fn write_u32(&mut self, mut value: u32) -> Result<(), C::Error> {
    self.context().endianness().swap_u32(&mut value);
    let slice = unsafe {
        std::slice::from_raw_parts(&value as *const u32 as *const u8, 4)
    };
    self.write_bytes(slice)
}
```

On a little-endian host the swap is a no-op. A string is the same idea: treat the UTF-8 bytes as a slice and copy them. A `Vec` of primitive values can be copied as one block when no endian conversion is required (`write_slice` in the same file).

The public entry the runner uses is `write_to_stream`, which wraps the `Vec<u8>` in a `std::io::Write` collector and calls `write_to`. After inlining, the timed encode is close to a handful of `memcpy`s.

**History.** Speedy (Koute, mid-2010s) was written for games and tools that already trust the record shape and want the processor to *store* fields, not *interpret* them. That is the same pressure that produced packed records in the 1950s–1960s and Sun’s XDR in 1987: declare the order and the widths, then copy. See [Historical perspective](../101/historical_perspective.md). Speedy is not XDR; it is native-endian by default and is not a public interchange standard. The *idea* — fixed widths, no names — is the old one.

## What Bincode does on the same `Document`

Bincode 2 still has a native `Encode` trait. This suite does **not** call it. The runner uses the **Serde** feature:

```rust
// bincode 2.0.1, src/features/serde/ser.rs
pub fn encode_into_std_write<E: Serialize, C: Config, W: std::io::Write>(
    val: E,
    dst: &mut W,
    config: C,
) -> Result<usize, EncodeError> {
    let writer = crate::IoWriter::new(dst);
    let mut encoder = crate::enc::EncoderImpl::<_, C>::new(writer, config);
    let serializer = SerdeEncoder { enc: &mut encoder };
    val.serialize(serializer)?;
    Ok(encoder.into_writer().bytes_written())
}
```

Three objects now sit between `Document` and the output bytes:

1. Serde’s `serialize` implementation on `Fixture` (variant index, then the struct).
2. `SerdeEncoder`, which implements Serde’s `Serializer` trait.
3. `EncoderImpl`, which finally writes bytes.

A struct does not become a packed image in one step. Serde calls `serialize_struct`, then `serialize_field` for every field. Each integer goes through `serialize_i32` → `i32::encode`. Because the config is `standard()`, `encode` for a 32-bit integer is **not** “write four bytes”:

```rust
// bincode 2.0.1, src/enc/impls.rs
impl Encode for u32 {
    fn encode<E: Encoder>(&self, encoder: &mut E) -> Result<(), EncodeError> {
        match E::C::INT_ENCODING {
            IntEncoding::Variable => {
                crate::varint::varint_encode_u32(encoder.writer(), E::C::ENDIAN, *self)
            }
            IntEncoding::Fixed => /* always 4 bytes */,
        }
    }
}
```

Variable-length encoding tests the magnitude on every value (`src/varint/encode_unsigned.rs`):

```rust
pub fn varint_encode_u32<W: Writer>(writer: &mut W, endian: Endianness, val: u32)
    -> Result<(), EncodeError>
{
    if val <= SINGLE_BYTE_MAX as _ {
        writer.write(&[val as u8])
    } else if val <= u16::MAX as _ {
        writer.write(&[U16_BYTE])?;
        // then two bytes
    } else {
        writer.write(&[U32_BYTE])?;
        // then four bytes
    }
}
```

A small `qty` or `status` becomes one byte. A large `price_minor` becomes a tag plus eight bytes. That is why Bincode’s document is **122 bytes** and Speedy’s is **214**. It is also why encode takes more than twice as long: every integer is a chain of comparisons, and every field is a Serde visit, not a store.

Decode is the same pipeline in reverse. Speedy’s `read_from_buffer` walks the known layout and fills a `Document`. Bincode’s `decode_from_slice` reconstructs a `Fixture` through Serde’s visitor, branching on integer width as it goes. That matches the measured 264 ns versus 573 ns.

**History.** [Serde](https://serde.rs/) (Erick Tryzelaar, David Tolnay, and contributors; 2015 onward) gave Rust one data model so that JSON, MessagePack, Bincode, and many other formats could share a single `Serialize` implementation. The benefit is enormous for a language ecosystem. The cost on a tight encode path is exactly what you see here: an intermediate visitor that does not know Bincode’s layout. Bincode itself began as a simple Rust binary format (Ty Overby and contributors, mid-2010s). Version 2 split “native `Encode`” from “Serde front end” and made variable-length integers the default so that typical structs would be small. This suite measures the Serde front end with that default.

## Side-by-side: one `i32` field

Take `Document.status`, an `i32`.

| Step | Speedy | Bincode (Serde + `standard()`) |
|------|--------|--------------------------------|
| How the field is reached | Generated `self.status.write_to(writer)` | `serialize_i32` on the Serde encoder |
| How many bytes | Always 4 | 1, 2+1, or 4+1, depending on magnitude |
| Branches | Endian swap if the host is not little-endian (none on this machine) | At least two magnitude tests, then a write |
| What the CPU does | Copy four bytes | Compare, choose a tag, copy one to four bytes |

Repeat that for every integer on every item in `items`. Document fixtures carry a short list of line items. The per-integer tax adds up.

## Side-by-side: the `items` vector

Speedy writes a `u32` count and then each `DocumentItem` with the same fixed layout. If the element type were a primitive, `write_slice` could copy the whole array as one byte block. `DocumentItem` is a struct, so the loop remains, but it is still a specialized loop.

Bincode, through Serde, calls `serialize_seq` with a length, encodes that length as a variable-length integer, then visits each element as a struct of three fields. Three more visitor calls per item (`sku`, `qty`, `price_minor`).

## What you give up to obtain Speedy’s speed

| Axis | Speedy’s choice | Consequence |
|------|-----------------|-------------|
| Integer width | Fixed | Faster; **larger** messages (214 B vs 122 B here) |
| Schema | The Rust type *is* the contract | Another language cannot read the bytes without a matching layout |
| Evolution | No field numbers, no skip rule | Adding a field in the middle breaks old readers |
| API surface | Own `Readable` / `Writable` traits | You derive Speedy in addition to (or instead of) Serde |
| Safety on untrusted input | Bounds-checked reads, not a full verifier | Still your responsibility; see [301 untrusted input](../301/untrusted-input.md) |

Bincode’s Serde path is the better default when the same struct must also speak JSON or MessagePack, or when message size on the network matters more than a few hundred nanoseconds. Postcard in this suite is the reminder that you can stay on Serde, keep variable-length integers, and still be faster than Bincode — it writes the `Fixture` with a tighter encoder (`postcard::to_extend`). Speedy still wins the stopwatch because it leaves Serde entirely. That pair is written out in [Speedy versus Postcard](rust-speedy-vs-postcard.md). In-place archives are a different lesson: [rkyv versus Speedy](rust-rkyv-vs-speedy.md).

## Honesty

1. **The wrapper is not identical.** Speedy encodes a `Document`. Bincode encodes a `Fixture`. A fairer Bincode call would be `encode_into_std_write(document, …)` on the inner struct, or Bincode’s native `Encode` derive without Serde. The suite measures the Serde integration because that is how Bincode is usually used.
2. **`standard()` is a choice.** `bincode::config::legacy()` uses fixed-width integers and would move Bincode toward Speedy’s size/speed point. It is not what this runner configures.
3. **The Dashboard owns the numbers.** Payload shape changes the ratio. A document with huge strings spends most of its time copying UTF-8; the integer tax shrinks as a fraction.
4. This page does not say “Rust wins.” It says why **one Rust library** outruns **another Rust library** on this fixture.

## Self-check

1. Write the bytes Speedy emits for `DocumentItem { sku: "A", qty: 1, price_minor: 2 }` on a little-endian machine (length as `u32`, then one byte `'A'`, then `i32`, then `i64`). How many bytes is that?
2. Argue, from the `varint_encode_u32` listing, why the same item is shorter in Bincode and why encoding it is slower.
3. Name one change to the Bincode wrapper that would shrink the speed gap without changing Speedy. Name one change that would shrink Bincode’s *size* advantage.
4. Why is Postcard smaller than Speedy and still slower, given that both omit field names?
