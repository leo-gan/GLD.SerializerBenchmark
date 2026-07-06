# Dynamic binary vs IDL binary

> After this page you can choose between MessagePack/CBOR-class dynamic binary and Protobuf-class IDL binary for a workload—without crowning a universal winner.

---

## Problem

You already decided “not JSON on this hop”—payloads are large enough or hot enough that text is unattractive. Two common next stops:

1. **Dynamic (schemaless) binary** — MessagePack, CBOR, and relatives: JSON-like data model, binary encoding, little or no IDL.
2. **IDL / schema-driven binary** — Protocol Buffers and kin: shared schema, field numbers, codegen, explicit evolution discipline.

Teams often pick by popularity or by a single latency chart. The durable choice tracks **how flexible the data model must stay** and **how hard you will work on a shared contract**.

---

## Short answer

**Dynamic binary** keeps a flexible map/array/scalar model and usually still puts **type tags** and often **string keys** on the wire. It is a strong default for internal services and caches that want smaller/faster-than-JSON payloads without owning an IDL pipeline—**you still own validation and compatibility**. **IDL binary** pushes names into a schema, encodes **field numbers** (or equivalent), and unlocks codegen, tighter density, and multi-language stubs—at the cost of schema design, generation in CI, and process for change. Prefer dynamic binary when documents vary and many consumers are loosely coupled; prefer IDL binary when the record shape is a product API you will version for years across languages.

---

## Mental model

```text
                 Need binary?
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
   Flexible documents      Stable record API
   many optional shapes    multi-language RPC
          │                       │
          ▼                       ▼
   Dynamic binary            IDL / schema binary
   (MsgPack, CBOR, …)        (Protobuf, …)
          │                       │
          ▼                       ▼
   Validate at edges         Schema + codegen +
   document compatibility    compatibility rules
```

Siblings in the dynamic family (CBOR, BSON, …) differ in type systems and ecosystem fit; the **decision axis vs IDL** is the same.

---

## How it works

### Dynamic binary (MessagePack-class)

- Data model ≈ JSON (maps, arrays, numbers, strings, binaries—details vary).
- Encoding uses compact **tags** instead of text punctuation and decimal numbers.
- **Keys** are often still strings (unless you adopt conventions like integer keys).
- Decoders can be schema-free; structure is discovered from the stream.
- Evolution = social process + optional external schema (JSON Schema-like, shared types).

### IDL binary (Protobuf-class)

- You define messages in an **IDL**; tools generate types and encoders.
- Wire form uses **field numbers** and known scalar encodings (e.g. varints).
- Unknown fields can be skipped for forward compatibility when used correctly.
- Density and speed depend heavily on **generated** vs reflective paths.
- Evolution = field-number discipline, reserved ids, optional additive fields ([schema evolution](schema-evolution.md)).

### What this comparison is *not*

- Not “Protobuf vs Avro” (both schema-centric; different cultures—Avro deferred to a later article / data-science lens).
- Not “binary vs zero-copy” (FlatBuffers-class is another design point—[zero-copy](zero-copy.md)).
- Not a promise that any MessagePack library beats any Protobuf library in your language.

---

## Costs & constraints

| Axis | Dynamic binary | IDL binary |
|------|----------------|------------|
| Size | Usually ≪ JSON; often \> tight Protobuf for named keys | Often smallest for stable records |
| CPU | Fast parsers exist; still tag/key work | Excellent with codegen; poor if misused reflectively |
| Flexibility | High—maps and optional keys are natural | Schema changes are deliberate |
| Polyglot | Wide library support; no single IDL | Strong when all languages in the codegen matrix |
| Operability | Need tooling to pretty-print | Need schema versions in debug paths |
| Process cost | Low ceremony; risk of silent drift | Higher ceremony; clearer shared types |
| Security | Limits on depth/size; validate untrusted data | Same; generated types ≠ authenticated sender |

---

## Real-world example

**A.** A Redis-backed session store holds semi-structured preferences that product tweaks weekly. MessagePack (or CBOR) between app nodes shrinks values versus JSON without forcing a `protoc` release for every experiment. Validation lives in the app’s typed settings model at write time.

**B.** A billing RPC spans Go, Java, and Python for five years of field additions. Protobuf (or similar) with breaking-change checks in CI is cheaper than rediscovering which string keys mean `amount` in which service.

---

## In this suite

| Family | Examples (orientation—see language Overviews for SoT) |
|--------|--------------------------------------------------------|
| Schemaless binary | Python `msgpack` / `cbor2`; JS `msgpackr` / `cbor-x`; Go msgpack/cbor; Rust `rmp-serde` / CBOR crates; C mpack/msgpack/cbor variants |
| Schema-driven | Protobuf bindings where registered; other IDL/schema codecs per language |

Compare **within one language** and prefer same-family charts when asking “is this library competitive?” Cross-family “winner” tables are decision inputs only when your workload truly sits on the fence. [Categories](../../analysis/serialization_categories.md) · language **Results**.

---

## Common mistakes

- Picking Protobuf “for speed” when the pain was public API debuggability (stay on JSON at the edge).
- Picking MessagePack and never validating—schemaless bytes with hostile input.
- Expecting dynamic binary to match IDL density while sending long Unicode keys every time.
- Adopting IDL without CI for compatibility or ownership of `.proto` files.
- Mixing models in one hop without an explicit anti-corruption layer (half map, half codegen DTO chaos).

---

## Key takeaways

- After “not JSON,” the fork is **flexible documents** vs **stable multi-language records**.
- Dynamic binary ≈ JSON data model with a binary encoding; you still own the contract.
- IDL binary ≈ shared schema, field numbers, codegen, and evolution process.
- Size/speed depend on implementation and whether keys/names stay on the wire.
- Use suite **Results** per language; do not treat blog leaderboards as policy.
- Match ceremony to how long the contract will live and how many languages share it.

---

## Next

[Zero-copy layouts](zero-copy.md) — when the goal is not “faster parse into objects,” but reading fields **in place**.

**See also:** [Serialization categories](../../analysis/serialization_categories.md) · [Encode/decode cost](encode-decode-cost.md)
