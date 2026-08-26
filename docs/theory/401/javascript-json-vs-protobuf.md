# JavaScript: why `JSON.stringify` is faster than google-protobuf on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **`JSON.stringify`** finishes more encode-and-decode cycles per second than **google-protobuf**, even though JSON is 448 bytes and Protocol Buffers is 155. That result surprises people who have just read that binary encodings are smaller and therefore faster.

This page looks at the actual timed functions. After reading it you should be able to say why `JSON.stringify` is faster than a real google-protobuf encode, why `JSON.parse` is faster than the JavaScript decoder, and why the smaller 155-byte message does not win on this document.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data, after google-protobuf encode was
moved into timed `serialize`. They illustrate the gap; they are not a
universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=javascript&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=JSON.stringify&ser=JSON.stringify&ser=google-protobuf#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [JavaScript overview](../../javascript/)

## Short answer

Two facts explain the table.

1. **Timed protobuf encode is a real encode.** `serialize` calls `jspbEncode`, which writes the document with `BinaryWriter`. That takes 8.4 µs. `JSON.stringify` is native C++ inside V8. It takes 2.9 µs.
2. **Timed protobuf decode is a JavaScript field loop.** It allocates a reader per nested message, reads each field number, and builds plain objects. `JSON.parse` is also native C++ inside V8. 3.6 µs of native parse is faster than 6.0 µs of JavaScript decode.

JSON still writes every field name. That costs size (448 B versus 155 B). It does not cost enough *time*, on this small document, to lose to a JavaScript Protocol Buffers library.

An earlier adapter encoded in `prepare` and timed only a `Buffer` copy (431 ns). That made google-protobuf look almost as fast as `JSON.stringify`. The table below is the fair comparison.

| | `JSON.stringify` | google-protobuf | fast-json-stringify |
|--|------------------|-----------------|---------------------|
| Mean encode + decode, document, *n* = 1 | **154 thousand / s** | 70 thousand / s | 100 thousand / s |
| Encode | **2.9 µs** | 8.4 µs | 6.2 µs |
| Decode | **3.6 µs** (`JSON.parse`) | 6.0 µs (JS `BinaryReader`) | `JSON.parse` (same) |
| Encoded size | 448 B | **155 B** | 448 B |

## The two timed call sites

**JSON** (`javascript/src/serializers/json.js`) is one native call each way, plus a UTF-8 `Buffer`:

```javascript
serialize(value) {
  return Buffer.from(JSON.stringify(value), 'utf8');
},
deserialize(buf) {
  return JSON.parse(bufToUtf8(buf));
},
```

**google-protobuf** (`javascript/src/serializers/modern.js`) stores the data type in `prepare` and encodes in `serialize`:

```javascript
prepare(dataName, value) {
  jspbDataName = dataName;
  jspbIsBatch = Array.isArray(value);
},
serialize(value) {
  const u8 = jspbEncode(jspbDataName, value);   // timed
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  return jspbDecode(jspbDataName, u8, jspbIsBatch);
},
```

The runner times `serialize` / `deserialize` after `prepare` (`javascript/src/runner_v2.js`). Generated `Document.serializeBinary` exists in `javascript/src/generated/google/js_fixtures_pb.cjs`. This wrapper uses the same `BinaryWriter` primitives as those generated stubs.

## What decode actually does

`jspbReadDocument` builds a literal, then for every field calls `nextField()` and a typed read. Nested `meta` and each of the **eight** items allocate another `BinaryReader` over a copied slice:

```javascript
// javascript/src/serializers/modern.js — document decode (abbreviated)
function jspbReadDocument(r) {
  const o = { id: '', status: 0, meta: { region: '', version: 0 }, items: [] };
  while (r.nextField()) {
    switch (r.getFieldNumber()) {
      case 1: o.id = r.readString(); break;
      case 2: o.status = r.readInt32(); break;
      case 3: {
        const ir = new BinaryReader(r.readBytes());
        while (ir.nextField()) { /* region, version */ }
        break;
      }
      case 4: {
        const ir = new BinaryReader(r.readBytes());
        const it = { sku: '', qty: 0, price_minor: 0 };
        while (ir.nextField()) { /* sku, qty, price_minor */ }
        o.items.push(it);
        break;
      }
    }
  }
  return o;
}
```

`nextField` in `google-protobuf` is a JavaScript variable-length integer parse of `(field << 3) | wireType`. Ten reader loops and ten object allocations later, you have the same logical document that `JSON.parse` produced in C++.

The official generated decoder is the same algorithm with setters (`deserializeBinaryFromReader`). Switching to it would not make decode native.

## Why `JSON.stringify` is faster than `fast-json-stringify`

`fast-json-stringify` compiles a JavaScript function in `prepare`, then concatenates strings in user land. Short strings even fall back to `JSON.stringify` for escaping. Decode is still `JSON.parse`. So this row measures **generated JavaScript encode versus V8’s C++ encode**, with the same parse. V8 is faster. That is implementation quality inside one encoding, the third idea on the [Rust comparison](rust-speedy-vs-bincode.md) (specialize the path — here the specialized path is already inside V8).

## History

JSON is the web default because browsers already used it ([Douglas Crockford](https://en.wikipedia.org/wiki/Douglas_Crockford), early 2000s). V8’s `JSON.parse` / `JSON.stringify` have been tuned for more than a decade. Protocol Buffers in JavaScript walks field numbers and payloads in ordinary JavaScript, in the same language that hosts that tuned parser. On a 448-byte document, the native parser is faster, even though it reads more bytes.

[Serialization 201](../201/encode-decode-cost.md) warned that “binary versus text” is not one cost. This page is that warning in one language’s source.

The same 155-byte encoding in **protobufjs** and **protobuf-es** is [three Protocol Buffers libraries](javascript-three-protobufs.md).

## Honesty

1. Both columns are now real encode and real decode. JSON is still faster on this document because V8’s JSON functions are native C++ and the Protocol Buffers path is JavaScript.
2. The 155-byte size is real. Field numbers and variable-length integers omit names.
3. A larger document, or a native addon decoder, would change the rank. This page explains *this* runner.

## Self-check

1. Add the two protobuf times: 8.4 µs + 6.0 µs. Add the two JSON times: 2.9 µs + 3.6 µs. Which half of the protobuf total is now the larger cost?
2. Why does `fast-json-stringify` sharing `JSON.parse` with `JSON.stringify` predict that it cannot win on decode?
3. Why can JSON be both larger (448 B) and faster than Protocol Buffers (155 B) on this document?
