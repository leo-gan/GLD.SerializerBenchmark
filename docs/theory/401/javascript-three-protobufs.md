# JavaScript: three engines, one Protocol Buffers document

## Why this article exists

The [JSON versus google-protobuf](javascript-json-vs-protobuf.md) page showed that this runner’s google-protobuf **encode** is a cached `Buffer`. A fair question follows: what happens when two other JavaScript libraries speak the **same 155-byte** encoding and actually run encode on the clock?

This page places **google-protobuf**, **protobufjs**, and **protobuf-es** side by side. After reading it you should be able to say which functions are timed, why the three totals differ by a factor of five, and how this extends [Same bytes, three runtimes](protobuf-cross-language-fidelity.md) without leaving JavaScript.

Numbers are from the committed JavaScript **Results** snapshot (document, one instance). See [JavaScript Results](../../javascript/results.md).

## Short answer

All three emit **155 bytes** of proto3 binary: field numbers 1–4, variable-length integers, no names. The stopwatch is not measuring the format. It is measuring three different machines that write and read those tags, and three different decisions about `prepare`.

| | google-protobuf (as timed) | protobufjs | protobuf-es |
|--|----------------------------|------------|-------------|
| Mean encode + decode | **164 thousand / s** | 41 thousand / s | 29 thousand / s |
| Encode | **431 ns** | 7.3 µs | 21 µs |
| Decode | **5648 ns** | 17 µs | 13 µs |
| Encoded size | **155 B** | **155 B** | **155 B** |

google-protobuf’s encode is **not** an encode. protobufjs times `Type.encode(...).finish()`. protobuf-es times `toBinary`. Decode is a JavaScript tag loop in every row. None of these is V8-native.

## The three timed call sites

**google-protobuf** (`javascript/src/serializers/modern.js`) encodes in untimed `prepare`:

```javascript
prepare(dataName, value) {
  jspbBytes = jspbEncode(dataName, value);   // untimed
},
serialize(_value) {
  const u8 = jspbBytes;
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  return jspbDecode(jspbDataName, u8, jspbIsBatch);
},
```

`jspbEncode` uses `BinaryWriter` primitives (`writeString`, `writeInt32`, `writeMessage`). Those calls are real Protocol Buffers writes. They run once, before the clock.

**protobufjs** (`javascript/src/serializers/schema.js`) builds a message in `prepare` and times encode:

```javascript
prepare(dataName, value) {
  pbType = pbRoot.lookupType(typeName);
  pbMsg = pbType.create(payload);          // untimed
},
serialize(_value) {
  return pbType.encode(pbMsg).finish();    // timed
},
deserialize(buf) {
  const decoded = pbType.decode(u8);
  return fromPbValue(pbDataName, decoded, pbIsBatch);
},
```

**protobuf-es** (`@bufbuild/protobuf` in `modern.js`) builds a typed message in `prepare` and times `toBinary`:

```javascript
prepare(dataName, value) {
  esMsg = create(esSchema, input);         // untimed
},
serialize(_value) {
  const u8 = toBinary(esSchema, esMsg);    // timed
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  const msg = fromBinary(esSchema, u8);
  return fromEsItem(esDataName, msg);      // domain copy is on the clock
},
```

So the encode column is three different quantities:

1. copy an existing `Uint8Array` into a Node `Buffer`;
2. walk a protobufjs message and emit tags;
3. walk a protobuf-es message and emit tags.

Only (2) and (3) answer “how expensive is JavaScript Protocol Buffers encode?”

## Why decode is the honest half

Every decode walks tags in JavaScript.

google-protobuf’s `jspbReadDocument` allocates a `BinaryReader` for the document, another for `meta`, and one per line item. Eight items means ten reader loops. Details are on the JSON comparison page.

protobufjs `Type.decode` is a generated-or-reflected field loop that fills a protobufjs message, then `fromPbValue` copies it to a plain object (`toJSON` or a spread). That second copy is on the clock and is part of the 17 µs.

protobuf-es `fromBinary` fills a protobuf-es message, then `fromEsItem` copies fields into a suite object. That copy is also on the clock (13 µs total). It is still faster than protobufjs here because the decode core is newer and typed, not because the bytes differ.

**History.** Protocol Buffers (Google, open-sourced 2008) specified the tags. `protoc --js_out` and the `google-protobuf` runtime brought that specification into browsers as `BinaryWriter` / `BinaryReader`. [protobufjs](https://github.com/protobufjs/protobuf.js) (Daniel Wirtz and contributors) loaded a `.proto` or a JSON descriptor at run time so teams could skip the compiler. [protobuf-es](https://github.com/bufbuild/protobuf-es) (Buf, early 2020s) generated TypeScript-first types and `toBinary` / `fromBinary`. Three engines, one wire article: [Protocol Buffers wire format](protobuf-wire-format.md).

## How to read the leaderboard

If you rank by ops/s, google-protobuf “wins.” If you add 431 ns + 5648 ns you are adding a buffer copy to a real decode. A fairer encode for that row would call `jspbEncode` inside `serialize`. The total would move toward protobufjs, not toward `JSON.stringify`.

If you rank by encode alone, you are ranking timer placement. protobuf-es looks worst (21 µs) because it does the work the first row deferred.

If you rank by size, all three tie. That is the format.

This is the JavaScript companion to [Same bytes, three runtimes](protobuf-cross-language-fidelity.md): there the languages differ and the bytes should match; here the language is one and the bytes do match, so the remaining story is the engine and the clock.

## Self-check

1. Which of the three `serialize` functions would you show a colleague who asked “how long does Protocol Buffers encode take in JavaScript on this suite?”
2. Why does equal size (155 B) prove the speed gap is not compactness?
3. protobuf-es times a domain copy on decode; google-protobuf builds a plain object directly. In which direction does that bias the decode column?
