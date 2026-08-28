# PHP: why `json_encode` outruns protobuf on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **stdlib JSON** finishes more encode-and-decode cycles per second than official **google/protobuf**, even though JSON is 454 bytes and Protocol Buffers is 160. Smaller is not faster. The JSON path is a native C engine inside the interpreter. The Protocol Buffers path, on this machine, is the official **userland** PHP runtime walking generated message objects.

This page compares the two timed wrappers. After reading it you should be able to say why `json_encode` / `json_decode` beat a real protobuf encode and decode here, why the 160-byte message does not win on this document, and what would change if `ext-protobuf` were loaded.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from a local PHP `all-single` run. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=php&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=json&ser=json&ser=protobuf#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [PHP overview](../../php/)

## Short answer

Two facts explain the table.

1. **Timed JSON is C inside the engine.** `json_encode` / `json_decode` with `JSON_THROW_ON_ERROR` are native. Encode is about 1.9 µs; decode is about 4.3 µs.
2. **Timed protobuf is generated PHP plus `serializeToString` / `mergeFromString`.** Encode first copies the suite array into a generated `Document` (`toProto`), then writes tags. Decode parses into a generated graph, then copies back to a suite array (`fromProto`). Both copies are on the clock. That is about 124 µs encode and 68 µs decode on this userland runtime.

JSON still writes every field name (454 B versus 160 B). That costs size. It does not cost enough *time*, on this small document, to lose to userland Protocol Buffers.

The version string is `google/protobuf+php` when the C extension is absent, and `…+ext` when `ext-protobuf` is loaded. This slice is `+php`.

| | `json` | protobuf (userland) | serialize |
|--|--------|---------------------|-----------|
| Mean encode + decode, document, *n* = 1 | **162 thousand / s** | 5.2 thousand / s | 178 thousand / s |
| Encode | **1.9 µs** | 124 µs | 2.1 µs |
| Decode | **4.3 µs** | 68 µs | 3.5 µs |
| Encoded size | 454 B | **160 B** | 738 B |

`serialize` is slightly faster than JSON on this one-instance document and writes more bytes. It is PHP-only. The pair on this page is the portable formats.

## The two timed call sites

**JSON** (`php/src/Serializers/JsonSer.php`) is one native call each way:

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

**protobuf** (`php/src/Serializers/ProtobufSer.php`) uses official generated types from `schemas/v2/protobuf/benchmark_v2.proto`:

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

`toProto` / `fromProto` (`php/src/ProtoBridge.php`) copy every field, including the eight line items, on the timed path. That is the same contract as the Kotlin/Java official protobuf rows: suite `Document` in, bytes, suite `Document` out.

## Why 454 bytes versus 160

JSON writes field names as UTF-8 text. Protocol Buffers writes field numbers and variable-length integers. The information is the same shop order. The 160-byte image is the compact layout taught in the [Protocol Buffers wire format](protobuf-wire-format.md) article.

## What you give up

Userland `google/protobuf` is the official PHP API and the interop contract. It is not a C JSON engine. If the bytes leave this process, protobuf is the format other languages can share. If the job is a public JSON API, `json_encode` is why it is faster here.

Loading `ext-protobuf` keeps the same generated classes and the same `serializeToString` / `mergeFromString` calls. The C extension replaces the userland walk. This article’s numbers are the userland path.

## Self-check

1. Why can JSON be both larger and faster on this document?
2. Which extra objects does the protobuf row build that `json_decode` does not?
3. What would you expect to change in the protobuf rank if `ext-protobuf` were loaded and the copies stayed on the clock?
