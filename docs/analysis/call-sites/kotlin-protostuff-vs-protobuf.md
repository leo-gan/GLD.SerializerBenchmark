# Kotlin: `Protostuff` vs. `protobuf`

This note inspects `protostuff`, `protobuf` (`protobuf-java`), and `protobuf-kotlin` in the Kotlin runner on the `document` ($n = 1$, `bytes` mode) payload. All three adapters share the identical suite `Document` boundary and produce **155-byte** wire payloads, isolating intermediate generated-message construction and Kotlin DSL builder overhead.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=kotlin&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protostuff&ser=protostuff&ser=protobuf&ser=protobuf-kotlin#compare) · [Kotlin overview](../../kotlin/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `protostuff` | `protobuf` (`protobuf-java`) | `protobuf-kotlin` |
|---|---|---|---|
| Standard | `custom` | `protobuf` | `protobuf` |
| Encoded size (`document`, $n = 1$) | **155 B** | **155 B** | **155 B** |
| Timed encode path | Data class (`@JvmField`) → `RuntimeSchema` → `ByteArray` | Data class → Java `newBuilder()` → `toByteArray()` | Data class → Kotlin `document { }` DSL → `toByteArray()` |
| Timed decode path | `ByteArray` → `mergeFrom` into `Document` | `parseFrom` → `fromProto()` data class | `parseFrom` → `fromProto()` data class |

## Timed Call Sites

**`protostuff`** (`kotlin/src/main/kotlin/benchmark/serializers/ProtostuffSer.kt`) caches `RuntimeSchema` and reuses `LinkedBuffer`:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray {
    buffer.clear()
    return ProtostuffIOUtil.toByteArray(fx.value, schema, buffer)
}
override fun deserializeBytes(data: ByteArray): Any {
    val msg = schema.newMessage()
    ProtostuffIOUtil.mergeFrom(data, msg, schema)
    return msg
}
```

**`protobuf`** (`ProtobufSer.kt`) calls Java builders (`toProto(fx).toByteArray()`), while **`protobuf-kotlin`** (`ProtobufKotlinSer.kt`) constructs the identical Java protobuf message through the official Kotlin DSL wrapper before calling the same wire serializer:

```kotlin
private fun toDocument(d: Document) =
    document {
        id = d.id
        status = d.status
        meta = documentMeta { region = d.meta.region; version = d.meta.version }
        d.items.forEach { it ->
            items += documentItem { sku = it.sku; qty = it.qty; priceMinor = it.priceMinor }
        }
    }
```

## Mechanistic Analysis and Scope Limits

1. **Same 155-byte output, different object lifecycles:** As in [Java: `Protostuff` vs. `protobuf-java`](java-protostuff-vs-protobuf.md), `RuntimeSchema` walks `@JvmField` properties in declaration order matching `benchmark_v2.proto` field numbers `1..4`, avoiding the intermediate immutable message graph that both official Protobuf rows construct on encode and decode.
2. **Why `protobuf-kotlin` tracks `protobuf-java`:** `protobuf-kotlin` wraps the same `protobuf-java` `Builder`, `toByteArray()`, and `parseFrom()` runtime with inline Kotlin DSL builders; any minor encode delta reflects DSL helper overhead rather than a distinct wire engine.
3. **Contract trade-off:** `protostuff` couples wire compatibility to Kotlin declaration order, whereas `protobuf` and `protobuf-kotlin` enforce explicit `.proto` field numbers and cross-language evolution.
