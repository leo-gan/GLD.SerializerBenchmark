# JavaScript: why `JSON.stringify` beats google-protobuf on Document

## Why this article exists

On this suite’s **document** fixture, one instance, in-memory buffer mode, **`JSON.stringify`** finishes more encode-and-decode cycles per second than **google-protobuf**, even though JSON is 448 bytes and Protocol Buffers is 155. That result surprises people who have just read that binary encodings are smaller and therefore faster.

This page looks at the actual timed functions. After reading it you should be able to say why the protobuf *encode* number is 431 nanoseconds, why decode is 5648, and why V8’s JSON path still wins the total.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data. They illustrate the gap; they are
not a universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=javascript&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=JSON.stringify&ser=JSON.stringify&ser=google-protobuf#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [JavaScript overview](../../javascript/)

## Short answer

Two facts, both in the wrapper, explain the table.

1. **Timed protobuf encode is not an encode.** `prepare` (untimed) writes the Protocol Buffers bytes once. The timed `serialize` only wraps those bytes in a Node `Buffer`. 431 ns is a buffer view, not `serializeBinary`.
2. **Timed protobuf decode is a JavaScript field loop.** It allocates a reader per nested message, walks tags, and builds plain objects. `JSON.parse` is native C++ inside V8. 3196 ns of native parse beats 5648 ns of user-land tag walking.

JSON still writes every field name. That costs size. It does not cost enough *time*, on this small document, to lose to a JavaScript protobuf decoder.

| | `JSON.stringify` | google-protobuf (as timed) | fast-json-stringify |
|--|------------------|----------------------------|---------------------|
| Mean encode + decode, document, *n* = 1 | **174 thousand / s** | 164 thousand / s | 107 thousand / s |
| Encode | 2538 ns | **431 ns** (cached bytes → `Buffer`) | slower JS stringify |
| Decode | **3196 ns** (`JSON.parse`) | 5648 ns (JS `BinaryReader`) | `JSON.parse` (same) |
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

**google-protobuf** (`javascript/src/serializers/modern.js`) encodes in `prepare`:

```javascript
prepare(dataName, value) {
  jspbDataName = dataName;
  jspbIsBatch = Array.isArray(value);
  jspbBytes = jspbEncode(dataName, value);   // untimed
},
serialize(_value) {
  const u8 = jspbBytes;
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  return jspbDecode(jspbDataName, u8, jspbIsBatch);
},
```

The runner times `serialize` / `deserialize` after `prepare` (`javascript/src/runner_v2.js`). Generated `Document.serializeBinary` exists in `javascript/src/generated/google/js_fixtures_pb.cjs`. This wrapper does not call it on the clock.

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

## Why `fast-json-stringify` loses to `JSON.stringify`

`fast-json-stringify` compiles a JavaScript function in `prepare`, then concatenates strings in user land. Short strings even fall back to `JSON.stringify` for escaping. Decode is still `JSON.parse`. So this row measures **generated JavaScript encode versus V8’s C++ encode**, with the same parse. V8 wins. That is implementation quality inside one format, the third idea on the [Rust comparison](rust-speedy-vs-bincode.md) (specialize the path — here the specialized path is already inside the engine).

## History

JSON is the web default because browsers already spoke it ([Douglas Crockford](https://en.wikipedia.org/wiki/Douglas_Crockford), early 2000s). V8’s `JSON.parse` / `JSON.stringify` have been tuned for more than a decade. Protocol Buffers in JavaScript is a port of a binary tag machine into the language that also hosts that tuned parser. On a 448-byte document, the native parser is the faster machine, even though it reads more bytes.

[Serialization 201](../201/encode-decode-cost.md) warned that “binary versus text” is not one cost. This page is that warning in one language’s source.

The same 155-byte encoding in **protobufjs** and **protobuf-es**, with encode actually on the clock, is [three Protocol Buffers engines](javascript-three-protobufs.md).

## Honesty

1. **Do not quote 431 ns as protobuf encode speed.** A fair encode would call `jspbEncode` or `serializeBinary` inside the timer. The `protobuf-es` row on the same Dashboard slice does time `toBinary` and is much slower.
2. The 155-byte size is real. Tags and variable-length integers do omit names.
3. A larger document, or a native addon decoder, would change the rank. This page explains *this* runner.

## Self-check

1. Add the two protobuf times: 431 + 5648. Add the two JSON times: 2538 + 3196. Which half of the protobuf total is “not really encode”?
2. Why does `fast-json-stringify` sharing `JSON.parse` with `JSON.stringify` predict that it cannot win on decode?
3. What would you change in `googleProtobufSer.serialize` to make the encode column honest, and what would you expect to happen to ops/s?
