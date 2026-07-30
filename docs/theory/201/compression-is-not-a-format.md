# Compression vs format

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/compression_vs_format.ipynb)
**Lab notebook:** [Compression vs format lab](../notebooks/201/compression_vs_format.ipynb)


## Problem

When bandwidth or storage is expensive, a common sequence of decisions is:

1. Payloads are observed to be large.
2. A general-purpose compressor is enabled on the HTTP connection or on stored files. **gzip**, **brotli**, and **zstd** are common choices.
3. The organization concludes that the serialization format “no longer matters” because compression “repairs” size.

That conclusion is sometimes operationally adequate. More often it hides **processor cost**, **latency effects**, and **forgone structure-aware savings**. It can also create the incorrect impression that an inefficient encoding is free of consequence.

In this section we separate two different mechanisms. One is choosing how values become bytes. The other is optionally shrinking those bytes after the fact.

---

## Short answer

**Serialization** defines *which bytes* represent which values. Types, field identity, and layout are part of that definition. **Compression** is a largely **semantics-agnostic** transform. It exploits redundancy in a byte sequence without understanding the fields.

Compression can shrink verbose encodings substantially. JSON with repeated keys is a common example. Compression also consumes processor time. It can increase latency on small messages. It does not provide schema evolution, type safety, or zero-copy field access. Format-aware techniques remove redundancy **using knowledge of the data model**. Variable-length integers, dictionary encoding, columnar layouts, and omission of field names are examples.

Prefer first to select a format suited to the contract and access pattern. **Then** apply compression when the network or storage tier still needs it and measurement supports the trade-off.

In other words: compression can make a large encoding smaller. It cannot replace a good contract, and it is not free.

---

## Mental model

```text
  Application values
        │
        ▼
  Serialization format  ──►  structured byte sequence
        │                     (meaning defined by the format)
        ▼
  Optional compression  ──►  opaque, typically smaller blob
        │                     (compressor does not interpret fields)
        ▼
  Network or storage
```

Layering is legitimate and common. For example, `Content-Type: application/json` with `Content-Encoding: gzip` is normal. Collapsing the two mechanisms into a single decision is the error.

---

## How it works

### What a general-purpose compressor does

Algorithms such as gzip, brotli, and zstd search for repeated byte subsequences and other statistical redundancy. They operate on **arbitrary** bytes. They do not know that “bytes 12–15 constitute `user_id`.”

**Beginner illustration — why JSON often compresses well.**

Three logical records as JSON Lines:

```json
{"city":"Paris","temp_c":18.0,"unit":"C"}
{"city":"Lyon","temp_c":17.5,"unit":"C"}
{"city":"Lille","temp_c":16.0,"unit":"C"}
```

The substrings `"city"`, `"temp_c"`, `"unit"`, and `","unit":"C"}` recur. A compressor can replace repeated sequences with shorter references. After decompression, the receiver again holds the original JSON text and must still **parse** it.

**Dense binary with little repetition** may shrink only modestly. There is less redundancy left to exploit. **Very small messages** may grow slightly because of format headers and dictionaries. They may also fail to justify the processor cost of compression and decompression.

### Format-aware density (without a second codec stage)

Examples of structure reducing size **using knowledge of the model**:

| Technique | Idea | Example context |
|-----------|------|-----------------|
| Omit repeated field names | Names live in a schema, not in every record | Schema-dependent encodings |
| Variable-length integers | Small numbers use fewer bytes than fixed 64-bit fields | Many RPC (remote procedure call) binary formats |
| Enumerations | Store a small integer instead of a long string label | Status codes, units |
| Columnar layout | Store one column contiguously; encode and compress per column | Parquet, ORC ([data science perspective](../101/data_science_perspective.md)) |
| Domain encoding | Differences of timestamps; dictionary codes for categories | Analytics and telemetry |

These representations remain **interpretable under format rules**. A gzip bitstream alone is not a data schema.

### Worked size intuition (order-of-magnitude, not a benchmark)

Consider *N* identical logical records, each with the same three field names. Numbers in this table are teaching intuition only. Suite **Results** own benchmark-runner truth for measured codecs.

| Approach | What is repeated *N* times | Typical implication |
|----------|----------------------------|---------------------|
| Uncompressed JSON | Field names and punctuation every record | Large; excellent input for a compressor |
| JSON + gzip | Names still present before compression | Transfer size may fall sharply; CPU cost rises |
| Schema-dependent binary | Field numbers, not Unicode names | Often small before any compressor |
| Schema-dependent binary + light compression | Remaining redundancy only | Diminishing returns if already dense |

Exact ratios depend on data and implementations. The table clarifies **which mechanism** removes which redundancy.

### Processor time and latency

Compression shifts cost from **bandwidth** to **processor time** at both ends. On loopback interfaces or high-speed datacenter links, compressing small remote-procedure-call messages can **increase** end-to-end latency. On constrained mobile or long-haul links, the same trade-off may improve user-visible performance. Measure the full path:

```text
  encode → compress → transfer → decompress → decode
```

### Security and framing

Compressed untrusted data has a history of **decompression bombs**. Those are small inputs that expand to enormous outputs. Limits on decoded size matter whether the outer wrapper is HTTP or a custom stream. Compression also interacts with encryption. Classical lessons such as CRIME/BREACH concern secrets adjacent to attacker-controlled plaintext under compression. Written security assumptions for transport security (who is allowed to send data, and what they can control) must be considered explicitly when enabling compression.

---

## Costs and constraints

| Axis | Compression applied to a verbose format | Denser format (with optional light compression) |
|------|------------------------------------------|--------------------------------------------------|
| Size | Often large reductions on JSON-like data | Competitive; less trivial redundancy left |
| Processor time | Extra work on every message | More work in encode/decode; less in compress |
| Latency | Can harm small, frequent messages; can help large transfers on slow links | Depends on the codec; no universal rule |
| Random access | Often requires decompressing a stream or block first | Some formats permit field- or column-level access |
| Evolution / types | Unchanged by gzip | Still defined by the format and contract |
| Operability | Convenient proxy configuration | Requires format expertise |

---

## Illustrative scenarios

**A. Public API.** JSON is retained for partners. Enabling gzip at the edge reduces transfer size enough that a format migration can be deferred. That is appropriate **if** processor capacity is sufficient and payloads are large enough.

**B. Internal high-frequency path.** Multi-megabyte JSON arrays move between services on a high-speed local network with gzip enabled by default. Profiles show processors busy in deflate while network interfaces remain underutilized. A dense binary schema **without** compression may improve tail latency more than further gzip tuning. A cheaper algorithm applied only to larger batches is another option.

**C. Analytical lake.** Gzip-compressed JSON lines accumulate for a year. Query engines scan far more data than a Parquet layout with columnar encodings would require. Compression was applied, but **the format remained poorly matched to analytical access**.

---

## In this suite

The benchmark runner measures **serializer** behaviour. That means encode and decode of logical fixtures. It is not a full matrix of compress-wrapped transports. **Results** should not be read as “gzip is unnecessary” or “binary is mandatory.” Use them to select a codec family and implementation. Evaluate compression on the deployment path separately, or as an explicit follow-on experiment outside the core tables.

---

## Common errors of reasoning

- Treating `gzip(JSON)` as architecturally equivalent to a schema-driven binary protocol.
- Compressing tiny, high-frequency remote calls by default “for consistency.”
- Ignoring the combined processor budget of encryption, compression, and encoding.
- Expecting already-compressed media (images, video) to benefit from another general-purpose compression layer on the same bytes.
- Interpreting successful compression as permission to omit validation and evolution design.

---

## Key takeaways

- Serialization chooses a **meaning-bearing layout**. Compression exploits **byte-level redundancy**.
- Both can reduce size. Only the format defines types, evolution, and access patterns.
- JSON with gzip can be a valid edge strategy. It is not a universal architecture.
- Dense, schema-aware encodings remove redundancy that a compressor would otherwise re-discover. They often have better access properties as well.
- Account for **processor time and latency**, not only compressed size.
- Columnar and format-aware encoding for analytics differ from message codecs for remote procedure calls.
- Suite **Results** inform codec choice. Re-measure with compression on the actual wire if compression is part of the design.

---
