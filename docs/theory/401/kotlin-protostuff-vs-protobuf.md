# Kotlin: why Protostuff outruns protobuf-java on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **Protostuff**, **protobuf-java**, and **protobuf-kotlin** write the **same number of bytes** (155). Protostuff still finishes more encode-and-decode cycles per second. When three libraries emit the same size, the gap cannot be “a more compact encoding.” It has to be the object they build and the path they take to build it.

This page compares the timed wrappers on the Kotlin harness. The Java pair of the same two libraries is [Java: Protostuff vs protobuf-java](java-protostuff-vs-protobuf.md).

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=kotlin&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=protostuff&ser=protostuff&ser=protobuf&ser=protobuf-kotlin#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Kotlin overview](../../kotlin/)

## Short answer

Protostuff completes more encode-and-decode cycles per second than protobuf-java on this Kotlin slice (about 17 thousand versus 13 thousand). protobuf-kotlin sits with protobuf-java. Both official rows write 155 bytes, so size cannot explain the difference.

All three adapters time the same work: suite `Document` in, bytes, suite `Document` out.

**Encode:** Protostuff walks public `@JvmField` properties of the live data class through a cached `RuntimeSchema`. protobuf-java and protobuf-kotlin first copy that object into a generated message (`toProto` / Kotlin `document { }`), then call `toByteArray()`.

**Decode:** Protostuff allocates a plain `Document` and fills its fields. The official rows call `parseFrom`, which builds an immutable generated graph, then copy that graph into a suite `Document`. Both copies are timed.

Protostuff has the higher total cycle rate because it never builds the generated graph.

| | Protostuff | protobuf-java | protobuf-kotlin | moshi-codegen |
|--|------------|---------------|-----------------|---------------|
| Mean encode + decode, document, *n* = 1 | **17 thousand / s** | 13 thousand / s | 13 thousand / s | 21 thousand / s |
| Encoded size | **155 B** | **155 B** | **155 B** | 440 B |
| Timed encode input | Domain data class | Domain → generated message | Domain → Kotlin DSL builder | Domain data class |
| Timed decode output | Domain data class | Generated message → domain | Generated message → domain | Domain data class |

moshi-codegen is first on this one-instance document because a generated JSON adapter is fast — and then it writes 440 bytes of names. It falls behind as the payload grows.

## The timed call sites

**Protostuff** (`kotlin/src/main/kotlin/benchmark/serializers/ProtostuffSer.kt`) caches a `RuntimeSchema` and a `LinkedBuffer`:

```kotlin
override fun prepare(fx: Fixture) {
    schema = RuntimeSchema.getSchema(TypeUtil.elementClass(fx.value)) as Schema<Any>
    buffer.clear()
}
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

**protobuf-java** (`kotlin/src/main/kotlin/benchmark/serializers/ProtobufSer.kt`) uses the Java builder API:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray = toProto(fx).toByteArray()
override fun deserializeBytes(data: ByteArray): Any =
    fromProto(typeId, batch, parser.parseFrom(data))
```

**protobuf-kotlin** (`kotlin/src/main/kotlin/benchmark/serializers/ProtobufKotlinSer.kt`) uses the generated Kotlin DSL, then the same wire methods:

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

The Kotlin DSL is a different way to *build* the generated message. `toByteArray()` and `parseFrom` are still the official Java runtime. That is why protobuf-kotlin and protobuf-java sit together on this fixture.

## Why the sizes match

The suite `.proto` numbers document fields `id = 1`, `status = 2`, `meta = 3`, `items = 4`. Protostuff’s `RuntimeSchema` assigns field numbers in declaration order on `benchmark.model.v2.Document`, which is the same order. All three write Protocol Buffers field numbers and variable-length integers.

## What you give up

Protostuff’s runtime schema follows declaration order. A `.proto` that numbers fields differently will not interoperate. The official Java/Kotlin runtime follows the `.proto` file and the published evolution rules. If the bytes leave this process, protobuf-java or protobuf-kotlin is the contract. If the bytes stay inside a JVM cache, Protostuff’s data-class path is why it is faster on this fixture.

## Self-check

1. Why is equal size evidence that the encoding is not the speed story?
2. What extra objects do the official protobuf rows still build that Protostuff does not?
3. Why do protobuf-java and protobuf-kotlin land so close to each other on this fixture?
