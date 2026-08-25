# Dynamic vs IDL binary

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/dynamic_vs_idl_binary.ipynb)
**Lab notebook:** [Dynamic vs IDL binary lab](../notebooks/201/dynamic_vs_idl_binary.ipynb)


## Problem

Suppose text JSON is already judged unsuitable for a particular hop. Payloads are large enough, or the path is performance-sensitive enough, that a binary encoding is under consideration. Two frequent alternatives are:

1. **Dynamic (schemaless) binary** — MessagePack, CBOR, and related formats. They keep a data model similar to JSON. They use a binary encoding. They need little or no **interface description language**. An IDL is a formal shared description of messages and field types.
2. **IDL / schema-driven binary** — Protocol Buffers and related systems. They use a shared schema, field numbers, code generation, and explicit evolution discipline.

Selections are often driven by popularity or by a single latency chart. A durable choice instead tracks two questions. How flexible must the data model remain? How much investment will you make in a shared contract?

---

## Short answer

**Dynamic binary** encodings preserve a flexible model of maps, arrays, and scalars. They usually place **type tags** and often **string keys** on the wire. They are a reasonable default for internal services and caches that want smaller or faster-than-JSON payloads without operating a full IDL toolchain. **Validation and compatibility remain the organization’s responsibility.**

**IDL binary** encodings move names into a schema. They encode **field numbers** (or equivalent identifiers). They support code generation, higher density, and multi-language stubs. The cost is schema design, generation in continuous integration, and a process for change.

Prefer dynamic binary when document shapes vary and consumers are loosely coupled. Prefer IDL binary when the record shape is a product interface that will be versioned for years across languages.

In other words: after you leave text JSON, the main fork is “flexible documents” versus “stable multi-language records.” It is not merely “which library is popular.”

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

Here **RPC** means remote procedure call. One program invokes an operation on another over the network. Related dynamic formats such as CBOR and BSON differ in type systems and ecosystem fit. The **decision axis relative to IDL binary** remains the same.

---

## How it works

### Dynamic binary encodings (MessagePack class)

**Data model.** Values are typically maps (string keys to values), arrays, numbers, strings, booleans, null, and often raw binary blobs. That is analogous to JSON, with format-specific extensions.

**Encoding idea (beginner sketch).** Instead of the characters `{`, `"id"`, `:`, `4`, `2`, a dynamic binary format might emit:

```text
  [tag: map with 1 entry]
    [tag: string length 2]  'i' 'd'
    [tag: small integer]    42
```

Exact tags differ by format. The teaching points are:

- structure is discovered from **tags in the stream**;
- **keys often remain strings**, so messages stay self-describing at the cost of repeating those keys;
- decimal digit conversion is avoided relative to JSON text.

**Evolution.** Change control is largely a social and testing process. External schemas can help. JSON Schema–like definitions or shared types in source control are examples.

### IDL binary encodings (Protocol Buffers class)

**Interface description.** Designers declare messages in an IDL. Tools generate types and encoders for each supported language.

**Encoding idea (beginner sketch).** With schema

```text
  message Item {
    int32 id = 1;
    string label = 2;
  }
```

the wire form uses **field number 1** and **field number 2**, not the Unicode names `id` and `label`. Unknown field numbers can often be skipped. That supports forward compatibility when used correctly. See [schema evolution](schema-evolution.md).

**Density and speed** depend strongly on **generated** versus reflective code paths. Generated code knows the field layout at compile time. Reflective paths discover structure at runtime and are often slower.

### Side-by-side miniature example

Logical value: `id = 42`, `label = "x"`.

| Approach | What a generic inspector sees without a project schema | Typical size tendency |
|----------|--------------------------------------------------------|------------------------|
| JSON text | Clear names and decimal numbers | Largest of the three |
| Dynamic binary with string keys | Recoverable map structure; keys visible as strings | Smaller than JSON; keys still present |
| IDL binary with field numbers | Opaque numbers unless the `.proto` (or equivalent) is available | Often smallest for stable records |

### What this comparison is not

- Not “Protocol Buffers versus Avro.” Both are schema-centric. Operational cultures differ. See the [data science perspective](../101/data_science_perspective.md) for Avro-oriented workloads.
- Not “binary versus zero-copy.” FlatBuffers-class designs are a separate point. See [zero-copy layouts](zero-copy.md).
- Not a guarantee that any MessagePack library outperforms any Protocol Buffers library in a given language.

---

## Costs and constraints

| Axis | Dynamic binary | IDL binary |
|------|----------------|------------|
| Size | Usually much smaller than JSON; often larger than a tight IDL encoding when string keys are used | Often smallest for stable records |
| Processor time | Efficient parsers exist; tag and key handling remain | Excellent with code generation; weaker if used only reflectively |
| Flexibility | High—maps and optional keys are natural | Schema changes are deliberate |
| Multiple languages | Broad library support without a single IDL | Strong when all languages participate in code generation |
| Operability | Pretty-printing tools are needed for support | Schema versions are needed on debug paths |
| Process cost | Low ceremony; risk of silent divergence | Higher ceremony; clearer shared types |
| Security | Depth and size limits; validate untrusted data | Same; generated types do not authenticate the sender |

---

## Illustrative scenarios

**A. Session document store.** A cache holds semi-structured user preferences that change weekly during product experimentation. MessagePack or CBOR between application nodes reduces size relative to JSON. A schema-compiler release is not required for every experiment. Validation belongs in the application’s typed model at write time.

**B. Multi-language billing interface.** A remote interface spans Go, Java, and Python over several years of field additions. Protocol Buffers (or a similar IDL system) with breaking-change checks in continuous integration is less costly. The alternative is rediscovering, in each service, which string keys denote monetary amounts.

---

## In this suite

| Family | Examples (orientation—language **Overview** pages are authoritative) |
|--------|------------------------------------------------------------------------|
| Schemaless binary | Python `msgpack` / `cbor2`; JavaScript `msgpackr` / `cbor-x`; Go MessagePack/CBOR libraries; Rust `rmp-serde` / CBOR crates; C mpack/msgpack/cbor variants |
| Schema-driven | Protocol Buffers bindings where registered; other IDL or schema codecs per language |

Compare **within one language**. Prefer same-family charts when asking whether a library is competitive in its class. Cross-family ranking tables are decision inputs only when the workload genuinely lies on the boundary. See [Serialization categories](../../analysis/serialization_categories.md) and the [Dashboard](../../dashboard/).

---

## Common errors of reasoning

- Selecting Protocol Buffers “for speed” when the primary difficulty was public API inspectability. JSON at the edge may remain appropriate.
- Adopting MessagePack without validation of untrusted input.
- Expecting dynamic binary encodings that carry long Unicode keys to match IDL density.
- Adopting an IDL without continuous-integration checks for compatibility or clear ownership of schema files.
- Mixing dynamic maps and generated types on one hop without an explicit translation boundary.

---

## Key takeaways

- After rejecting JSON for a hop, the principal fork is **flexible documents** versus **stable multi-language records**.
- Dynamic binary is roughly a JSON-like data model with a binary encoding. The organization still owns the contract.
- IDL binary is a shared schema, field numbers, code generation, and an evolution process.
- Size and speed depend on implementation and on whether keys or names remain on the wire.
- Use the **Dashboard** per language. Do not treat informal ranking articles as policy.
- Match process cost to the lifetime of the contract and the number of languages that share it.

---
