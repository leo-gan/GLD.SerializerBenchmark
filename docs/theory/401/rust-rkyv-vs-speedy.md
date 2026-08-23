# Rust: why rkyv does not beat Speedy when you rebuild a `Document`

## Why this article exists

rkyv is designed so a reader can use the received buffer **in place**. Product language calls that zero-copy. On this suite’s **document** fixture, one instance, **Speedy** is still faster, and rkyv’s message is **larger**. The Results page already notes that timed rkyv decode **materializes owned values**. This page opens those two call sites and the library functions they invoke, so the note becomes something you can see in code.

After reading it you should be able to say what `rkyv::from_bytes` does that `rkyv::access` would not, and why an in-place layout can lose a stopwatch that demands a `Document`.

Numbers are from the committed Rust **Results** snapshot. See [Rust Results](../../rust/results.md).

## Short answer

In-place access is an **application-programming-interface**, not a prize you collect by choosing a crate. This runner asks both libraries for an owned `Document`. Speedy reads a packed image into that struct. rkyv first builds an archived layout (alignment, relative pointers), then **deserializes that archive into a second owned `Document`**. You pay construction and you pay a classical copy. Decode is not faster. Encode is much slower. Size grows because of padding.

| | Speedy 0.8.7 | rkyv 0.8.17 (as timed) |
|--|--------------|------------------------|
| Mean encode + decode, document, *n* = 1 | **2.84 million / s** | 1.64 million / s |
| Encode | **88 ns** | 314 ns |
| Decode | **264 ns** | 296 ns |
| Encoded size | **214 B** | 272 B |

A production reader that only needed `status` could call `rkyv::access` and load one integer from the buffer. This suite does not time that path. It would be faster, and it would not produce a `Document` the fidelity check can compare field by field.

## The two timed call sites

**Speedy** writes the concrete struct into the runner’s `Vec<u8>` (`rust/src/serializers/direct.rs`):

```rust
fn speedy_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else { bail!("speedy: expected Document"); };
    v.write_to_stream(&mut *out)?;
    Ok(())
}
// decode:
Document::read_from_buffer(d)
```

**rkyv** allocates an aligned buffer, copies it into the runner’s vector, then on decode builds an owned value:

```rust
fn rkyv_ser_document(fx: &Fixture, out: &mut Vec<u8>) -> Result<()> {
    let Fixture::Document(v) = fx else { bail!("rkyv: expected Document"); };
    let bytes = rkyv::to_bytes::<rkyv::rancor::Error>(v)?;
    out.extend_from_slice(bytes.as_ref());
    Ok(())
}
fn rkyv_de_document(data: &[u8]) -> Result<Document> {
    rkyv::from_bytes::<Document, rkyv::rancor::Error>(data)
}
```

`from_bytes` is not “view the buffer.” In rkyv 0.8 it is access **plus** deserialize into `T` (`rkyv` `src/api/high/mod.rs` / `from_bytes`): validate the archive, then allocate strings and vectors that the `Document` owns.

The path this crate advertises for in-place reads is `access` / `access_unchecked`, which returns `&ArchivedDocument` into the byte slice. The runner does not call it, because the suite’s fidelity check compares owned domain values.

## What Speedy stores

Speedy’s derived `write_to` is a straight sequence of fixed-width stores: a `u32` length, then bytes; an `i32` as four bytes; an `i64` as eight. Details are on [Speedy versus Bincode](rust-speedy-vs-bincode.md). Decode is the inverse: read known widths into a `Document`. There is no archived twin type.

## What rkyv stores

rkyv (David Koloski, early 2020s) builds an **archive**: the on-the-wire layout *is* a relocatable image of the value. Strings and vectors become relative pointers and lengths, placed so that a later load from the buffer is a valid Rust reference after validation. `to_bytes` must:

1. walk the `Document`;
2. write those relative pointers and the pointed-to bytes;
3. satisfy alignment (often four or eight bytes), which inserts padding.

That is why encode is 314 ns rather than 88, and why the image is 272 bytes rather than 214. The extra bytes are not field names. They are the directory and padding that make in-place loads legal.

**History.** The idea is the same pressure that produced Cap’n Proto (Kenton Varda, 2013) and FlatBuffers (Wouter van Oortmerssen, 2014): do not build a second object tree if the program will only read a few fields. See [201 in-place access](../201/zero-copy.md) and the [historical perspective](../101/historical_perspective.md). rkyv brings that idea into Rust’s type system. It only helps if the timed path *stops* at the archived view.

## Side-by-side: what the clock includes

| Step | Speedy (timed) | rkyv as timed here | rkyv `access` (not timed) |
|------|----------------|--------------------|---------------------------|
| Encode | store fields into `out` | build aligned archive, then `extend_from_slice` | same archive |
| Decode | fill a `Document` | validate + fill a `Document` | return `&ArchivedDocument` |
| Read `status` | already in the struct | already in the struct | load four bytes at an offset |
| Fidelity check | compares two `Document`s | compares two `Document`s | would need a different check |

Decode times are close (264 ns versus 296 ns) because **both fill a `Document`**. rkyv’s extra work is validation and a less dense layout, not a free read.

## What you give up either way

If you use `access`, you must keep the buffer alive, you must validate untrusted bytes, and you must write the rest of the program against archived types. If you use `from_bytes`, you have an ordinary `Document` and you have paid Speedy’s kind of decode, plus archive construction. This suite chose the second path so that rkyv can sit on the same fidelity table as Speedy and Bincode. That is honest for comparison and unfair to rkyv’s advertised read path.

## Self-check

1. Quote the two rkyv calls in `direct.rs`. Which one is the in-place API, and which one does the runner use?
2. Why can rkyv be both larger and slower than Speedy *and* still be the right crate for a catalogue that is read field-by-field?
3. The [Swift FlatBuffers page](swift-flatbuffers-vs-protobuf.md) times a domain copy. How is that the same lesson as this page?
