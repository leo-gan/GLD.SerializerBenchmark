# Encode/decode cost

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/encode_decode_cost.ipynb)
**Lab notebook:** [Encode/decode cost playground](../notebooks/201/encode_decode_cost.ipynb)


## Problem

It is easy to look at one performance chart and declare a format the winner. For example, someone might claim that switching from text to binary will make encoding ten times faster. Teams often make that switch and see almost no improvement. Sometimes results even get worse. The reason is that the real bottleneck is rarely the abstract idea of text versus binary.

Encoding and decoding costs come from several separate steps. The main cost centers are usually these:

- **Tokenization** — finding structure in the bytes.
- **Numeric conversion** — turning digit text into machine numbers, or the reverse.
- **Memory allocation** — creating objects in the language runtime.
- **Copying** — moving bytes from one buffer to another.
- **Payload shape** — how nested or scattered the data is.

In this section we separate those cost centers so you can reason about them one by one.

---

## Short answer

The cost of encoding and decoding is the sum of several mechanisms. It is not one magic property of “text” or “binary.”

Text formats such as JSON spend work on several tasks. They scan character encodings such as UTF-8. They recognize structural tokens. They unescape strings. They also convert **decimal digit sequences** into the binary integer and floating-point forms the processor actually uses. Binary formats usually avoid decimal text. They often omit repeated field *names*. Yet they still pay for length prefixes, type tags or field numbers, validation, and construction of language-level objects.

In managed runtimes, **allocation rate and garbage collection** often dominate. Garbage collection (GC) is automatic reclamation of unused memory. That work can cost more time than the encode or decode routine itself. A carefully engineered JSON implementation may outperform an inefficient binary stack. A payload made of many small, pointer-linked objects stresses every codec.

This matters because format choice alone rarely explains performance. Implementation quality and data shape often matter as much or more.

---

## Mental model

Think of encode and decode as two opposite pipelines. They convert between in-memory values and a sequence of bytes:

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

As **text**, this is a sequence of characters. Those characters are commonly stored as UTF-8 bytes. The processor does not “natively” understand braces or the decimal notation `21.5`. A JSON decoder must, among other steps:

1. **Discover structure.** Locate `{`, `:`, `,`, `}`, and string delimiters. Simple parsers do this with many conditional branches. Highly optimized parsers may use SIMD instructions. SIMD means single instruction, multiple data. Such instructions apply the same operation to several pieces of data at once. The logical task remains structure discovery either way.
2. **Interpret strings.** Read the bytes between quotes. Apply escape rules, for example `\n`. Often allocate a string object in the language runtime.
3. **Interpret numbers.** Read the characters `2`, `1`, `.`, `5`. Compute the binary floating-point value the CPU will use in arithmetic. That conversion is non-trivial. It can dominate runtime on numeric-heavy payloads.
4. **On encode (printing).** Convert binary integers and floats back into decimal digit characters. Escape strings. Emit punctuation.

**Worked contrast for one integer.** The logical value forty-two may appear in several forms:

| Representation | Illustrative bytes (concept) | Work to obtain a machine integer |
|----------------|------------------------------|----------------------------------|
| JSON text `"id": 42` | characters `4` and `2`, plus surrounding structure | Scan the digits, then multiply and accumulate to form 42 |
| Fixed 32-bit little-endian binary | four bytes, for example `2a 00 00 00` | Load four bytes with a known byte order |
| Compact binary “varint” (sketch) | one or more bytes encoding small integers densely | Loop over continuation bits, then shift and combine |

No row is universally “best.” The table only makes visible **where processor time goes**.

### Metadata that travels with the message

Even without human-oriented punctuation, many binary formats still carry **descriptive metadata**. Metadata is extra information that helps a reader interpret the values:

- **Type tags** — for example “the next value is a 32-bit integer,” or “the next value is a UTF-8 string of length *n*.”
- **Field names** — string keys such as `"temp_c"` repeated for every record. This is common in MessagePack maps and in JSON.

Schema-dependent formats such as Protocol Buffers typically replace names on the wire with **small field numbers**. Those numbers are defined in a shared **schema**. A schema is a formal description of messages and field types. That choice reduces per-message metadata. The cost is a contract outside the message itself (for example in a separate schema file). See [Self-describing vs schema](self-describing-vs-schema-dependent.md).

### Memory allocation and copying

A common decode path in managed languages looks like this. Managed languages include Python, Java, C#, JavaScript, and similar environments:

```text
  byte buffer
      → allocate a map or object
      → for each field: allocate a string key and/or value object
      → return a fully populated graph
```

Each allocation has a direct cost. Each allocation also contributes to later **garbage collection** work. That work can increase latency variability. **Tail latency** is the slowest requests, not just the average. Alternative designs reduce that cost:

- decode into a preallocated structure;
- reuse buffers across requests;
- expose **views** into the existing byte buffer (related to [zero-copy layouts](zero-copy.md)).

In practice, “a faster serializer” in managed languages often means **fewer allocations**. It does not merely mean fewer arithmetic instructions inside the encode loop.

### Payload shape

The shape of the data also matters a great deal. Two messages with the same logical “size in fields” can behave very differently:

| Shape (illustrative) | Characteristic cost |
|----------------------|---------------------|
| One flat record: a few large integers and one large binary blob | Fewer objects; more bulk memory-copy bandwidth |
| A deep tree: hundreds of small nested objects and short strings | Many allocations; poor locality (scattered memory access) |

**Shape can matter as much as the choice of format family.** Nested structures and many small objects cost more to encode than simple flat records. This suite uses controlled fixtures so comparisons stay interpretable within a language. See [Test Data](../../analysis/test_data_configuration.md).

### Implementation quality

The label “JSON” covers both pedagogical recursive parsers and highly optimized libraries. The label “Protocol Buffers” covers both reflection-based paths and fully code-generated paths. Reflection means the program discovers field structure at runtime. Code generation means the structure is known at compile time. Comparisons should fix **language**, **implementation**, and **payload**. Do not compare only the marketing name of a format.

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

**Scenario A — numeric telemetry over a wide-area network.** An internal service returns large JSON arrays of floating-point measurements. A schemaless binary encoding reduces transfer size. It can also help distant clients. On a CPU-bound service on a local high-speed network, gains may stay modest. That happens when each request still **builds thousands of small language objects in memory**. Object reuse or a code-generated schema codec may change performance more than substituting “binary” as a slogan.

**Scenario B — public HTTP API.** An organization may keep JSON for inspectability and interoperability. It can still meet latency goals by adopting a more efficient JSON implementation. That approach does not change the public contract.

---

## In this suite

Language **Results** pages and the [dashboard](../../dashboard/) report measured encode and decode behaviour for registered libraries. Those libraries cover the JSON family, schemaless binary, schema-driven, and language-native codecs where present. Prefer comparisons **within one language**. Where possible, also stay **within one family**. Cross-language “winners” are not interchangeable.

Methodology and metric definitions appear in [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md) and [Metrics](../../analysis/METRICS.md). Quantitative statements in prose are illustrative. Suite measurements are authoritative for this benchmark runner.

---

## Common errors of reasoning

- Concluding that “JSON is slow” without saying **which library** and **which payload**.
- Expecting a schemaless binary format that still carries string keys to match the density of a schema-dependent encoding.
- Changing only the codec while still allocating a new object graph on every request.
- Extrapolating from microbenchmarks on tiny messages to multi-megabyte documents, or the reverse.
- Comparing a fully warmed, code-generated path with a cold, reflective path and treating the result as a law of formats.

---

## Key takeaways

- Total cost includes parse and print work, metadata handling, allocations and copies, payload shape, and implementation quality.
- Distinctive costs of text formats often come from **structure discovery** and **decimal numeric conversion**. They do not come from “using characters” in the abstract.
- Binary encodings remove some costs and introduce others. Tags, variable-length integers, and schema tooling are examples.
- In managed languages, **allocation rate** is a first-class performance concern.
- Prefer paradigm-local, same-language evidence from **Results** over informal ranking articles.
- Format choice should reflect the full constraint set. Debugging, evolution, and multiple languages matter, not processor time alone.

---
