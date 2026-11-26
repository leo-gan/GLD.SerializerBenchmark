# Kotlin: `FlatBuffers` vs. `protobuf`

This note inspects the Kotlin `flatbuffers` and `protobuf` (`protobuf-java`) adapters on the `document` ($n = 1$, `bytes` mode) payload. Both adapters time the identical end-to-end suite boundary (`Document` → bytes → `Document`), isolating the trade-off between FlatBuffers' larger offset/vtable buffer (**416 B**) and Protocol Buffers' compact tag-and-varint stream (**155 B**).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=kotlin&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=flatbuffers&ser=flatbuffers&ser=protobuf#compare) · [Kotlin overview](../../kotlin/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `flatbuffers` | `protobuf` (`protobuf-java`) |
|---|---|---|
| Standard | `flatbuffers` | `protobuf` |
| Encoded size (`document`, $n = 1$) | **416 B** | **155 B** |
| Wire organization | Vtables (16-bit offsets), 32-bit relative pointers, aligned fixed-width scalars | 1-byte field tags, base-128 varints, length-delimited submessages |
| Timed encode path | Reused `FlatBufferBuilder` (`clear` → `packOne` → `finish` → `ByteArray`) | `toProto(fx)` generated builder graph → `toByteArray()` |
| Timed decode path | Vtable offset loads → materialize suite `Document` | `parseFrom` generated message graph → `fromProto()` suite `Document` |

## Timed Call Sites

**`flatbuffers`** (`kotlin/src/main/kotlin/benchmark/serializers/FlatBuffersSer.kt`) clears and reuses a `FlatBufferBuilder`, packs nested strings/tables bottom-up with the `Document` table as buffer root, and copies fields into a suite `Document` on decode:

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

**`protobuf`** (`kotlin/src/main/kotlin/benchmark/serializers/ProtobufSer.kt`) builds an immutable generated message via `toProto` and parses/copies back on decode:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray = toProto(fx).toByteArray()
override fun deserializeBytes(data: ByteArray): Any =
    fromProto(typeId, batch, parser.parseFrom(data))
```

## Mechanistic Analysis and Scope Limits

1. **Why 416 B vs. 155 B:** FlatBuffers writes a 16-bit vtable per table (`Document`, `DocumentMeta`, eight `DocumentItem` tables), 4-byte offsets for every string/vector/subtable reference, and full-width aligned `Int32`/`Int64` fields (Kotlin emits 416 B rather than Swift's 440 B because Kotlin sets `Document` directly as buffer root without a `FixtureRoot` wrapper). Protocol Buffers writes 1-byte field tags and compact varints ([4.1 Protobuf wire format](../../theory/401/protobuf-wire-format.md)).
2. **Why larger wire size can still decode faster:** Reading a FlatBuffers field performs one 16-bit vtable lookup and a direct little-endian load with no varint loop and no intermediate generated object graph. `protobuf-java` executes nested varint tag loops inside `parseFrom`, allocates immutable generated objects, and then copies them into suite data classes via `fromProto`.
3. **Eager vs. partial-access trade-off:** This runner times full materialization of `Document` on both sides so FlatBuffers is not artificially favored by skipping copies. In read-mostly workloads projecting only a subset of fields, FlatBuffers can read directly from the buffer without allocating a domain graph; in bandwidth- or log-size-constrained workloads, Protocol Buffers' 155-byte density dominates. Compare with [Swift: `FlatBuffers` vs. `SwiftProtobuf`](swift-flatbuffers-vs-protobuf.md).
