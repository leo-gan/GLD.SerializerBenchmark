# Kotlin: `kotlinx-json` vs. `Moshi`

This note compares `kotlinx-json`, `moshi-codegen`, and `moshi-reflect` on the `document` ($n = 1$, `bytes` mode) payload. All three serialize the same Kotlin `Document` data class into an identical **440-byte** compact UTF-8 JSON document, isolating pure implementation cost between a multi-format plugin architecture and a JSON-dedicated adapter.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=kotlin&standard=json&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=moshi-codegen&ser=moshi-codegen&ser=kotlinx-json&ser=moshi-reflect#compare) · [Kotlin overview](../../kotlin/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `kotlinx-json` | `moshi-codegen` | `moshi-reflect` |
|---|---|---|---|
| Standard | `json` | `json` | `json` |
| Encoded size (`document`, $n = 1$) | **440 B** | **440 B** | **440 B** |
| Timed boundary | `Document` ↔ UTF-8 `ByteArray` | `Document` ↔ UTF-8 `ByteArray` | `Document` ↔ UTF-8 `ByteArray` |
| Binding mechanism | Compiler-generated `KSerializer` + format encoder/decoder | KSP-generated `DocumentJsonAdapter` over Okio `Buffer` | `KotlinJsonAdapterFactory` reflection over Okio `Buffer` |
| Multi-format support | Yes (JSON, CBOR, ProtoBuf, HOCON, Properties) | JSON only | JSON only |

## Timed Call Sites

**`kotlinx-json`** (`kotlin/src/main/kotlin/benchmark/serializers/KotlinxJsonSer.kt`) reuses a `Json` instance and `ByteArrayOutputStream`, encoding and decoding through the compiler-generated `KSerializer`:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray {
    baos.reset()
    json.encodeToStream(serializer, fx.value, baos)
    return baos.toByteArray()
}
override fun deserializeBytes(data: ByteArray): Any =
    json.decodeFromStream(serializer, ByteArrayInputStream(data))
```

**`moshi-codegen`** (`kotlin/src/main/kotlin/benchmark/serializers/MoshiCodegenSer.kt`) caches the KSP-generated `JsonAdapter` in `prepare` and streams through an Okio `Buffer`:

```kotlin
override fun serializeBytes(fx: Fixture): ByteArray {
    val buf = Buffer()
    adapter.toJson(buf, fx.value)
    return buf.readByteArray()
}
override fun deserializeBytes(data: ByteArray): Any =
    adapter.fromJson(Buffer().write(data)) ?: throw IllegalStateException("moshi-codegen null")
```

## Mechanistic Analysis and Scope Limits

1. **Controlled equal-size comparison (440 B):** Because wire bytes are identical across all three rows, throughput differences arise strictly from parser/encoder dispatch and allocation rather than format density (the JVM parallel to [Python: `orjson` vs. stdlib `json`](python-orjson-vs-json.md)).
2. **Format-abstraction layer on decode:** `kotlinx.serialization` decouples data-class structure (`KSerializer`) from wire syntax (`CompositeDecoder` / `JsonDecoder`), adding an abstraction hop per field and nested list item during decode. Moshi's `JsonAdapter` couples Okio JSON token reading directly to property assignment with no intermediate format layer.
3. **Architecture trade-off:** `kotlinx.serialization` supports Kotlin Multiplatform and multiple wire formats from one `@Serializable` model; Moshi targets JVM/Android JSON exclusively. On this small single-instance document, `moshi-reflect` closely tracks `moshi-codegen` because both share Moshi's Okio token reader and JIT inlines the small class structure.
