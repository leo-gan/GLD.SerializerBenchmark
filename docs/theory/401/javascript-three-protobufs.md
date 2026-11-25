# 4.11 Case Study: Same Wire Bytes, Three Implementations (JavaScript)

## Problem Statement

In [4.7 Cross-language fidelity](protobuf-cross-language-fidelity.md), we held the wire format constant while varying the programming language. Here we hold **both** the language (JavaScript on V8/Node.js) **and** the wire output (an identical **155-byte** proto3 message for `document`, $n = 1$) constant, varying only the library implementation: **`google-protobuf`**, **`protobufjs`**, and **`protobuf-es`** (`@bufbuild/protobuf`).

Because all three libraries emit identical 155-byte payloads, wire compactness cannot explain the $2.6\times$ total throughput spread. This study isolates pure **intra-standard implementation variance** ([3.9 Implementation variance](../301/using-this-suite.md#implementation-variance)) and documents how fixing an earlier timing bug in `prepare` changed the measured result by $5\times$.

> **Illustrative L1 snapshot (`document`, $n = 1$, `bytes` mode):** Live authoritative numbers belong to the [JavaScript Protocol Buffers Dashboard slice](../../dashboard/index.html?lang=javascript&standard=protobuf&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=google-protobuf&ser=google-protobuf&ser=protobufjs&ser=protobuf-es#compare) ([Claims L1](../../analysis/CLAIMS_AND_REPLICATION.md) · [JavaScript Overview](../../javascript/index.md)).

| Metric (Quoted L1 Snapshot) | `google-protobuf` | `protobufjs` | `protobuf-es` |
|---|---:|---:|---:|
| Throughput (encode + decode) | **70k ops/s** | 40k ops/s | 27k ops/s |
| Encode latency | 8.4 µs | **8.0 µs** | 22.0 µs |
| Decode latency | **6.0 µs** | 17.0 µs | 14.0 µs |
| Encoded wire size | **155 B** | **155 B** | **155 B** |

*(For the cross-standard contrast against V8's built-in C++ `JSON.stringify`/`JSON.parse`, see [JavaScript: JSON vs. `google-protobuf`](../../analysis/call-sites/javascript-json-vs-protobuf.md).)*

---

## Source-Level Call Sites and Timing Discipline

The JavaScript benchmark runner invokes three hooks: untimed `prepare(dataName, value)`, timed `serialize(value)`, timed `deserialize(buf)`, and untimed post-decode `toDomain(decoded)` (for fidelity checking).

### 1. `google-protobuf` (`javascript/src/serializers/modern.js`)

```javascript
prepare(dataName, value) {
  jspbDataName = dataName;
  jspbIsBatch = Array.isArray(value);
},
serialize(value) {
  const u8 = jspbEncode(jspbDataName, value);        // BinaryWriter calls (timed)
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  return jspbDecode(jspbDataName, u8, jspbIsBatch);  // BinaryReader -> plain JS object (timed)
},
```

### 2. `protobufjs` (`javascript/src/serializers/schema.js`)

```javascript
prepare(dataName, value) {
  pbType = pbRoot.lookupType(typeName);
  pbMsg = pbType.create(payload);                    // untimed
},
serialize(_value) {
  return pbType.encode(pbMsg).finish();              // timed
},
deserialize(buf) {
  return pbType.decode(u8);                          // timed (builds library Message)
},
toDomain(decoded) {
  return fromPbValue(pbDataName, decoded, pbIsBatch); // untimed
},
```

### 3. `protobuf-es` (`@bufbuild/protobuf` in `javascript/src/serializers/modern.js`)

```javascript
prepare(dataName, value) {
  esMsg = create(esSchema, input);                   // untimed
},
serialize(_value) {
  const u8 = toBinary(esSchema, esMsg);              // timed
  return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
},
deserialize(buf) {
  return fromBinary(esSchema, u8);                   // timed (builds typed ES Message)
},
toDomain(msg) {
  return fromEsItem(esDataName, msg);                // untimed
},
```

---

## Mechanistic Analysis

### Historical Timing-Bug Lesson

An earlier version of the `google-protobuf` adapter ran encoding inside untimed `prepare` and timed only a `Buffer` copy inside `serialize`—making `google-protobuf` appear ~$5\times$ faster than `protobuf-es`. Moving real `BinaryWriter` calls into `serialize` aligned all three adapters under the [Timing honesty](../../analysis/TIMING_HONESTY.md) contract and lowered `google-protobuf`'s encode throughput to its true parity with `protobufjs` (8.4 µs vs. 8.0 µs).

### Why Latency Still Diverges on Identical 155-Byte Output

None of the three libraries executes inside V8's built-in C++ runtime (unlike `JSON.parse`); all three execute varint/tag loops in JIT-compiled JavaScript:

1. **Encode (`8.0 µs` vs. `8.4 µs` vs. `22.0 µs`):** `protobufjs`[^1] compiles optimized per-message encoder code dynamically (or walks compact descriptors with a pooled chunked writer), and `google-protobuf` calls direct `BinaryWriter` methods (`writeString`, `writeInt32`, `writeMessage`). `protobuf-es`[^2] prioritizes TypeScript-first ergonomics, descriptor-driven reflection over generated `GenMessage` schemas, and strict edition/proto3 compliance—adding dispatch overhead per field on a small 155-byte record.
2. **Decode (`6.0 µs` vs. `14.0 µs` vs. `17.0 µs`):** `google-protobuf`'s `jspbDecode` reads tags with `BinaryReader` directly into plain JavaScript objects, whereas `protobufjs` (`Type.decode`) and `protobuf-es` (`fromBinary`) instantiate full library message objects with prototype metadata and schema checks (note that copying into suite objects via `toDomain` occurs *after* the timer stops, so the 14–17 µs gap reflects genuine decoder work).

---

## Exercises

1. **Eliminating wire-size hypotheses:** Why does observing **155 B** across all three rows immediately eliminate wire compactness as an explanation for the throughput differences?

??? note "Solution"
    Because every library writes and reads the exact same number of bytes (and the same proto3 tag/varint structure), differences in memory bandwidth or wire verbosity are zero. The entire spread arises from JavaScript execution paths, object allocation patterns, and descriptor/writer overhead inside each implementation.

2. **Auditing `prepare` bugs:** Suppose a benchmark PR introduces a new serializer adapter whose `encode` latency is $0.05\ \mu\text{s}$ while peer libraries in the same language and standard take $8$–$20\ \mu\text{s}$ on identical 155-byte output. What defect should a reviewer inspect first?

??? note "Solution"
    Check whether `prepare` is pre-serializing the message to bytes and `serialize` is merely copying or returning a cached `Buffer`/`Uint8Array` instead of walking the object and emitting wire bytes on every timed iteration ([Timing honesty](../../analysis/TIMING_HONESTY.md)).

3. **Selecting beyond microbenchmark speed:** Why might a TypeScript engineering team still choose `protobuf-es` over `google-protobuf` despite `protobuf-es` taking 22 µs vs. 8.4 µs on this 155-byte microbenchmark?

??? note "Solution"
    `protobuf-es` provides idiomatic modern TypeScript types, ESM tree-shaking, canonical JSON mapping, and active Buf ecosystem maintenance, whereas legacy `google-protobuf` ships older Closure-style JavaScript APIs. On typical web/Node.js services where network RTT is tens of milliseconds, a 14 µs encode difference is negligible compared with type safety and maintenance cost.

---

## References

[^1]: Wirtz, D., & Contributors. *`protobuf.js`: Protocol Buffers for JavaScript*. <https://github.com/protobufjs/protobuf.js>
[^2]: Buf Technologies. *`protobuf-es`: ECMAScript / TypeScript Protocol Buffers Runtime*. <https://github.com/bufbuild/protobuf-es>
