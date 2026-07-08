# Dynamic vs IDL binary

> After reading this page, one should be able to choose between MessagePack/CBOR-class dynamic binary encodings and Protocol Buffers–class IDL binary encodings for a given workload, without asserting a universal ranking of formats.

---

## Problem

Suppose text JSON is already judged unsuitable for a particular hop—payloads are large enough, or the path is sufficiently performance-sensitive, that a binary encoding is under consideration. Two frequent alternatives are:

1. **Dynamic (schemaless) binary** — MessagePack, CBOR, and related formats: a data model similar to JSON, a binary encoding, little or no interface description language.  
2. **IDL / schema-driven binary** — Protocol Buffers and related systems: a shared schema, field numbers, code generation, and explicit evolution discipline.

Selections are often driven by popularity or by a single latency chart. A durable choice instead tracks **how flexible the data model must remain** and **how much investment will be made in a shared contract**.

---

## Short answer

**Dynamic binary** encodings preserve a flexible model of maps, arrays, and scalars, and usually place **type tags** and often **string keys** on the wire. They are a reasonable default for internal services and caches that seek smaller or faster-than-JSON payloads without operating a full IDL toolchain—**validation and compatibility remain the organization’s responsibility**. **IDL binary** encodings move names into a schema, encode **field numbers** (or equivalent identifiers), and support code generation, higher density, and multi-language stubs—at the cost of schema design, generation in continuous integration, and a process for change. Prefer dynamic binary when document shapes vary and consumers are loosely coupled; prefer IDL binary when the record shape is a product interface that will be versioned for years across languages.

---

## Mental model

```text
                 Binary encoding required?
                      │
          ┌───────────┴───────────┐
          ▼                       ▼
   Flexible documents        Stable record interface
   many optional shapes      multi-language RPC
          │                       │
          ▼                       ▼
   Dynamic binary            IDL / schema binary
   (MessagePack, CBOR, …)    (Protocol Buffers, …)
          │                       │
          ▼                       ▼
   Validate at boundaries    Schema + code generation
   document compatibility    + compatibility rules
```

Related dynamic formats (CBOR, BSON, and others) differ in type systems and ecosystem fit; the **decision axis relative to IDL binary** remains the same.

---

## How it works

### Dynamic binary encodings (MessagePack class)

**Data model.** Values are typically maps (string keys to values), arrays, numbers, strings, booleans, null, and often raw binary blobs—analogous to JSON, with format-specific extensions.

**Encoding idea (beginner sketch).** Instead of the characters `{`, `"id"`, `:`, `4`, `2`, a dynamic binary format might emit:

```text
  [tag: map with 1 entry]
    [tag: string length 2]  'i' 'd'
    [tag: small integer]    42
```

Exact tags differ by format; the pedagogical point is:

- structure is discovered from **tags in the stream**;  
- **keys often remain strings**, so messages stay self-describing at the cost of repeating those keys;  
- decimal digit conversion is avoided relative to JSON text.

**Evolution.** Change control is largely a social and testing process, optionally assisted by external schemas (for example JSON Schema–like definitions or shared types in source control).

### IDL binary encodings (Protocol Buffers class)

**Interface description.** Designers declare messages in an IDL; tools generate types and encoders for each supported language.

**Encoding idea (beginner sketch).** With schema

```text
  message Item {
    int32 id = 1;
    string label = 2;
  }
```

the wire form uses **field number 1** and **field number 2**, not the Unicode names `id` and `label`. Unknown field numbers can often be skipped, which supports forward compatibility when used correctly ([schema evolution](schema-evolution.md)).

**Density and speed** depend strongly on **generated** versus reflective code paths.

### Side-by-side miniature example

Logical value: `id = 42`, `label = "x"`.

| Approach | What a generic inspector sees without a project schema | Typical size tendency |
|----------|--------------------------------------------------------|------------------------|
| JSON text | Clear names and decimal numbers | Largest of the three |
| Dynamic binary with string keys | Recoverable map structure; keys visible as strings | Smaller than JSON; keys still present |
| IDL binary with field numbers | Opaque numbers unless the `.proto` (or equivalent) is available | Often smallest for stable records |

### What this comparison is not

- Not “Protocol Buffers versus Avro” (both are schema-centric; operational cultures differ—see the [data science perspective](../101/data_science_perspective.md) for Avro-oriented workloads).  
- Not “binary versus zero-copy” (FlatBuffers-class designs are a separate point—[zero-copy layouts](zero-copy.md)).  
- Not a guarantee that any MessagePack library outperforms any Protocol Buffers library in a given language.

---

## Costs and constraints

| Axis | Dynamic binary | IDL binary |
|------|----------------|------------|
| Size | Usually much smaller than JSON; often larger than a tight IDL encoding when string keys are used | Often smallest for stable records |
| Processor time | Efficient parsers exist; tag and key handling remain | Excellent with code generation; weaker if used only reflectively |
| Flexibility | High—maps and optional keys are natural | Schema changes are deliberate |
| Multiple languages | Broad library support without a single IDL | Strong when all languages participate in code generation |
| Operability | Pretty-printing tools required for support | Schema versions required on debug paths |
| Process cost | Low ceremony; risk of silent divergence | Higher ceremony; clearer shared types |
| Security | Depth and size limits; validate untrusted data | Same; generated types do not authenticate the sender |

---

## Illustrative scenarios

**A. Session document store.** A cache holds semi-structured user preferences that change weekly during product experimentation. MessagePack or CBOR between application nodes reduces size relative to JSON without requiring a schema-compiler release for every experiment. Validation belongs in the application’s typed model at write time.

**B. Multi-language billing interface.** A remote interface spans Go, Java, and Python over several years of field additions. Protocol Buffers (or a similar IDL system) with breaking-change checks in continuous integration is less costly than rediscovering, in each service, which string keys denote monetary amounts.

---

## In this suite

| Family | Examples (orientation—language **Overview** pages are authoritative) |
|--------|------------------------------------------------------------------------|
| Schemaless binary | Python `msgpack` / `cbor2`; JavaScript `msgpackr` / `cbor-x`; Go MessagePack/CBOR libraries; Rust `rmp-serde` / CBOR crates; C mpack/msgpack/cbor variants |
| Schema-driven | Protocol Buffers bindings where registered; other IDL or schema codecs per language |

Compare **within one language**, and prefer same-family charts when asking whether a library is competitive in its class. Cross-family ranking tables are decision inputs only when the workload genuinely lies on the boundary. See [Serialization categories](../../analysis/serialization_categories.md) and language **Results**.

---

## Common errors of reasoning

- Selecting Protocol Buffers “for speed” when the primary difficulty was public API inspectability (JSON at the edge may remain appropriate).  
- Adopting MessagePack without validation of untrusted input.  
- Expecting dynamic binary encodings that carry long Unicode keys to match IDL density.  
- Adopting an IDL without continuous-integration checks for compatibility or clear ownership of schema files.  
- Mixing dynamic maps and generated types on one hop without an explicit translation boundary.

---

## Key takeaways

- After rejecting JSON for a hop, the principal fork is **flexible documents** versus **stable multi-language records**.  
- Dynamic binary ≈ JSON-like data model with a binary encoding; the organization still owns the contract.  
- IDL binary ≈ shared schema, field numbers, code generation, and an evolution process.  
- Size and speed depend on implementation and on whether keys or names remain on the wire.  
- Use suite **Results** per language; do not treat informal ranking articles as policy.  
- Match process cost to the lifetime of the contract and the number of languages that share it.

---
