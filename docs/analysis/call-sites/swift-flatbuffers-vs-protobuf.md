# Swift: `FlatBuffers` vs. `SwiftProtobuf`

This note inspects the Swift `FlatBuffers` and `SwiftProtobuf` adapters on the `document` ($n = 1$, `bytes` mode) payload. Both adapters time the symmetric end-to-end suite boundary (`Document` → `Data` → `Document`), contrasting FlatBuffers' vtable/offset buffer (**440 B**) against Protocol Buffers' compact tag-and-varint wire format (**155 B**).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=swift&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=FlatBuffers&ser=FlatBuffers&ser=SwiftProtobuf#compare) · [Swift overview](../../swift/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `FlatBuffers` | `SwiftProtobuf` |
|---|---|---|
| Standard | `flatbuffers` | `protobuf` |
| Encoded size (`document`, $n = 1$) | **440 B** | **155 B** |
| Buffer root framing | Wraps payload in 11-slot `FixtureRoot` table (+24 B vs. Kotlin's 416 B) | Root is `Document` directly |
| Timed encode path | Reused `FlatBufferBuilder` (`clear` → create strings/tables → `endTable`) | `toProtobuf` struct copy → two-pass `serializedData()` (size pass + write pass) |
| Timed decode path | Vtable 16-bit offset loads → materialize suite `Document` | Varint tag loop (`nextFieldNumber()`) → generated struct → `toDomain()` |

## Timed Call Sites

**`FlatBuffers`** (`swift/Sources/SerializerBenchmarkCore/Serializers/FlatBuffersSer.swift` + `FlatBuffersBridge.swift`) clears a reused `FlatBufferBuilder`, packs strings, nested tables, and `FixtureRoot`, and copies fields back into a suite `Document` on decode:

```swift
public func serializeBytes(_ fixture: Fixture) throws -> Data {
    guard let encodeFn else { throw BenchError.prepareRequired }
    builder.clear()
    return try encodeFn(&builder, fixture)
}
```

**`SwiftProtobuf`** (`Protobuf.swift`) converts between suite `Document` and generated SwiftProtobuf structs on the same clock:

```swift
public func serializeBytes(_ fixture: Fixture) throws -> Data {
    let msg = try ProtobufBridge.toProtobuf(fixture)
    return try msg.serializedData()
}
public func deserializeBytes(_ data: Data) throws -> Any {
    let msg = try decodeNative(data)
    return try ProtobufBridge.toDomain(msg, fixture: prepared)
}
```

## Mechanistic Analysis and Scope Limits

1. **Why 440 B vs. 155 B:** FlatBuffers stores a 16-bit vtable per table (`FixtureRoot`, `Document`, `DocumentMeta`, eight `DocumentItem`s), 4-byte relative offsets (including a 32-byte vector of item offsets), and aligned fixed-width `Int32`/`Int64` fields. Swift adds 24 bytes over [Kotlin's 416-byte FlatBuffers row](kotlin-flatbuffers-vs-protobuf.md) because Swift wraps every record in a `FixtureRoot` table. Protocol Buffers writes 1-byte tags and compact varints ([4.1 Protobuf wire format](../../theory/401/protobuf-wire-format.md)).
2. **Offset loads vs. two-pass encode & varint decode:** On encode, `SwiftProtobuf`'s `serializedData()` performs two traversals (size computation, then write) after `toProtobuf`. On decode, FlatBuffers resolves each scalar via a 16-bit vtable slot and direct little-endian load, avoiding `nextFieldNumber()` varint loops and switch dispatch.
3. **Eager materialization vs. zero-copy access:** Both timed decode paths copy into a suite `Document` so the comparison is unbiased at the suite boundary. In production workloads that inspect only a few fields of a large read-only payload, FlatBuffers' in-place access avoids copying altogether ([2.7 Zero-copy](../../theory/201/zero-copy.md)); for wire-bandwidth-sensitive logs or RPCs, Protocol Buffers' 155-byte encoding dominates.
