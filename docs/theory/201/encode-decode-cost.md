# Encode/decode cost

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/encode_decode_cost.ipynb)
**Lab notebook:** [Encode/decode cost playground](../notebooks/201/encode_decode_cost.ipynb)


## Problem

People sometimes declare a format “winner” from a single chart—“replace text with binary and improve performance by an order of magnitude.” Organizations then change codecs and see little improvement, or even a regression, because the limiting factor was never “text versus binary” as an abstract dichotomy. The dominant costs are typically **tokenization** (finding structure in the bytes), **numeric conversion**, **memory allocation**, **copying**, and **payload shape**.

---

## Short answer

The cost of encoding and decoding is the sum of several mechanisms, not one magic property of “text” or “binary.”

Text formats—especially JSON—spend work scanning character encodings such as UTF-8, recognizing structural tokens, unescaping strings, and converting **decimal digit sequences** into the binary integer and floating-point forms the processor actually uses. Binary formats usually avoid decimal text and often omit repeated field *names*, yet they still pay for length prefixes, type tags or field numbers, validation, and construction of language-level objects.

In managed runtimes, **allocation rate and garbage collection** (GC = automatic reclamation of unused memory) often dominate the time spent inside the encode or decode routine itself. A carefully engineered JSON implementation may outperform an inefficient binary stack. A payload made of many small, pointer-linked objects stresses every codec.

---

## Mental model

```text
  In-memory values (objects, records, maps)
        │
        ▼
  ┌─────────────┐     Processor work: traverse structure, format values
  │   Encode    │ ──► grow an output buffer; possibly copy
  └─────────────┘
        │ sequence of bytes
        ▼
  ┌─────────────┐     Processor work: scan or parse; validate
  │   Decode    │ ──► allocate language objects; assign fields
  └─────────────┘
        │
        ▼
  In-memory values again
```

For any performance-critical path, useful questions include:

1. How many times is each byte examined?
2. How many distinct heap objects are created?
3. How often are values converted between **decimal text** and **binary numeric forms**?

---

## How it works

### From human-readable text to processor values (and the reverse)

Consider a minimal JSON object:

```json
{"id": 42, "temp_c": 21.5, "label": "sensor-7"}
```

As **text**, this is a sequence of characters, commonly stored as UTF-8 bytes. The processor does not “natively” understand braces or the decimal notation `21.5`. A JSON decoder must, among other steps:

1. **Discover structure** — locate `{`, `:`, `,`, `}`, and string delimiters. Simple parsers do this with many conditional branches. Highly optimized parsers may use SIMD (single instruction, multiple data) instructions, but the logical task remains structure discovery.
2. **Interpret strings** — read the bytes between quotes; apply escape rules (for example `\n`); often allocate a string object in the language runtime.
3. **Interpret numbers** — read the characters `2`, `1`, `.`, `5` and compute the binary floating-point value the CPU will use in arithmetic. That conversion is non-trivial and can dominate runtime on numeric-heavy payloads.
4. **On encode (printing)** — convert binary integers and floats back into decimal digit characters; escape strings; emit punctuation.

**Worked contrast for one integer.** The logical value forty-two may appear as:

| Representation | Illustrative bytes (concept) | Work to obtain a machine integer |
|----------------|------------------------------|----------------------------------|
| JSON text `"id": 42` | characters `4` and `2`, plus surrounding structure | Scan the digits, then multiply and accumulate to form 42 |
| Fixed 32-bit little-endian binary | four bytes, for example `2a 00 00 00` | Load four bytes with a known byte order |
| Compact binary “varint” (sketch) | one or more bytes encoding small integers densely | Loop over continuation bits, then shift and combine |

No row is universally “best.” The table only makes visible **where processor time goes**.

### Metadata that travels with the message

Even without human-oriented punctuation, many binary formats still carry **descriptive metadata**:

- **Type tags** — for example “the next value is a 32-bit integer,” or “the next value is a UTF-8 string of length *n*.”
- **Field names** — string keys such as `"temp_c"` repeated for every record. This is common in MessagePack maps and in JSON.

Schema-dependent formats such as Protocol Buffers typically replace names on the wire with **small field numbers** defined in a shared schema. That reduces per-message metadata at the cost of an out-of-band contract. See [Self-describing vs schema](self-describing-vs-schema-dependent.md).

### Memory allocation and copying

A common decode path in managed languages (Python, Java, C#, JavaScript, and similar environments) looks like this:

```text
  byte buffer
      → allocate a map or object
      → for each field: allocate a string key and/or value object
      → return a fully populated graph
```

Each allocation has a direct cost and contributes to later **garbage collection** work, which can increase latency variability (tail latency—the slowest requests). Alternative designs reduce that cost:

- decode into a preallocated structure;
- reuse buffers across requests;
- expose **views** into the existing byte buffer (related to [zero-copy layouts](zero-copy.md)).

In practice, “a faster serializer” in managed languages often means **fewer allocations**, not merely fewer arithmetic instructions inside the encode loop.

### Payload shape

Two messages with the same logical “size in fields” can behave very differently:

| Shape (illustrative) | Characteristic cost |
|----------------------|---------------------|
| One flat record: a few large integers and one large binary blob | Fewer objects; more bulk memory-copy bandwidth |
| A deep tree: hundreds of small nested objects and short strings | Many allocations; poor locality (scattered memory access) |

**Shape can matter as much as the choice of format family.** This suite uses controlled fixtures so comparisons stay interpretable within a language; see [Test Data](../../analysis/test_data_configuration.md).

### Implementation quality

The label “JSON” covers both pedagogical recursive parsers and highly optimized libraries. The label “Protocol Buffers” covers both reflection-based and fully code-generated paths. Comparisons should fix **language**, **implementation**, and **payload**, not only the marketing name of a format.

---

## Costs and constraints

| Axis | Factors that often dominate | Attribution that is often too coarse |
|------|------------------------------|--------------------------------------|
| Processor time | Numeric parse and print; token scanning; UTF-8 handling; varint loops | Treating “we used JSON” as a single yes/no fact |
| Memory / allocations | Per-field objects; intermediate strings; map nodes | Blaming only the format family |
| Size / bandwidth | Repeated keys; decimal digits; optional whitespace | Assuming binary is always better on a high-speed local network |
| Latency tails | Garbage-collection pauses after allocation spikes | Looking only at mean encode time |
| Operability | Text logs versus the need for binary decoders | — |

---

## Illustrative scenarios

**Scenario A — numeric telemetry over a wide-area network.** An internal service returns large JSON arrays of floating-point measurements. A schemaless binary encoding reduces transfer size and can help distant clients. On a CPU-bound service on a local high-speed network, gains may stay modest if each request still **materializes thousands of small objects**. Object reuse or a code-generated schema codec may change performance more than substituting “binary” as a slogan.

**Scenario B — public HTTP API.** An organization may keep JSON for inspectability and interoperability, and still meet latency goals by adopting a more efficient JSON implementation, without changing the public contract.

---

## In this suite

Language **Results** pages and the [dashboard](../../dashboard/) report measured encode and decode behaviour for registered libraries (JSON family, schemaless binary, schema-driven, and language-native where present). Prefer comparisons **within one language** and, where possible, **within one family**. Cross-language “winners” are not interchangeable.

Methodology and metric definitions: [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md), [Metrics](../../analysis/METRICS.md). Quantitative statements in prose are illustrative; suite measurements are authoritative for this harness.

---

## Common errors of reasoning

- Concluding that “JSON is slow” without saying **which library** and **which payload**.
- Expecting a schemaless binary format that still carries string keys to match the density of a schema-dependent encoding.
- Changing only the codec while still allocating a new object graph on every request.
- Extrapolating from microbenchmarks on tiny messages to multi-megabyte documents (or the reverse).
- Comparing a fully warmed, code-generated path with a cold, reflective path and treating the result as a law of formats.

---

## Key takeaways

- Total cost includes parse and print work, metadata handling, allocations and copies, payload shape, and implementation quality.
- Distinctive costs of text formats often come from **structure discovery** and **decimal numeric conversion**, not from “using characters” in the abstract.
- Binary encodings remove some costs and introduce others (tags, variable-length integers, schema tooling).
- In managed languages, **allocation rate** is a first-class performance concern.
- Prefer paradigm-local, same-language evidence from **Results** over informal ranking articles.
- Format choice should reflect the full constraint set—debugging, evolution, multiple languages—not processor time alone.

---
