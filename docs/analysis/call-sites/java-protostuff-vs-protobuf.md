# Java: `Protostuff` vs. `protobuf-java`

This note inspects the Java `protostuff` and `protobuf` (`protobuf-java`) adapters on the `document` ($n = 1$, `bytes` mode) payload. Both adapters time the same end-to-end suite boundary (`Document` POJO → bytes → `Document` POJO) and emit identical **155-byte** wire payloads, isolating the allocation and conversion cost of generated immutable Protocol Buffers messages.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=java&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protostuff&ser=protostuff&ser=protobuf#compare) · [Java overview](../../java/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `protostuff` | `protobuf` (`protobuf-java`) |
|---|---|---|
| Standard | `custom` (Protostuff runtime grouping) | `protobuf` (official `.proto` wire format) |
| Encoded size (`document`, $n = 1$) | **155 B** | **155 B** (identical) |
| Timed encode path | Domain POJO → `RuntimeSchema` → `byte[]` | Domain POJO → `toProto()` generated message → `toByteArray()` |
| Timed decode path | `byte[]` → `mergeFrom` into `new Document()` | `byte[]` → `parseFrom` immutable message → `fromProto()` POJO |
| Schema contract | Java field declaration order (JVM-centric) | Explicit `.proto` field numbers and cross-language evolution |

## Timed Call Sites

**`protostuff`** (`java/src/main/java/benchmark/serializers/ProtostuffSer.java`) caches `RuntimeSchema` and a reusable `LinkedBuffer` in `prepare`, then serializes and merges domain POJOs directly:

```java
public byte[] serializeBytes(Fixture fx) {
    buffer.clear();
    return ProtostuffIOUtil.toByteArray(fx.value, schema, buffer);
}
public Object deserializeBytes(byte[] data) {
    Object msg = schema.newMessage();
    ProtostuffIOUtil.mergeFrom(data, msg, schema);
    return msg;
}
```

**`protobuf-java`** (`java/src/main/java/benchmark/serializers/ProtobufSer.java`) binds `parser` in `prepare` and times the symmetric suite-boundary conversion alongside `toByteArray()` and `parseFrom()`:

```java
public byte[] serializeBytes(Fixture fx) {
    return toProto(fx).toByteArray();
}
public Object deserializeBytes(byte[] data) {
    return fromProto(typeId, batch, parser.parseFrom(data));
}
```

## Mechanistic Analysis and Scope Limits

1. **Identical 155-byte payload:** `benchmark_v2.proto` assigns `id = 1`, `status = 2`, `meta = 3`, `items = 4`, matching `Document`'s Java field declaration order. Although `ProtostuffIOUtil` delimits nested messages with start/end group bytes rather than length prefixes, for short nested payloads both encodings consume one extra byte per nested record, producing the same 155-byte total.
2. **Double object-graph tax on `protobuf-java`:** Because both adapters share the suite POJO boundary, `protobuf-java` allocates and populates a generated immutable message graph (builders, UTF-8 validation, presence bitfields, unknown-field storage) before copying back via `fromProto`. `protostuff` writes and fills the target `Document` POJO directly without an intermediate graph.
3. **Contract trade-off:** `RuntimeSchema` depends on Java declaration order and is suitable only within a controlled JVM estate; services exchanging bytes across languages or evolving schemas independently require `.proto`-driven `protobuf-java`. See also the Kotlin counterpart in [Kotlin: `Protostuff` vs. `protobuf`](kotlin-protostuff-vs-protobuf.md).
