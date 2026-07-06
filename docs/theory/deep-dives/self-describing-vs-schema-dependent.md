# Self-describing vs schema-dependent

> After this page you can say who carries field identity—the payload or a shared contract—and what that choice buys and costs.

---

## Problem

Two teams ship the “same” record: an id, a name, and a balance. In JSON, a new engineer can open a log line and guess the meaning. In a compact binary blob, the same engineer sees opaque bytes until someone points at a `.proto`, an Avro schema, or a wiki that may be wrong.

The design question is not “do we have types?” It is **where the meaning of each field lives** when the message is in flight or at rest.

---

## Short answer

**Self-describing-ish** formats carry enough structure in the payload for a generic tool to parse a tree: field names and/or type tags travel with the data (JSON, MessagePack, CBOR, many “binary JSON” codecs). **Schema-dependent** formats omit most of that metadata from the message: readers need a **shared schema or IDL** (classic Protobuf binary, raw Avro datum bytes, many tight RPC encodings) to know that field `3` is `balance` and how it is encoded. Self-describing formats trade size and some CPU for inspectability and flexibility. Schema-dependent formats trade up-front contract and tooling for density, codegen, and clearer evolution rules—when teams actually maintain the contract.

---

## Mental model

```text
  Self-describing-ish                    Schema-dependent
  ┌──────────────────────────┐           ┌──────────────────────────┐
  │ {"user_id": 42,          │           │ schema / IDL (shared)    │
  │  "name": "Ada", …}       │           │   field 1 = user_id      │
  │  names + values on wire  │           │   field 2 = name …       │
  └──────────────────────────┘           └────────────┬─────────────┘
                                                     │
                                                     ▼
                                         ┌──────────────────────────┐
                                         │ 08 2a 12 03 41 64 61 …   │
                                         │  numbers / layout only   │
                                         └──────────────────────────┘
```

“Self-describing” is a spectrum: JSON is human-oriented; MessagePack is machine-oriented but still tagged; Protobuf with an embedded descriptor set is a hybrid operational story, not the default minimal encoding.

---

## How it works

### What the payload must answer

Any reader needs to recover:

1. **Where fields start and end** (delimiters, length prefixes, or fixed layout).
2. **What type of value** is present (or a schema that fixes the type).
3. **Which logical field** this is (name, ordinal, or position).

Self-describing formats answer (2) and (3) **inside the stream**. Schema-dependent formats answer them **from an out-of-band contract** agreed at build or deploy time (and sometimes versioned via a registry).

### Why Protobuf “needs” a schema (the real lesson)

Protobuf’s binary encoding is dense **because** field *names* are not on the wire—**field numbers** and wire types are. Without the schema mapping numbers to names and types, you can only do limited generic decoding. That is not a Protobuf quirk; it is the general pattern of **schema-dependent density**. The schema is the product; the bytes are an encoding of values under that product.

### Schemaless is not “schemaless product”

JSON and MessagePack do not free you from contracts. They move validation, documentation, and compatibility policy into **OpenAPI, JSON Schema, shared types, or tribal knowledge**. The wire stays flexible; the organization still needs a source of truth.

### Hybrids

- **Avro** often stores a writer schema with data files, or uses a **schema registry** id with events—schema is first-class even when not every field name repeats per record.
- **JSON + schema validation** keeps a self-describing payload and an external contract for correctness.
- **Protobuf JSON mapping** can reintroduce names for debugging at a size cost.

---

## Costs & constraints

| Axis | Self-describing-ish | Schema-dependent |
|------|---------------------|------------------|
| Size / bandwidth | Names/tags repeat; larger | Often smaller for the same logical record |
| CPU | Parse tags/names; flexible decoders | Less metadata; codegen can be very fast |
| Evolution | Easy to add keys; easy to *silently* disagree | Explicit rules (field numbers, compatibility modes)—if enforced |
| Operability | Logs and support love inspectable payloads | Need decoders, schema versions in observability |
| Tooling | Universal parsers | IDL, codegen, CI discipline |
| Security / trust | Still validate untrusted input | Still verify; do not confuse “has schema” with “safe” |

---

## Real-world example

A public HTTP API stays on JSON so browser tools, gateways, and partners can read errors without a code generator. An internal event bus between owned services switches to a schema-dependent binary codec with a registry: payloads shrink, and CI enforces compatibility. Both choices are “correct”; they place field identity in different places because **audiences and change processes** differ.

---

## In this suite

The suite’s families roughly track this axis:

| Family | Typical wire metadata |
|--------|------------------------|
| JSON (text) | Field names, text structure |
| Schemaless binary | Type tags; often string keys |
| Schema-driven | Field numbers / layout from schema |
| Language-native | Runtime type metadata (not portable interchange) |

See [Serialization categories](../../analysis/serialization_categories.md) and language **Overview** pages for registered examples. Density and speed claims belong on **Results**, not on the family label alone.

---

## Common mistakes

- Calling JSON “schemaless” as if the product has no contract.
- Expecting Protobuf-like size from MessagePack while sending full key strings every time.
- Deploying schema-dependent bytes without a versioned schema story (who has which version?).
- Treating “we can open it in a text editor” as a substitute for validation at trust boundaries.
- Assuming a schema makes deserialization **safe** against hostile input (resource limits and verifiers still matter).

---

## Key takeaways

- The core design choice is **where field identity and types live**: in the payload or in a shared contract.
- Self-describing formats buy flexibility and inspectability; they pay in size and some parse work.
- Schema-dependent formats buy density and codegen; they pay in tooling and contract discipline.
- “Protobuf needs a schema” is the general lesson of **dense binary without names on the wire**.
- Schemaless wires still need organizational schemas (docs, validators, tests).
- Pick the locus of truth that matches who must read the bytes and how you manage change—next: [Schema evolution](schema-evolution.md).

---
