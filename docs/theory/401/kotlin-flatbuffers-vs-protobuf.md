# Kotlin: why FlatBuffers outruns protobuf-java on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **FlatBuffers** finishes more encode-and-decode cycles per second than **protobuf-java**, while writing a **larger** message (416 bytes versus 155). Smaller is not faster. The two libraries are optimizing different moments: FlatBuffers arranges the buffer so a field is an offset plus a load; Protocol Buffers writes a compact tag stream and must parse that stream to recover a field.

This page compares the two timed wrappers on the Kotlin harness. The Swift pair of the same two formats is [Swift: FlatBuffers vs SwiftProtobuf](swift-flatbuffers-vs-protobuf.md).

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=kotlin&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=flatbuffers&ser=flatbuffers&ser=protobuf#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Kotlin overview](../../kotlin/)

## Short answer

FlatBuffers is faster than protobuf-java on this slice (about 23 thousand versus 13 thousand cycles per second). protobuf-java writes the smaller message (155 bytes versus 416). We can see both facts in the table.

FlatBuffers is faster because encode and decode are **table construction and offset arithmetic**: a field is a vtable slot plus a load. protobuf-java writes fewer bytes because encode is **field numbers plus variable-length integers** and there is no vtable. Smaller is not faster here.

Both adapters time the same work: suite `Document` in, bytes, suite `Document` out. FlatBuffers still copies strings and items into the suite type on decode. protobuf-java copies a generated message into the same suite type. The pair is not biased by a view that skips the copy.

| | FlatBuffers | protobuf-java |
|--|-------------|---------------|
| Mean encode + decode, document, *n* = 1 | **23 thousand / s** | 13 thousand / s |
| Encode | **27 µs** | 39 µs |
| Decode | **18 µs** | 32 µs |
| Encoded size | 416 B | **155 B** |

## The two timed call sites

**FlatBuffers** (`kotlin/src/main/kotlin/benchmark/serializers/FlatBuffersSer.kt`) reuses a `FlatBufferBuilder` and times pack plus `finish`:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray {
    builder.clear()
    val root = if (batch) packList(fx.value as List<*>) else packOne(fx.value)
    builder.finish(root)
    val bb = builder.dataBuffer()
    val out = ByteArray(bb.remaining())
    bb.get(out)
    return out
}
```

Document encode creates strings, a nested meta table, a vector of item offsets, then the document table:

```kotlin
private fun packDocument(d: Document): Int {
    val id = builder.createString(d.id)
    val meta =
        DocumentMeta.createDocumentMeta(builder, builder.createString(d.meta.region), d.meta.version)
    val itemOffs =
        IntArray(d.items.size) { i ->
            val it = d.items[i]
            DocumentItem.createDocumentItem(builder, builder.createString(it.sku), it.qty, it.priceMinor)
        }
    return benchmark.fb.Document.createDocument(
        builder, id, d.status, meta, benchmark.fb.Document.createItemsVector(builder, itemOffs),
    )
}
```

`createDocument` writes a **vtable**: a small table of 16-bit offsets that says where each field lives.

Decode wraps the bytes and copies into the suite `Document`:

```kotlin
private fun fromDocument(d: benchmark.fb.Document): Document {
    val metaSrc = d.meta()
    val meta = benchmark.model.v2.DocumentMeta(metaSrc?.region() ?: "", metaSrc?.version() ?: 0)
    val items =
        MutableList(d.itemsLength()) { i ->
            val src = d.items(i)!!
            benchmark.model.v2.DocumentItem(src.sku() ?: "", src.qty(), src.priceMinor())
        }
    return Document(d.id() ?: "", d.status(), meta, items)
}
```

Each accessor is a vtable slot plus a load. The copy into the suite type is timed.

**protobuf-java** (`kotlin/src/main/kotlin/benchmark/serializers/ProtobufSer.kt`) copies the suite value into a generated message on the clock, then writes tags:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray = toProto(fx).toByteArray()
override fun deserializeBytes(data: ByteArray): Any =
    fromProto(typeId, batch, parser.parseFrom(data))
```

`toByteArray()` walks field numbers and variable-length integers. `parseFrom` builds the generated graph, then `fromProto` copies that graph into a suite `Document`. Both copies are timed.

## Why 416 bytes versus 155

The information is the same. The layout is not.

| Cost in FlatBuffers | Cost in Protocol Buffers |
|---------------------|--------------------------|
| A vtable per table (Document, Meta, each Item) | A one-byte header for field numbers 1–4 |
| Four-byte offsets to strings, vectors, and nested tables | A variable-length length plus UTF-8 |
| `Int32` / `Int64` stored at full width, with alignment padding | Variable-length integers (a small `status` is one byte) |
| A vector of eight item *offsets* plus eight item tables | Eight tagged nested messages |

416 bytes is close to JSON’s 440 on this fixture because both pay a per-field directory (vtables or names) plus padding. 155 bytes is the compact Protocol Buffers layout taught in the [Protocol Buffers wire format](protobuf-wire-format.md) article.

The Kotlin FlatBuffers row is 416 bytes, not the 440 bytes on the Swift page. Swift wraps every fixture in a `FixtureRoot` table. Kotlin writes the `Document` table as the buffer root.

## Why FlatBuffers is still faster here

Decode of a FlatBuffers `status` is: look up a 16-bit slot in the vtable, then load a little-endian `int`. There is no variable-length integer loop.

protobuf-java decode is `parseFrom` (a field-number loop, including eight nested items), then `fromProto`. Encode pays a `toProto` copy plus a tag write for every present field.

On a document with eight items, eight vtables plus padding still cost less processor time in this runner than eight nested field loops. The extra bytes are sequential and cheap. The extra branches are not.

This suite does **not** stop at a FlatBuffers view. `fromDocument` copies strings and items into the suite `Document`, and that copy is timed. protobuf-java pays the matching copy (`fromProto`) on the same clock. A production FlatBuffers reader that only needed `status` could still skip the copy.

## What you give up

| Axis | FlatBuffers | protobuf-java |
|------|-------------|---------------|
| Size on this fixture | Larger (vtables, padding) | Smaller (field numbers, varints) |
| Read one field | Offset + load | Must parse up to that field (or the whole message, as timed) |
| Evolution | Schema + vtable slots | Field numbers, skip unknowns |
| Mutation | Rebuild the buffer | Rebuild the message and encode |
| Debugging | Needs a FlatBuffers inspector | Still opaque without the `.proto`, but smaller |

If the document is a public log, protobuf-java’s 155 bytes and skip rules are the reason it exists. If the document is a large catalogue and the interface only needs three fields, FlatBuffers’ layout is the reason *it* exists.

## Self-check

1. Why can FlatBuffers be both larger and faster on the same record?
2. Which bytes in the 416-byte image have no counterpart in the 155-byte image?
3. Both rows copy into a suite `Document` on the timed decode. What would change in the FlatBuffers rank if decode stopped at the vtable view and never copied?
