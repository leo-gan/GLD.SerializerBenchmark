# JavaScript: three Protocol Buffers libraries, one encoding

## Why this article exists

The [JSON versus google-protobuf](javascript-json-vs-protobuf.md) page compared one Protocol Buffers library with `JSON.stringify`. A fair question follows. What happens when two other JavaScript libraries write the **same 155-byte** Protocol Buffers message?

This page places **google-protobuf**, **protobufjs**, and **protobuf-es** side by side. After reading it you should be able to name the functions that are timed, explain why the three totals differ, and relate the result to [Same bytes, three runtimes](protobuf-cross-language-fidelity.md), which asked the same question across languages.

Numbers in the table below are a **quoted L1 slice** (document, n=1, bytes)
from this suite’s packed Dashboard data, after google-protobuf encode was
moved into timed `serialize`. They illustrate the gap; they are not a
universal ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=javascript&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=google-protobuf&ser=google-protobuf&ser=protobufjs&ser=protobuf-es#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [JavaScript overview](../../javascript/)

## Short answer

All three libraries write the same **155-byte** proto3 message. The message uses field numbers 1 through 4 and variable-length integers. It does not store field names. Because the three encodings have the same length, compactness cannot explain the speed difference.

The JavaScript runner calls three methods on each adapter.

- `prepare(dataName, value)` runs once. It is **not** timed. It may store the data type and build a library message. It must not write the output bytes.
- `serialize(value)` runs many times. It is timed. That time is reported as encode.
- `deserialize(buf)` runs many times. It is timed. That time is reported as decode.

All three adapters now write the 155 bytes inside `serialize`. The encode column therefore measures the same kind of work: walk a value and emit Protocol Buffers bytes.

On this slice, protobufjs and google-protobuf encode in about **8 µs**. protobuf-es takes 22 µs. We can see that in the Encode row of the table.

**google-protobuf is the fastest decoder** (6.0 µs). protobuf-es takes 14 µs. protobufjs takes 17 µs. google-protobuf builds an ordinary JavaScript object directly. The other two first build a library message. The later copy into a suite object is **not** timed (`toDomain` after the clock).

On total cycles per second, google-protobuf is first (about 70 thousand) because decode is much shorter. protobufjs is next (40 thousand). protobuf-es is last (27 thousand). None of the three decoders runs inside V8’s built-in C++ runtime. Each walks the byte stream in JavaScript.

| | google-protobuf | protobufjs | protobuf-es |
|--|-----------------|------------|-------------|
| Mean encode + decode | **70 thousand / s** | 40 thousand / s | 27 thousand / s |
| Encode | 8.4 µs | **8.0 µs** | 22 µs |
| Decode | **6.0 µs** | 17 µs | 14 µs |
| Encoded size | **155 B** | **155 B** | **155 B** |

An earlier version of this adapter encoded in `prepare` and timed only a `Buffer` copy. That made google-protobuf look about five times as fast as protobuf-es. The copy was not an encode. The table above is the fair comparison.

## The three timed call sites

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
  return jspbDecode(jspbDataName, u8, jspbIsBatch);
},
```

`jspbEncode` uses `BinaryWriter` primitives (`writeString`, `writeInt32`, `writeMessage`). Those calls are real Protocol Buffers writes. They now run on every timed encode.

**protobufjs** (`javascript/src/serializers/schema.js`) builds a message in `prepare` and encodes in `serialize`:

```javascript
prepare(dataName, value) {
  pbType = pbRoot.lookupType(typeName);
  pbMsg = pbType.create(payload);          // untimed
},
serialize(_value) {
  return pbType.encode(pbMsg).finish();    // timed
},
deserialize(buf) {
  return pbType.decode(u8);               // timed
},
toDomain(decoded) {
  return fromPbValue(pbDataName, decoded, pbIsBatch);
},
```

**protobuf-es** (`@bufbuild/protobuf` in `modern.js`) builds a typed message in `prepare` and encodes in `serialize`:

```javascript
prepare(dataName, value) {
  esMsg = create(esSchema, input);         // untimed
},
serialize(_value) {
  const u8 = toBinary(esSchema, esMsg);    // timed
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  return fromBinary(esSchema, u8);         // timed
},
toDomain(msg) {
  return fromEsItem(esDataName, msg);
},
```

The encode column therefore reports three real encodes:

1. walk the document with google-protobuf `BinaryWriter`;
2. walk a protobufjs message and write Protocol Buffers bytes;
3. walk a protobuf-es message and write Protocol Buffers bytes.

That is the fair answer to “how long does a JavaScript Protocol Buffers encode take on this suite?”

## Why the decode times differ

Every decode walks the 155-byte message in JavaScript.

google-protobuf’s `jspbReadDocument` allocates a `BinaryReader` for the document, another for the nested `meta` message, and one reader for each line item. Eight items means ten reader loops. Details are on the JSON comparison page. The decoder writes an ordinary object. There is no second copy after decode. That is why its decode time is the shortest of the three.

protobufjs `Type.decode` walks each field and fills a protobufjs message. The field list may come from generated code or from a descriptor loaded at run time. `fromPbValue` copies that message into an ordinary object after the timer (`toDomain`).

protobuf-es `fromBinary` fills a protobuf-es message. `fromEsItem` copies the fields into an ordinary object after the timer. The remaining decode gap is in the two JavaScript decoders, not in a second copy.

**History.** Protocol Buffers (Google, open-sourced 2008) defined the binary layout: a field number, a wire type, and a payload. `protoc --js_out` and the `google-protobuf` runtime brought that specification into browsers as `BinaryWriter` / `BinaryReader`. [protobufjs](https://github.com/protobufjs/protobuf.js) (Daniel Wirtz and contributors) loaded a `.proto` file or a JSON descriptor at run time so teams could skip the compiler. [protobuf-es](https://github.com/bufbuild/protobuf-es) (Buf, early 2020s) generated TypeScript-first types and `toBinary` / `fromBinary`. Three libraries, one binary layout: [Protocol Buffers wire format](protobuf-wire-format.md).

## How to read the leaderboard

If you rank the three rows by cycles per second, google-protobuf is first. That ranking is no longer a buffer copy plus a decode. It is a real encode plus a decode that builds an ordinary object in one step.

If you rank the three rows by encode time alone, protobufjs and google-protobuf are nearly equal (8.0 µs and 8.4 µs). protobuf-es is last (22 µs). All three numbers are encodes.

If you rank the three rows by encoded size, they are equal. All three write the same Protocol Buffers message. Size does not explain the speed gap.

This page is the JavaScript companion to [Same bytes, three runtimes](protobuf-cross-language-fidelity.md). There the languages differ and the bytes should match. Here the language is JavaScript and the bytes do match. The remaining difference is how each library writes and reads those bytes.

## Self-check

1. Which of the three `serialize` functions has the shortest encode time on this slice, and which library call does it make?
2. Why does equal size (155 B) prove that the speed gap is not caused by a more compact encoding?
3. After the `toDomain` hook, protobuf-es no longer copies fields during timed decode. What work is still left inside protobuf-es `deserialize`?
