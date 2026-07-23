# Self-describing vs schema

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/self_describing_vs_schema.ipynb)
**Lab notebook:** [Self-describing vs schema lab](../notebooks/201/self_describing_vs_schema.ipynb)


## Problem

Two systems exchange the “same” logical record: an identifier, a name, and a monetary balance. Encoded as JSON, you can often open a log line and infer meaning from the field names. Encoded as a compact binary sequence without documentation nearby, the same person sees only opaque bytes until a schema file, interface description, or other authoritative specification is consulted.

The design question is not merely “are there types?” It is **where the meaning of each field is recorded** when the message is in transit or at rest.

---

## Short answer

**Self-describing** formats (to varying degrees) embed enough structure in the payload that a generic tool can recover a tree of values. Field names and/or type tags travel with the data. JSON, MessagePack, CBOR, and many “binary JSON” encodings sit in this family.

**Schema-dependent** formats omit most of that metadata from each message. Readers need a **shared schema or interface description language (IDL)**—a formal description of messages and field types shared by producers and consumers. Classic Protocol Buffers binary encoding, raw Avro data bytes, and many compact remote-procedure-call encodings work this way. For example, you need the schema to know that field number `3` means `balance` and how that field is encoded.

Self-describing formats typically trade larger size and extra parsing work for inspectability and flexibility. Schema-dependent formats trade an explicit, maintained contract and supporting tooling for density, code generation, and clearer evolution rules—when that contract is actually maintained.

---

## Mental model

![Self-describing payload versus schema-dependent encoding](../assets/diagrams/201-self-describing-vs-schema.svg#only-light)
![Self-describing payload versus schema-dependent encoding](../assets/diagrams/201-self-describing-vs-schema-dark.svg#only-dark)

“Self-describing” is a spectrum, not a single switch. JSON prioritizes human inspection. MessagePack remains machine-oriented yet still carries tags and often keys. Operational deployments that ship descriptor sets alongside Protocol Buffers are hybrid arrangements; they are not the minimal on-the-wire encoding.

---

## How it works

### Three questions every reader must answer

Any decoder must recover:

1. **Extent** — where each field begins and ends (delimiters, length prefixes, or fixed layout).
2. **Type** — whether the value is an integer, string, nested record, and so on (or a schema that fixes the type).
3. **Identity** — which logical field is present (name, numeric identifier, or positional index).

Self-describing formats answer (2) and (3) **inside the byte stream**. Schema-dependent formats answer them primarily from an **out-of-band contract** agreed at build or deployment time (sometimes versioned through a registry).

### Beginner example: one logical record, two encodings

Logical record:

| Field | Value |
|-------|--------|
| `user_id` | 42 |
| `name` | `Ada` |

**Self-describing text (JSON):**

```json
{"user_id":42,"name":"Ada"}
```

A general-purpose parser can construct a map without any project-specific schema file. The characters `user_id` and `name` appear in **every** message. That helps debugging, and it costs space when millions of messages are stored or transmitted.

**Schema-dependent sketch (Protocol Buffers style, conceptual):**

Suppose the shared schema states:

```text
  field number 1: user_id, 32-bit integer
  field number 2: name, length-delimited UTF-8 string
```

The on-the-wire form carries **field numbers and values**, not the Unicode names `user_id` and `name`. A reader that lacks the schema cannot reliably map number `1` to the product concept “user identifier.” Density improves because names are not repeated. **Correct interpretation depends on sharing the same schema version.**

### Why dense binary encodings “require” a schema

Protocol Buffers’ compact binary encoding is small largely **because field names are absent from the stream**—field numbers and wire types remain. Without the mapping from numbers to names and types, only limited generic inspection is possible. That property is not peculiar to one product; it is the general pattern of **schema-dependent density**. The schema is part of the product contract. The bytes are an encoding of values under that contract.

### “Schemaless” on the wire is not “no contract in the organization”

JSON and MessagePack do not eliminate the need for agreements among producers and consumers. They relocate validation, documentation, and compatibility policy into specifications such as OpenAPI or JSON Schema, shared source types, tests, and operational practice. The wire representation remains flexible. The organization still needs an authoritative definition of allowed shapes.

### Hybrid arrangements

| Arrangement | Where the contract lives | What the payload emphasizes |
|-------------|--------------------------|-----------------------------|
| Avro data file with embedded writer schema | File header and/or registry | Compact values, with the schema available nearby |
| Events with a schema-registry identifier | Registry entry referenced by id | Small per-record overhead; the full schema is fetched by id |
| JSON validated against JSON Schema | External schema document | Self-describing payload plus separate correctness checks |
| Protocol Buffers JSON mapping | Schema plus JSON field names | Human-oriented debugging at larger size |

---

## Costs and constraints

| Axis | Self-describing (typical) | Schema-dependent (typical) |
|------|---------------------------|----------------------------|
| Size / bandwidth | Names and tags are repeated, so payloads are larger | Often smaller for the same logical record |
| Processor time | Parse tags and names; flexible decoders | Less metadata; code generation can be efficient |
| Evolution | Easy to add keys; also easy to disagree silently | Explicit rules (field numbers, compatibility modes)—if you enforce them |
| Operability | Logs and support benefit from inspectable payloads | You need decoders and schema versions for observability |
| Tooling | Widely available generic parsers | IDL, code generation, and continuous-integration discipline |
| Security / trust | Untrusted input must still be validated | Presence of a schema does not by itself make input safe |

---

## Illustrative scenarios

**Public HTTP API.** JSON is retained so browsers, gateways, and external partners can inspect errors without a code generator.

**Internal event bus among owned services.** A schema-dependent binary codec with a registry reduces payload size; continuous integration enforces compatibility. Both designs can be appropriate. They locate field identity differently because **audiences and change-control processes** differ.

---

## In this suite

The suite’s families align roughly with this axis:

| Family | Typical metadata on the wire |
|--------|------------------------------|
| JSON (text) | Field names and textual structure |
| Schemaless binary | Type tags; often string keys |
| Schema-driven | Field numbers or layout derived from a schema |
| Language-native | Runtime type metadata (generally unsuitable as portable interchange) |

See [Serialization categories](../../analysis/serialization_categories.md) and language **Overview** pages for registered examples. Claims about density and speed belong on **Results**, not on the family label alone.

---

## Common errors of reasoning

- Describing JSON as “schemaless” as if the product had no contract at all.
- Expecting Protocol Buffers–like size from MessagePack while still transmitting full key strings in every message.
- Deploying schema-dependent bytes without a versioned account of which party holds which schema.
- Treating human readability as a substitute for validation at trust boundaries.
- Assuming that the existence of a schema makes deserialization safe against adversarial input. Resource limits and verifiers remain necessary.

---

## Key takeaways

- The central design choice is **where field identity and types live**: in the payload or in a shared contract.
- Self-describing formats favour flexibility and inspectability; they typically cost size and some parsing work.
- Schema-dependent formats favour density and code generation; they require tooling and contract discipline.
- “Protocol Buffers requires a schema” is one instance of the general lesson of **dense binary encoding without names on the wire**.
- Flexible wire formats still require organizational contracts—documentation, validators, and tests.
- Choose the locus of truth according to who must read the bytes and how change is managed.

---
