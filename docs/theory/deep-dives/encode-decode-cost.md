# Where encode/decode time actually goes

> After this page you can name the real cost centers of serialization—and avoid the myth that “JSON is always slow” or “binary is always fast.”

---

## Problem

Benchmarks and blog posts often crown a format winner from a single chart: “switch to binary and save 10×.” Teams then ship a new codec and see little change—or a regression—because the bottleneck was never “text versus binary” in the abstract. It was **tokenization**, **number conversion**, **allocations**, **copies**, or **payload shape**.

---

## Short answer

Encode/decode cost is a sum of several mechanisms. Text formats (especially JSON) pay for scanning UTF-8, finding tokens, unescaping strings, and parsing decimal numbers into binary floats/ints. Binary formats usually skip decimal text and often skip field *names*, but they still pay for length prefixes, tags or field numbers, validation, and building language objects. In managed runtimes, **allocation and GC pressure** frequently dominate “algorithmic” encode time. A highly optimized JSON library can beat a naïve binary stack; a dense, pointer-heavy payload punishes every codec.

---

## Mental model

```text
  Domain object / map
        │
        ▼
  ┌─────────────┐     CPU: walk graph, format values
  │   Encode    │ ──► buffer growth, copies out
  └─────────────┘
        │ bytes
        ▼
  ┌─────────────┐     CPU: scan/parse, validate
  │   Decode    │ ──► allocate objects, fill fields
  └─────────────┘
        │
        ▼
  Domain object / map
```

Ask of any hot path: **How many times do we touch each byte? How many objects do we allocate? How many times do we convert between text and binary numbers?**

---

## How it works

### Text parsing and printing

JSON/XML-style codecs must:

1. **Discover structure** — braces, commas, quotes (branchy, hard to vectorize in simple parsers).
2. **Handle strings** — UTF-8 validation (policy varies), escape sequences.
3. **Parse numbers** — decimal text → binary int/float (non-trivial; a major share of JSON time on numeric payloads).
4. **Print on the way out** — binary numbers → decimal text; escape strings.

Binary formats typically store integers in a fixed width or a compact varint encoding and avoid decimal conversion.

### Self-describing metadata on the wire

Schemaless binary (MessagePack, CBOR, …) still carries **type tags** and often **field names** as strings. You save text punctuation and decimal numbers, but you do not get Protobuf-level density “for free.” Schema-driven codecs push names to a shared schema and leave **field numbers** or offsets on the wire—less metadata per message, more contract up front. Details: [Self-describing vs schema-dependent](self-describing-vs-schema-dependent.md).

### Allocations and copies

Classic path: bytes → **new** strings, maps, lists, DTOs. Faster path: reuse buffers, decode into preallocated structs, or use span/view APIs. “Faster serializer” in C#, Java, Python, JS, and Go often means **fewer allocations**, not only fewer instructions in the encode loop.

### Payload shape

Deep object graphs with many small strings stress pointer chasing and allocator traffic. Wide flat records with large blobs stress memcpy bandwidth. **Shape can matter as much as codec brand.** The suite uses controlled fixtures so comparisons stay meaningful within a language—see [Test data](../../analysis/test_data_configuration.md).

### Implementation quality

The label “JSON” covers both a textbook recursive parser and SIMD-oriented libraries. The label “Protobuf” covers reflection-based and fully generated paths. Always compare **implementations** in the same language and paradigm.

---

## Costs & constraints

| Axis | What often dominates | What people over-blame |
|------|----------------------|-------------------------|
| CPU | Number parse/print; token scan; UTF-8; varint loops | “We used JSON” as a single boolean |
| Memory / allocations | Per-field objects; intermediate strings; map nodes | Format family alone |
| Size / bandwidth | Repeated keys; decimal digits; whitespace | Assuming binary always wins after one hop on a LAN |
| Latency tails | GC pauses from allocation spikes | Mean encode time only |
| Operability | Cheap logging of text vs need for decoders | — |

---

## Real-world example

An internal API returns large JSON arrays of telemetry points (many floating-point fields). Switching to a schemaless binary format shrinks payloads and helps WAN clients, but a CPU-bound service on a local network sees modest gains because **building thousands of small objects per request** still dominates. Introducing object reuse or a code-generated schema codec changes the curve more than “binary” as a slogan. Conversely, a public edge API may stay on JSON for debuggability and still meet SLOs with a faster JSON implementation.

---

## In this suite

Language **Results** pages and the [dashboard](../../dashboard/) report measured encode/decode behavior for registered libraries (JSON family, schemaless binary, schema-driven, and language-native where present). Use them to compare **within one language** and preferably **within one family**. Cross-language “winners” are not interchangeable.

Methodology and metric definitions: [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md), [Metrics](../../analysis/METRICS.md). Treat any single blog-style number in prose as orientation only.

---

## Common mistakes

- Concluding “JSON is slow” without naming **which library** and **which payload**.
- Expecting MessagePack to match Protobuf density while still shipping field names on every message.
- Optimizing codec choice while allocating a new DTO graph on every request.
- Microbenchmarking tiny messages and predicting behavior on multi-megabyte documents (or the reverse).
- Comparing a fully warmed generated Protobuf path to a cold reflective JSON path and calling it a format law.

---

## Key takeaways

- Cost = parse/print work + metadata handling + allocations/copies + shape effects + implementation quality.
- Text’s distinctive tax is often **structure discovery and decimal numbers**, not “characters” in the abstract.
- Binary removes some taxes and introduces others (tags, varints, schema tooling).
- In managed languages, **allocation rate** is a first-class performance metric.
- Prefer paradigm-local, same-language evidence from **Results** over format folklore.
- Choose formats for the whole product constraint set (debug, evolution, polyglot)—not CPU alone.

---
