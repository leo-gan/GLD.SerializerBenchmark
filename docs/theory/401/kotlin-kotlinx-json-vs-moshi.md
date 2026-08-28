# Kotlin: why Moshi outruns kotlinx-json on the same JSON

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **moshi-codegen** and **kotlinx-json** emit the **same 440 bytes** of named JSON. Moshi still finishes more encode-and-decode cycles per second. When two libraries write the same text, the gap cannot be “a denser encoding.” It has to be how each library walks the data class and how it hands bytes back to the caller.

This page holds the format still (JSON with field names) and changes only the library. The Python pair of that question is [orjson vs json](python-orjson-vs-json.md).

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=kotlin&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=moshi-codegen&ser=moshi-codegen&ser=kotlinx-json&ser=moshi-reflect#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Kotlin overview](../../kotlin/)

## Short answer

Moshi’s generated adapter completes more encode-and-decode cycles per second than kotlinx.serialization JSON on this slice (about 21 thousand versus 12 thousand). Both write 440 bytes, so size cannot explain the difference.

Both adapters time the same work: suite `Document` in, UTF-8 JSON out, suite `Document` back.

**Encode:** kotlinx-json calls `Json.encodeToStream` on a reused `ByteArrayOutputStream`. Moshi calls a KSP-generated `JsonAdapter.toJson` into an Okio `Buffer`.

**Decode:** kotlinx-json calls `Json.decodeFromStream` on a `ByteArrayInputStream`. That path walks JSON tokens through the kotlinx decoder and builds the data class. Moshi’s generated adapter reads tokens and assigns fields. Decode is where most of the gap sits (about 52 µs versus 24 µs).

moshi-reflect sits with moshi-codegen on this one-instance document. Reflection is not the story here. The story is Moshi’s adapter versus kotlinx’s format decoder.

| | moshi-codegen | kotlinx-json | moshi-reflect |
|--|---------------|--------------|---------------|
| Mean encode + decode, document, *n* = 1 | **21 thousand / s** | 12 thousand / s | 23 thousand / s |
| Encode | **24 µs** | 29 µs | 20 µs |
| Decode | **24 µs** | 52 µs | 22 µs |
| Encoded size | **440 B** | **440 B** | **440 B** |

Equal size is the teaching fact. The speed difference is implementation, not a different encoding.

## The two timed call sites

**kotlinx-json** (`kotlin/src/main/kotlin/benchmark/serializers/KotlinxJsonSer.kt`) reuses a `Json` instance and a `ByteArrayOutputStream`:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray {
    baos.reset()
    json.encodeToStream(serializer, fx.value, baos)
    return baos.toByteArray()
}
override fun deserializeBytes(data: ByteArray): Any =
    json.decodeFromStream(serializer, ByteArrayInputStream(data))
```

`encodeToStream` / `decodeFromStream` are the official kotlinx.serialization JSON APIs. The compiler generated a `KSerializer` for `Document`. The timed path still walks that serializer: each property is a format-level encode or decode, then a stream write or read.

**moshi-codegen** (`kotlin/src/main/kotlin/benchmark/serializers/MoshiCodegenSer.kt`) caches the generated adapter in `prepare` and times only `toJson` / `fromJson`:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray {
    val buf = Buffer()
    adapter.toJson(buf, fx.value)
    return buf.readByteArray()
}
override fun deserializeBytes(data: ByteArray): Any =
    adapter.fromJson(Buffer().write(data)) ?: throw IllegalStateException("moshi-codegen null")
```

The adapter comes from `@JsonClass(generateAdapter = true)` on the suite data classes. KSP writes a `DocumentJsonAdapter` that knows the property names and types. There is no format-level serializer graph on the timed path.

## Why decode favours Moshi

kotlinx-json decode is a **format decoder plus a serializer**. `decodeFromStream` reads tokens, then the generated `KSerializer` maps those tokens onto `Document`. That extra hop is real work on every field, including the eight line items.

Moshi decode is **one generated adapter**. The adapter reads `"id"`, `"status"`, `"meta"`, `"items"` and assigns them. Nested `DocumentMeta` and `DocumentItem` have their own generated adapters. There is no second framework between the token and the field.

Encode is closer (29 µs versus 24 µs) because both paths already know the field list. Decode is where the kotlinx format layer shows up.

## What you give up

kotlinx.serialization is the Kotlin multiplatform format family. The same `@Serializable` types can write JSON, CBOR, ProtoBuf, Properties, and HOCON. Moshi is JVM JSON. If the product must share one type definition across formats, kotlinx-json is the reason that family exists. If the product is a JVM service that only speaks JSON, Moshi’s generated adapter is why it is faster on this fixture.

moshi-reflect is slightly faster than moshi-codegen on this one-instance document. Do not read that as “never generate adapters.” The reflection factory is still Moshi. The pair on this page is kotlinx versus Moshi, not codegen versus reflection.

## Self-check

1. Why is equal size evidence that the encoding is not the speed story?
2. Which timed call still walks a format-level `KSerializer`, and which one calls a generated `JsonAdapter`?
3. Why is the decode gap larger than the encode gap on this fixture?
