# 2.4 Self-Describing vs. Schema-Dependent Encodings

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/self_describing_vs_schema.ipynb)

## Problem Statement

Any decoder reading a serialized byte stream must recover three facts for every field:

1. **Extent:** Where the field begins and ends (via delimiters, length prefixes, or fixed widths).
2. **Type:** How the bytes should be interpreted (integer, floating-point, UTF-8 string, array, nested record).
3. **Identity:** Which logical attribute the value represents (field name, numeric tag, or positional index).

The fundamental structural divide among serialization standards is **where type and identity metadata live**: embedded inside every payload on the wire, or held out of band in a shared schema contract.

---

## Core Distinction and Spectrum

!!! note "Definition: Self-Describing vs. Schema-Dependent"
    - A **self-describing** encoding carries field names and/or type tags inside the byte stream itself so a generic parser can reconstruct a tree of values without an application-specific schema (e.g., JSON, XML, MessagePack, CBOR, Amazon Ion).
    - A **schema-dependent** encoding omits field names (and often type tags) from individual payloads; interpreting the bytes requires a shared external schema or interface description (e.g., Protocol Buffers binary, raw Avro, SBE, FlatBuffers).

![Self-describing payload versus schema-dependent encoding](../assets/diagrams/201-self-describing-vs-schema.svg#only-light)
![Self-describing payload versus schema-dependent encoding](../assets/diagrams/201-self-describing-vs-schema-dark.svg#only-dark)

### Worked Comparison

For the logical record `{user_id: 42, name: "Ada"}`:

- **Self-describing JSON (27 bytes):**[^2]
  ```json
  {"user_id":42,"name":"Ada"}
  ```
  Any generic parser reconstructs both keys and values without external files, but the ASCII strings `"user_id"` and `"name"` are transmitted in every single record.
- **Schema-dependent Protocol Buffers binary (7 bytes):**[^3]
  With a shared schema assigning `user_id = 1` (varint) and `name = 2` (length-delimited UTF-8), the wire sequence is `08 2a 12 03 41 64 61`. Field names are absent; without the `.proto` definition, a reader can see only "field 1 = varint 42, field 2 = 3 bytes `Ada`."

### Hybrid Points Along the Spectrum

Self-description is a continuum rather than a strict binary switch. Production systems frequently combine wire compactness with accessible metadata:

| Arrangement | Locus of Schema Metadata | Resulting Trade-Off |
|---|---|---|
| **Avro Object Container File / Parquet**[^4] | Writer schema embedded once in file header or footer | Amortizes schema overhead across thousands or millions of records |
| **Event bus + Schema Registry** | Compact 4-byte schema ID prefixed to each message; schema stored in registry | Minimal per-message overhead while preserving full historical interpretability |
| **JSON + JSON Schema / OpenAPI** | Self-describing wire payload validated against an external specification | Retains human debuggability while enforcing strict structural contracts |
| **Protocol Buffers JSON mapping** | Same `.proto` schema emitted with text field names for debugging edges | Trades wire density for human readability on diagnostic or HTTP boundaries |

**Crucial distinction:** "Schemaless on the wire" does *not* mean "no contract in the organization." Teams using JSON or MessagePack still must govern allowed shapes, optionality, and breaking changes through validators, contract tests, and documentation.[^1]

---

## Trade-Offs and Failure Modes

| Dimension | Self-Describing (JSON, MessagePack, CBOR) | Schema-Dependent (Protocol Buffers, Avro, FlatBuffers, SBE) |
|---|---|---|
| **Wire size** | Larger; field names and type tags repeat per record | Compact; names omitted from payload |
| **CPU cost** | Key hashing / string comparison and dynamic dispatch | Integer tag switch or fixed-offset loads via generated code |
| **Observability** | Logs and captures inspectable with generic tools | Requires schema-aware decoders and version tracking |
| **Tooling & process** | Minimal build friction; universal generic parsers | Requires IDL authoring, codegen in CI, and version governance |
| **Security** | Untrusted shapes still require validation and depth/size limits | Presence of a schema does not replace bounds checks or input limits |

**Common pitfalls:**
- Expecting MessagePack or CBOR maps (which still encode string keys) to match Protocol Buffers wire size.
- Archiving raw schema-dependent bytes without recording which schema version produced them, leaving historical archives unreadable.
- Assuming a schema compiler makes untrusted inputs inherently safe against oversized or deeply nested payloads.

---

## Connection to the Benchmark Suite

The suite's teaching families ([Families](../../analysis/families.md)) align closely with this axis: **JSON** and **schemaless binary** transmit names/tags per message; **schema-driven** codecs rely on generated IDLs (`schemas/v2/`); **columnar** files (Parquet, ORC, Arrow IPC) carry schemas once per file footer or stream header. Note that **SBE** is a schema-driven single-record format measured on the `columnar` data set (`signal`), not a columnar file format. Compare density and speed within one language and data type on the [Dashboard](../../dashboard/index.html).

---

## Exercises

1. **Wire overhead scaling:** Suppose a telemetry record has 6 fields whose average JSON key name is 10 bytes, and its values total 24 bytes in compact binary form. Estimate the fraction of wire bytes spent on key names alone in a self-describing map encoding, and explain how batching 1,000 records into an Avro container file changes that fraction.

??? note "Solution"
    In a single self-describing record, key names alone contribute ~60 bytes (plus quotes/delimiters or length tags), making metadata >70% of the ~84+ byte payload. In an Avro container file, the schema (a few hundred bytes) is written **once** in the file header and amortized across 1,000 records (~0.3–0.5 bytes/record), leaving nearly 100% of the body for values.

2. **Inspecting unknown bytes:** You receive the 7-byte Protocol Buffers payload `08 2a 12 03 41 64 61` without a `.proto` file. Which of the three decoder questions (*extent*, *type*, *identity*) can you recover from the bytes alone, and which cannot be recovered reliably?

??? note "Solution"
    - **Extent:** Recoverable (varint continuation bits and length prefix `03` delimit every field).
    - **Type:** Partially recoverable at the *wire-type* level only (field 1 is a varint, field 2 is 3 length-delimited bytes—you cannot tell whether field 1 is `int32`, `sint32`, `uint64`, or `enum`, nor whether field 2 is a UTF-8 string, raw `bytes`, or a nested message).
    - **Identity:** **Not recoverable** (field numbers `1` and `2` carry no semantic names without the schema).

3. **Hybrid selection:** An external partner API must remain debuggable with `curl`, yet partners repeatedly send strings where integers are expected. Should the team migrate the wire format to Protocol Buffers, or adopt a hybrid arrangement? Justify your answer.

??? note "Solution"
    Adopt a **hybrid arrangement**: keep JSON on the wire for `curl` inspectability and partner ergonomics, and enforce a strict **JSON Schema / OpenAPI** contract (backed by server-side typed validation) at the API gateway so malformed types fail fast with explicit errors.

---

## References

[^1]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4: "Encoding and Evolution." O'Reilly Media.
[^2]: Bray, T. (Ed.). (2017). *The JavaScript Object Notation (JSON) Data Interchange Format*. IETF RFC 8259. <https://www.rfc-editor.org/rfc/rfc8259>
[^3]: Protocol Buffers Documentation. *Encoding Guide*. <https://protobuf.dev/programming-guides/encoding/>
[^4]: Apache Software Foundation. *Apache Avro Specification (§ Object Container Files)*. <https://avro.apache.org/docs/>
