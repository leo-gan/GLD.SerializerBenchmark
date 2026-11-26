# Mojo: `EmberJson` vs. `mojo-avro`

This note inspects Mojo's reflection JSON codec (`EmberJson`) and schema-ordered Avro binary codec (`mojo-avro`, `leo-gan/gld-avro`) on the `document` ($n = 1$, `bytes` mode) payload. Both serialize the same pure-Mojo `Document` struct with no streaming API (`bytes` only), contrasting self-describing UTF-8 JSON text (**448 B**) against schema-dependent binary Avro (**114 B**).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=mojo&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=EmberJson&ser=EmberJson&ser=mojo-avro#compare) · [Mojo overview](../../mojo/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `EmberJson` | `mojo-avro` (`gld-avro`) |
|---|---|---|
| Standard | `json` | `avro` |
| Encoded size (`document`, $n = 1$) | **448 B** | **114 B** ($3.9\times$ smaller) |
| Wire representation | Named UTF-8 JSON objects and decimal digits | Positional schema-ordered binary datum; zigzag varints; no keys |
| Timed boundary | `Document` ↔ JSON string (`serialize` / `deserialize`) | `Document` ↔ Avro byte buffer (`encode` / `decode` via `AvroDatum`) |
| Stream I/O | `bytes` only | `bytes` only |

## Timed Call Sites

**`EmberJson`** (`mojo/src/bench/emberjson_ser.mojo`) uses reflection-based serialization over the suite `Document` struct:

```mojo
var text = serialize(document)
var back = deserialize[Document](text)
```

**`mojo-avro`** (`mojo/src/bench/avro_ser.mojo`) invokes `AvroDatum` trait encoding and decoding on the same struct:

```mojo
var buf = encode(document)
var back = decode[Document](buf)
```

## Mechanistic Analysis and Scope Limits

1. **Nearly $4\times$ wire reduction (448 B → 114 B):** `EmberJson` repeats `"sku"`, `"qty"`, and `"price_minor"` eight times alongside punctuation and decimal ASCII numbers. `mojo-avro` omits all field names (relying on the out-of-band Avro schema) and packs small integers into 1–2 byte zigzag varints.
2. **Parse and formatting cost:** Avoiding UTF-8 token scanning, quote/escape handling, and decimal–binary conversion reduces both encode and decode work on `mojo-avro` relative to `EmberJson`.
3. **Scope limits:** Because these two libraries implement different standards (`json` vs. `avro`), treat live Dashboard differences as a **format trade-off** (human readability vs. compact schema-driven binary) rather than an implementation ranking; consult the live Dashboard CIs and Mojo 1.1 toolchain version before quoting L1 timings.
