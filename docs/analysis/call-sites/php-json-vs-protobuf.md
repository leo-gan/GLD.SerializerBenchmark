# PHP: `json` vs. `google/protobuf`

This note inspects PHP's built-in `ext-json` (`json`) and official `google/protobuf` (`protobuf`) adapters on the `document` ($n = 1$, `bytes` mode) payload. Both adapters time the symmetric suite-array boundary (`array` → bytes → `array`); the comparison illustrates how a compiled C engine inside Zend outruns a pure-PHP userland binary runtime even though JSON is nearly $3\times$ larger (**454 B** vs. **160 B**).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=php&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=json&ser=json&ser=protobuf#compare) · [PHP overview](../../php/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `json` (`ext-json`) | `protobuf` (`google/protobuf+php`) |
|---|---|---|
| Standard | `json` | `protobuf` |
| Encoded size (`document`, $n = 1$) | **454 B** | **160 B** |
| Execution tier | Bundled C extension inside Zend (`json_encode` / `json_decode`) | Userland PHP runtime on static CLI host (reports `+ext` if C extension loaded) |
| Timed boundary | PHP associative array ↔ UTF-8 JSON string | PHP array → `ProtoBridge::toProto()` generated objects → wire bytes → `fromProto()` |

## Timed Call Sites

**`json`** (`php/src/Serializers/JsonSer.php`) calls Zend's bundled C functions directly:

```php
public function serializeBytes(mixed $value): string
{
    return json_encode($value, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
}
public function deserializeBytes(string $data): mixed
{
    return json_decode($data, true, 512, JSON_THROW_ON_ERROR);
}
```

**`protobuf`** (`php/src/Serializers/ProtobufSer.php`) maps suite arrays into generated `benchmark_v2.proto` classes (`ProtoBridge.php`), encodes via `serializeToString()`, and reverses via `mergeFromString()` + `fromProto()`:

```php
public function serializeBytes(mixed $value): string
{
    return ProtoBridge::toProto($value)->serializeToString();
}
public function deserializeBytes(string $data): mixed
{
    $msg = ProtoBridge::emptyMessage($this->sample);
    $msg->mergeFromString($data);
    return ProtoBridge::fromProto($msg);
}
```

## Mechanistic Analysis and Scope Limits

1. **C engine vs. Zend bytecode + object graph:** `json_encode` and `json_decode` operate directly on PHP HashTables in C without instantiating PHP classes. Under the default static PHP CLI (no `ext-protobuf`), `google/protobuf` executes varint encoding/decoding in Zend bytecode while constructing and copying ten generated PHP objects (`Document`, `DocumentMeta`, eight `DocumentItem`s) inside the timer.
2. **Effect of `ext-protobuf`:** Loading the optional C `ext-protobuf` extension (reflected by `+ext` in `SerializerVersion`) replaces the userland wire loop with C while keeping the generated class API unchanged; the `toProto`/`fromProto` PHP object-mapping cost remains when converting from plain arrays.
3. **Contract trade-off:** `json` is ideal for public text APIs, whereas `protobuf` provides the compact 160-byte cross-language schema contract ([4.1 Protobuf wire format](../../theory/401/protobuf-wire-format.md)). PHP's built-in `serialize` emits 738 B and is non-portable and unsafe on untrusted input.
