# Swift: why FlatBuffers outruns SwiftProtobuf on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **FlatBuffers** finishes more encode-and-decode cycles per second than **SwiftProtobuf**, while writing a **larger** message (440 bytes versus 155). Smaller is not faster. The two libraries are optimizing different moments: FlatBuffers arranges the buffer so a field is an offset plus a load; SwiftProtobuf writes a compact tag stream and must parse that stream to recover a field.

This page compares the two timed wrappers and the generated code they call.

Numbers are from the committed Swift **Results** snapshot. See [Swift Results](../../swift/results.md).

## Short answer

FlatBuffers wins the stopwatch because encode and decode are **table construction and offset arithmetic**. SwiftProtobuf wins the tape measure because encode is **tags plus variable-length integers** and there is no vtable.

The runner is not perfectly symmetric. FlatBuffers *times* the copy into the suite’s domain `Document`. SwiftProtobuf’s timer stops at a generated `Message`; the later domain copy is off the clock. FlatBuffers still wins while doing more of the application’s work.

| | FlatBuffers | SwiftProtobuf |
|--|-------------|---------------|
| Mean encode + decode, document, *n* = 1 | **132 thousand / s** | 114 thousand / s |
| Encode | **3782 ns** | 4510 ns |
| Decode | **3822 ns** | 4257 ns |
| Encoded size | 440 B | **155 B** |

## The two timed call sites

**FlatBuffers** (`swift/Sources/SerializerBenchmarkCore/Serializers/FlatBuffersSer.swift`) reuses a builder and calls a bound encode function:

```swift
public func serializeBytes(_ fixture: Fixture) throws -> Data {
    guard let encodeFn else { throw BenchError.prepareRequired }
    builder.clear()
    return try encodeFn(&builder, fixture)
}
```

Document encode (`FlatBuffersBridge.swift`) creates strings, nested tables, a vector of item offsets, then a `FixtureRoot` wrapper:

```swift
let id = fbb.create(string: d.id)
let region = fbb.create(string: d.meta.region)
let meta = benchmark_v2_DocumentMeta.createDocumentMeta(...)
for it in d.items {
    let sku = fbb.create(string: it.sku)
    itemOffs.append(benchmark_v2_DocumentItem.createDocumentItem(...))
}
let items = fbb.createVector(ofOffsets: itemOffs)
return benchmark_v2_Document.createDocument(...)
```

`endTable` writes a **vtable**: a small table of 16-bit offsets that says where each field lives (`FlatBufferBuilder.endTable`).

**SwiftProtobuf** converts the domain object in untimed `prepare`, then times `serializedData()` / `init(serializedBytes:)` (`Protobuf.swift`):

```swift
public func serializeBytes(_ fixture: Fixture) throws -> Data {
    return try native.serializedData()
}
public func deserializeBytes(_ data: Data) throws -> Any {
    return try decodeNative(data)
}
```

`serializedData()` first walks the message to compute the size, allocates `Data` of that length, then walks again to write (`Message+BinaryAdditions.swift`). Each present field is a tag plus a payload:

```swift
// Generated Document.traverse
if !self.id.isEmpty {
    try visitor.visitSingularStringField(value: self.id, fieldNumber: 1)
}
if self.status != 0 {
    try visitor.visitSingularInt32Field(value: self.status, fieldNumber: 2)
}
```

```swift
// BinaryEncoder.startField
mutating func startField(tag: FieldTag) {
    putVarInt(value: UInt64(tag.rawValue))   // (field << 3) | wire type
}
```

## Why 440 bytes versus 155

The information is the same. The layout is not.

| Cost in FlatBuffers | Cost in Protocol Buffers |
|---------------------|--------------------------|
| A vtable per table (Document, Meta, each Item, plus `FixtureRoot`) | A one-byte tag for field numbers 1–4 |
| Four-byte offsets to strings, vectors, and nested tables | A variable-length length plus UTF-8 |
| `Int32` / `Int64` stored at full width, with alignment padding | Variable-length integers (a small `status` is one byte) |
| A vector of eight item *offsets* (32 bytes) plus eight item tables | Eight tagged nested messages |
| An extra 11-slot `FixtureRoot` so one buffer can hold any fixture kind | The root *is* the `Document` |

440 bytes is close to JSON’s 448 on this fixture because both pay a per-field directory (vtables or names) plus padding. 155 bytes is the compact tag stream taught in the [Protocol Buffers wire format](protobuf-wire-format.md) article.

**History.** [Wouter van Oortmerssen](https://en.wikipedia.org/wiki/Wouter_van_Oortmerssen) released FlatBuffers at Google around 2014 so that games and mobile clients could read a field without building a parallel object tree. Kenton Varda’s Cap’n Proto (2013) is the sibling idea. Protocol Buffers (open-sourced 2008) optimized the opposite moment: many small service messages, density, and skip-based evolution. See [201 in-place access](../201/zero-copy.md) and the [historical perspective](../101/historical_perspective.md).

## Why FlatBuffers is still faster here

Decode of a FlatBuffers `status` is: look up a 16-bit slot in the vtable, then load a little-endian `Int32`. There is no variable-length integer loop.

```swift
// generated accessor
public var status: Int32 {
    let o = _accessor.offset(VTOFFSET.status.v)
    return o == 0 ? 0 : _accessor.readBuffer(of: Int32.self, at: o)
}
```

SwiftProtobuf decode is `nextFieldNumber()` (a variable-length integer) in a loop, then a `switch` that fills properties. Encode pays *two* visits (size, then write) and a tag per field.

On a document with eight items, eight vtables plus padding still cost less processor time in this runner than eight nested tag loops. The extra bytes are sequential and cheap. The extra branches are not.

This suite does **not** stop at a FlatBuffers view. `documentDomain` copies strings and items into the suite `Document`, and that copy is on the clock. A production reader that only needed `status` could skip that copy. The comparison is therefore conservative toward SwiftProtobuf.

## What you give up

| Axis | FlatBuffers | SwiftProtobuf |
|------|-------------|---------------|
| Size on this fixture | Larger (vtables, padding, root wrapper) | Smaller (tags, varints) |
| Read one field | Offset + load | Must parse up to that field (or the whole message, as timed) |
| Evolution | Schema + vtable slots | Field numbers, skip unknowns |
| Mutation | Rebuild the buffer | Rebuild the message and encode |
| Debugging | Needs a FlatBuffers inspector | Still opaque without the `.proto`, but smaller |

If the document is a public log, SwiftProtobuf’s 155 bytes and skip rules are the reason it exists. If the document is a large catalogue and the interface only needs three fields, FlatBuffers’ layout is the reason *it* exists.

## Self-check

1. Why can FlatBuffers be both larger and faster on the same record?
2. Which bytes in the 440-byte image have no counterpart in the 155-byte image?
3. The runner times FlatBuffers’ domain copy and does not time SwiftProtobuf’s. In which direction does that bias the rank?
