# 2.8 Compression vs. Format

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/compression_vs_format.ipynb)

## Problem Statement

When network bandwidth or object-storage bills grow, teams frequently enable a general-purpose compressor—such as **gzip**, **brotli**, or **zstd**—at the HTTP proxy or storage layer and conclude that the underlying serialization format no longer matters because compression eliminates size differences.

While layering compression over a verbose format is often pragmatic, treating compression as a substitute for format design conflates two orthogonal layers. General-purpose compression reduces byte-level statistical redundancy at the expense of CPU cycles and latency; it does not provide static types, schema evolution, column projection, or zero-copy field access.

---

## Separating the Two Layers

!!! note "Definition: Serialization vs. General-Purpose Compression"
    - **Serialization** maps typed application values into a structured, meaning-bearing byte representation (defining types, field identity, layout, and compatibility rules).
    - **General-purpose compression** (DEFLATE/gzip, zstd, LZ4, Brotli)[^1][^2] is a **semantics-agnostic** byte-to-byte transform that replaces repeated subsequences and skewed symbol frequencies with shorter codes without understanding record boundaries or schemas.

```text
  Application values
        │  [Serialization: defines schema, types, field layout]
        ▼
  Structured bytes  ──►  [Optional Compression: shrinks byte redundancy]  ──►  Network / Disk
```

Combining both layers (for example, `Content-Type: application/json` with `Content-Encoding: zstd`) is standard practice. The architectural mistake is collapsing them into a single decision.

### End-to-End Cost Model

Enabling compression shifts cost from network/disk I/O to CPU at both endpoints:

$$T_{\text{end-to-end}} = T_{\text{encode}} + T_{\text{compress}} + \frac{S_{\text{compressed}}}{B} + T_{\text{decompress}} + T_{\text{decode}}$$

where $S_{\text{compressed}}$ is compressed byte size and $B$ is effective link or storage bandwidth.

- **On slow WAN/mobile links or cold object storage** (low $B$), reducing $S$ dominates, so compression frequently lowers total latency and storage cost.
- **On high-speed datacenter links or loopback IPC** (high $B$) with small messages ($< 1\text{ KB}$), $T_{\text{compress}} + T_{\text{decompress}}$ routinely *exceeds* transmission savings—and framing headers can even make very small payloads slightly *larger*.
- Crucially, after decompression, the receiver still holds the original uncompressed representation (e.g., verbose JSON text) and must pay the full $T_{\text{decode}}$ parsing and allocation cost.

---

## Structure-Aware Density vs. Byte-Level Compression

Format-aware encodings eliminate redundancy *using knowledge of the data model* before a general-purpose compressor ever runs:

| Format-Aware Technique | Mechanism | Typical Format Examples |
|---|---|---|
| **Omit field names** | Replace repeated string keys with numeric tags or schema order | Protocol Buffers, Avro, SBE |
| **Variable-length integers** | Encode small integers in 1–2 bytes instead of fixed 8-byte words | Protocol Buffers varints, CBOR, MessagePack |
| **Enumerations / dictionary codes** | Map low-cardinality strings to small integers | Protobuf enums, Parquet dictionary pages |
| **Columnar grouping + delta/RLE** | Place homogeneous column values adjacently for domain-specific encoding | Parquet, ORC[^3] |
| **Sub-byte bit-packing** | Store bounded integers at exact bit width ([2.2 Bit width](bit-width-and-bus-width.md)) | Parquet RLE/bit-packing, FastLanes, ASN.1 PER |

Consider three repeated JSON Lines records:

```json
{"city":"Paris","temp_c":18.0,"unit":"C"}
{"city":"Lyon","temp_c":17.5,"unit":"C"}
{"city":"Lille","temp_c":16.0,"unit":"C"}
```

Because `"city"`, `"temp_c"`, and `,"unit":"C"}` repeat verbatim, `gzip` achieves a dramatic compression ratio on JSON—yet the decoder must still decompress and parse every character. On already-dense binary payloads (e.g., random IEEE 754 floats or tight Protocol Buffers streams), general-purpose compressors yield much smaller relative gains because less repetitive syntax remains.

### Security Considerations

Layering compression over untrusted input introduces two well-known failure modes:

1. **Decompression bombs:** A tiny compressed payload can expand to gigabytes of zeros or repeated tokens, exhausting memory unless strict limits on **decompressed byte length** are enforced during streaming decompression.
2. **Compression side channels (CRIME / BREACH):** Compressing attacker-influenced input alongside secrets (such as session cookies or tokens) inside an encrypted TLS stream leaks secret bytes via observable ciphertext length variations.[^4]

---

## Trade-Offs by Deployment Scenario

| Scenario | Practical Assessment |
|---|---|
| **Public REST API over WAN** | Keep JSON for partner ergonomics; apply gzip/brotli/zstd selectively above a minimum byte threshold (e.g., $\ge 1\text{ KB}$) while watching CPU and BREACH rules. |
| **High-QPS internal datacenter RPC** | Measure end-to-end latency before enabling compression; switching to a compact schema-driven binary format *without* compression often beats `gzip(JSON)` on both CPU and $p_{99}$ latency. |
| **Analytical data lake** | Gzipped JSON Lines forces full-file decompression and row parsing on every query; columnar Parquet with per-column encodings (Snappy/zstd pages) cuts both I/O and CPU by orders of magnitude. |

---

## Connection to the Benchmark Suite

Core Dashboard tables measure **uncompressed codec encode/decode cost and raw wire size** (except where a columnar library applies default page compression, such as `parquet` vs. `parquet-uncompressed`; see [Data sets](../../analysis/test_data_configuration.md)). To study compression trade-offs empirically across repeated text, numeric telemetry, and tiny flat records, see [Experiment 2: Does squeezing the bytes make JSON small enough?](../../experiments/index.md#2-does-squeezing-the-bytes-make-json-small-enough) and the [Dashboard](../../dashboard/index.html).

---

## Exercises

1. **Latency break-even calculation:** A datacenter link transfers payloads at $B = 1\text{ GB/s}$ ($1\text{ B/ns}$). A 2 KB JSON message compresses to 600 bytes with gzip (saving 1,400 bytes), but gzip compress + decompress adds $25\,\mu\text{s}$ of combined CPU time. Does enabling gzip *reduce* or *increase* single-message end-to-end latency on this link?

??? note "Solution"
    - Transfer time saved: $1\,400\text{ B} / (1\text{ B/ns}) = 1\,400\text{ ns} = 1.4\,\mu\text{s}$.
    - CPU time added: $25.0\,\mu\text{s}$.
    - Net effect: end-to-end latency **increases** by $23.6\,\mu\text{s}$. On a slow $1\text{ MB/s}$ mobile link, by contrast, saving 1,400 bytes saves $1\,400\,\mu\text{s}$ ($1.4\text{ ms}$), easily justifying $25\,\mu\text{s}$ of CPU work.

2. **Format vs. compression on analytics:** Suppose `gzip(JSONL)` and `Parquet` occupy the exact same disk size (10 GB) for a 100-column log table. Why will an analytical query selecting `SUM(revenue)` over one column still run far faster on Parquet?

??? note "Solution"
    To read `revenue` from `gzip(JSONL)`, the engine must read and decompress all 10 GB and parse all 100 JSON fields per row. In Parquet, column projection reads only the `revenue` column chunks (~1% of the file), decompresses only those pages, and processes contiguous binary numeric values directly without JSON tokenization or decimal float parsing.

3. **Hands-on check:** Run [Compression vs. format](../notebooks/201/compression_vs_format.ipynb) on *(a)* a single 60-byte status record and *(b)* a batch of 500 repeated JSON objects. Explain why compression behaves oppositely on the two workloads.

??? note "Solution"
    On a 60-byte record, compression headers and sliding-window overhead leave little or no redundancy to exploit (output may even exceed 60 bytes while adding CPU cost). Across 500 repeated JSON objects, repeated keys and structural punctuation compress heavily via LZ77 back-references and entropy coding.

---

## References

[^1]: Deutsch, P. (1996). *GZIP file format specification version 4.3*. IETF RFC 1952. <https://www.rfc-editor.org/rfc/rfc1952>
[^2]: Collet, Y., & Kucherawy, M. (2021). *Zstandard Compression and the 'application/zstd' Media Type*. IETF RFC 8878. <https://www.rfc-editor.org/rfc/rfc8878>
[^3]: Apache Software Foundation. *Apache Parquet Encodings Specification*. <https://parquet.apache.org/docs/file-format/data-pages/encodings/>
[^4]: Gluck, Y., Harris, N., & Prado, A. (2013). *BREACH: Reviving the CRIME Attack*. Black Hat USA.
