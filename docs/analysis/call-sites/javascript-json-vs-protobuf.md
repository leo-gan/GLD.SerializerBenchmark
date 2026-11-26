# JavaScript: `JSON.stringify` vs. `google-protobuf`

This note inspects the Node.js `JSON.stringify` and `google-protobuf` adapters on the `document` ($n = 1$, `bytes` mode) payload. Despite Protocol Buffers producing a nearly $3\times$ smaller wire payload (**155 B** vs. **448 B**), V8's built-in C++ JSON engine outruns userland JavaScript Protocol Buffers reader/writer loops on small documents.

[Dashboard comparison (L1)](../../dashboard/index.html?lang=javascript&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=JSON.stringify&ser=JSON.stringify&ser=google-protobuf#compare) · [JavaScript overview](../../javascript/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `JSON.stringify` | `google-protobuf` |
|---|---|---|
| Standard | `json` | `protobuf` |
| Encoded size (`document`, $n = 1$) | **448 B** | **155 B** |
| Execution tier | Native C++ inside V8 (`JSON.stringify` / `JSON.parse`) + UTF-8 `Buffer` | Userland JavaScript (`BinaryWriter` / `BinaryReader`) |
| Decode allocations | Single C++ parse pass into V8 hidden-class objects | Per-nested-message `new BinaryReader(r.readBytes())` (10 readers for `document`) |

## Timed Call Sites

**`JSON.stringify`** (`javascript/src/serializers/json.js`) invokes V8's native C++ serializer and parser with a UTF-8 `Buffer` conversion:

```javascript
serialize(value) {
  return Buffer.from(JSON.stringify(value), 'utf8');
},
deserialize(buf) {
  return JSON.parse(bufToUtf8(buf));
},
```

**`google-protobuf`** (`javascript/src/serializers/modern.js`) records type metadata in untimed `prepare` and executes `jspbEncode` / `jspbDecode` (using `google-protobuf`'s `BinaryWriter` and `BinaryReader` primitives) inside the timed methods:

```javascript
serialize(value) {
  const u8 = jspbEncode(jspbDataName, value);
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  return jspbDecode(jspbDataName, u8, jspbIsBatch);
},
```

On decode, every nested record (`meta` plus eight `items`) allocates a fresh `BinaryReader` over a copied byte slice and runs a JavaScript varint tag loop (`while (r.nextField())`).

## Mechanistic Analysis and Scope Limits

1. **Native C++ engine vs. userland JS loops:** V8's C++ `JSON.stringify` and `JSON.parse` have undergone over a decade of engine-level optimization (fast property tables, inline UTF-8 scanning). By contrast, `google-protobuf` parses base-128 varints and allocates ten `BinaryReader` instances in userland JavaScript, so reading 155 compact binary bytes costs more CPU time than scanning 448 text bytes in C++ ([2.3 Encode and decode cost](../../theory/201/encode-decode-cost.md)).
2. **Why `fast-json-stringify` also trails on small records:** `fast-json-stringify` compiles JS string concatenation for encode (falling back to `JSON.stringify` for escaping) while sharing `JSON.parse` for decode, pitting userland JS string building against V8's C++ path.
3. **Timing honesty history and scope:** An early adapter erroneously encoded inside `prepare` and timed a `Buffer` copy; the current adapter performs full encode and decode on the clock. Larger numeric payloads or a native C++ addon decoder alter the CPU/bandwidth trade-off. For a controlled comparison of three JS Protocol Buffers libraries (`google-protobuf`, `protobufjs`, `protobuf-es`) on the same 155-byte output, see [4.11 JavaScript: three Protobufs](../../theory/401/javascript-three-protobufs.md).
