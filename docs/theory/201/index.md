# Serialization 201: Mechanisms

Part II examines the low-level mechanisms that govern how data structures map to wire bytes and why serialization standards exhibit different size, latency, compatibility, and memory-access trade-offs.

**Prerequisites:** [Part I: Foundations (101)](../101/index.md). Methodological and fair-comparison rules are stated once in the [Course Syllabus](../index.md#methodological-principles).

---

## Chapters

Work through the chapters in numerical order on a first pass (`2.2` is optional background on sub-byte bit packing and hardware transfer widths):

| Chapter | Topic | Core Question | Companion Lab |
|---|---|---|---|
| [2.1 Memory layout](memory-layout.md) | Alignment, padding, endianness, object graphs | Why is an uninterpreted process memory dump not a portable interchange format? | — |
| [2.2 Bit width is not bus width](bit-width-and-bus-width.md) *(optional)* | Information width vs. byte addressability vs. bus/SIMD transfer width | How do bit-packed values, aligned layouts, and wide hardware transfers interact? | — |
| [2.3 Encode and decode cost](encode-decode-cost.md) | Scanning, radix conversion, metadata, allocations, locality | Where do encode and decode CPU cycles and heap allocations actually go? | [Lab](../notebooks/201/encode_decode_cost.ipynb) |
| [2.4 Self-describing vs. schema-dependent](self-describing-vs-schema-dependent.md) | Wire metadata vs. out-of-band contracts | Does field identity live inside every payload or in a shared external schema? | [Lab](../notebooks/201/self_describing_vs_schema.ipynb) |
| [2.5 Schema evolution](schema-evolution.md) | Backward/forward/full compatibility, field numbers, Avro resolution | How do schemas change safely while older and newer software run concurrently? | [Lab](../notebooks/201/schema_evolution.ipynb) |
| [2.6 Dynamic vs. IDL binary](dynamic-vs-idl-binary.md) | MessagePack/CBOR class vs. Protocol Buffers class | When does a binary format warrant an IDL and code generation? | [Lab](../notebooks/201/dynamic_vs_idl_binary.ipynb) |
| [2.7 Zero-copy layouts](zero-copy.md) | Relative offsets, vtables, in-place reads, verification | What does "no deserialization" actually skip, and what costs remain? | — |
| [2.8 Compression vs. format](compression-is-not-a-format.md) | Byte-level compression vs. structure-aware encoding | Why does enabling gzip or zstd not substitute for format design? | [Lab](../notebooks/201/compression_vs_format.ipynb) |

See [Lab notebooks](../notebooks/README.md) for local and Google Colab setup. Specification details for standards referenced in Part II are cataloged under [Compliance](../../compliance/index.md), and measured timings live on the [Dashboard](../../dashboard/index.html).

---

## Where to Go Next

- **Production architecture:** [Part III: Production Systems (301)](../301/index.md) — applying these mechanisms under conflicting security, contract, and latency constraints.
- **Codec implementation:** [Part IV: Codec Internals (401)](../401/index.md) — Protocol Buffers byte layout, language runtime walkthroughs, and a hands-on encoder/decoder lab.
