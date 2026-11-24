# 2.3 Encode and Decode Cost

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/leo-gan/GLD.SerializerBenchmark/blob/master/docs/theory/notebooks/201/encode_decode_cost.ipynb)

## Problem Statement

Informal performance discussions frequently reduce serialization latency to a binary claim—for example, asserting that replacing JSON with any binary format yields an order-of-magnitude speedup. In practice, format migrations often disappoint or even regress when the dominant bottleneck lies outside text syntax.

Encoding and decoding latency is the sum of distinct computational stages rather than an intrinsic property of "text" or "binary" labels. To reason accurately about serializer performance, one must decompose total cost into four primary components:

$$T_{\text{total}} = T_{\text{scan}} + T_{\text{conv}} + T_{\text{alloc}} + T_{\text{copy}}$$

where $T_{\text{scan}}$ is structural scanning and dispatch, $T_{\text{conv}}$ is value conversion (such as decimal–binary radix conversion or varint bit-packing), $T_{\text{alloc}}$ is heap allocation and downstream garbage-collection work, and $T_{\text{copy}}$ is memory-bandwidth movement of payload bytes.

---

## Cost Decomposition

Both encode and decode traverse the same logical boundary in opposite directions:

```text
  In-memory values  ──►  Encode (traverse, convert, write buffer)  ──►  Byte sequence
  In-memory values  ◄──  Decode (scan, validate, convert, allocate) ◄── Byte sequence
```

Evaluating any serialization path begins with three quantitative questions: *(1)* how many passes over the input bytes are performed, *(2)* how many distinct heap allocations occur per record, and *(3)* how many values undergo non-trivial representation conversion?

### 1. Structural Scanning and Tokenization ($T_{\text{scan}}$)

Consider a small JSON record:

```json
{"id": 42, "temp_c": 21.5, "label": "sensor-7"}
```

Because JSON is delimiter-based UTF-8 text, a decoder must locate structural characters (`{`, `:`, `,`, `}`, `"`), track string-escape state (`\"`, `\uXXXX`), and validate UTF-8 sequences. Naive character-by-character parsers incur high branch-misprediction rates on structural tokens. Modern parsers such as `simdjson` mitigate this by processing 32- or 64-byte blocks with SIMD instructions to build structural bitmasks before value extraction.[^1]

Binary formats replace delimiter scanning with explicit **type tags**, **field numbers**, or **length prefixes**. While this eliminates escape scanning, decoders still execute tag dispatch loops, bounds checks, and—for variable-length integers (*varints*)—continuation-bit shifts and branches.

### 2. Value and Numeric Conversion ($T_{\text{conv}}$)

Processors perform arithmetic on fixed-width binary integers and IEEE 754 floating-point values, not decimal ASCII strings. Converting `"21.5"` to an IEEE 754 `double` on decode—and formatting a `double` back to shortest round-trip decimal digits on encode—can dominate CPU time on numeric-heavy workloads even with modern algorithms such as Eisel–Lemire parsing and Ryū formatting.[^2][^3]

| Representation of integer `42` | Wire bytes (conceptual) | Primary decode work |
|---|---|---|
| JSON text (`"id": 42`) | ASCII `'4'`, `'2'` plus key and delimiters | Token scan; decimal multiply-accumulate |
| Fixed 32-bit little-endian | `2a 00 00 00` | Single bounds-checked 4-byte load (plus byte swap on big-endian hosts) |
| Unsigned base-128 varint | `2a` | Continuation-bit test, shift, and mask loop |

Binary formats avoid decimal–binary conversion altogether, though varint and zigzag encodings trade fixed-width direct loads for compact wire length and per-byte bit manipulation.

### 3. Wire Metadata Overhead

Wire density affects both $T_{\text{scan}}$ and $T_{\text{copy}}$. Self-describing formats—whether text (JSON) or binary (MessagePack maps, CBOR maps)—repeat string field names in every record. Decoding a map requires hashing or comparing each key string to resolve the target slot. Schema-dependent formats (Protocol Buffers, Avro, positional structs) omit field names on the wire, replacing string matching with small integer tag dispatch or fixed field order ([Self-describing vs. schema-dependent](self-describing-vs-schema-dependent.md)).[^4]

### 4. Heap Allocation, Copying, and Garbage Collection ($T_{\text{alloc}}, T_{\text{copy}}$)

In garbage-collected runtimes (Python, Java, C#, JavaScript, Go), object creation frequently dominates pure parsing time. A conventional decode path allocates a container object per nested record, a string object per key and text value, and boxed numeric objects where the runtime lacks unboxed primitives. High allocation rates increase both immediate allocator latency and tail latency from subsequent garbage-collection pauses.

High-throughput codecs reduce $T_{\text{alloc}}$ and $T_{\text{copy}}$ through four techniques:

| Technique | Mechanism | Primary Benefit |
|---|---|---|
| **Typed positional targets** | Decode directly into fixed-slot structs or generated classes instead of hash maps | Eliminates map allocation and key hashing |
| **Buffer reuse / pooling** | Clear and reuse an output byte buffer across encode calls | Eliminates per-call buffer growth and reallocation |
| **Borrowed views / spans** | Expose slices referencing the input buffer directly (when unescaped) | Avoids copying string payloads onto the heap |
| **Zero-copy layouts** | Read aligned fields in place via relative offsets ([Zero-copy](zero-copy.md)) | Defers or avoids constructing an object graph altogether |

---

## Implementation Variance and Workload Sensitivity

Two factors routinely outweigh the choice between text and binary standards:

- **Payload shape and memory locality:** A flat record containing contiguous numeric arrays stresses memory bandwidth and numeric conversion, whereas a deeply nested tree of short strings and small maps stresses allocator throughput and causes CPU cache misses across pointer-linked heap objects.
- **Implementation architecture:** A format label spans orders of magnitude in engineering effort. A SIMD-accelerated, compiled JSON library (`orjson`, `simdjson`, `yyjson`) frequently outperforms a reflection-based or interpreted binary serializer on the same hardware. Compile-time code generation eliminates runtime type inspection and dynamic dispatch; reflection discovers field layouts repeatedly at run time.

| Cost Axis | Dominant Driver | Common Misattribution |
|---|---|---|
| **CPU time** | Radix conversion, token scanning, varint loops, runtime reflection | Treating "JSON" or "binary" as a single performance tier |
| **Memory & tail latency** | Per-field object allocations, map entries, intermediate `String` buffers | Evaluating only mean encode throughput while ignoring GC pressure |
| **Wire bandwidth** | Repeated string keys, decimal expansion, uncompacted whitespace | Assuming smaller raw payloads automatically reduce latency on fast local networks |

---

## Connection to the Benchmark Suite

The [Dashboard](../../dashboard/index.html) reports serialize latency, decode latency, combined throughput, and encoded byte size across five data sets specifically shaped to isolate these cost centers (`message` for flat overhead, `document` for nested trees, `telemetry` for numeric arrays, `strings` for text allocation, and `event` for log envelopes; see [Suite](../../analysis/suite.md)).

To separate implementation cost from format cost, filter the Dashboard to one **language**, one **standard**, one **data set**, and one **data type**. Methodology and statistical cleaning rules are defined in [Analysis methodology](../../analysis/ANALYSIS_METHODOLOGY.md).

---

## Exercises

1. **Bottleneck attribution:** A Python service switches an internal endpoint from `orjson` (encoding dictionaries) to pure-Python `msgpack` (also encoding dictionaries) and observes *higher* latency despite a 28% smaller payload. Using the decomposition $T_{\text{total}} = T_{\text{scan}} + T_{\text{conv}} + T_{\text{alloc}} + T_{\text{copy}}$, explain how this can occur.

??? note "Solution"
    Because both paths still encode and decode untyped Python dictionaries, $T_{\text{alloc}}$ (allocating `dict` containers and hashing string keys on decode) remains high in both cases. Meanwhile, `orjson` executes $T_{\text{scan}}$ and $T_{\text{conv}}$ inside a compiled Rust extension, whereas a slower implementation increases $T_{\text{scan}}$ and interpreter overhead by more than the modest reduction in $T_{\text{copy}}$ from 28% fewer bytes.

2. **Encode vs. decode asymmetry:** Why can a fast JSON encoder (`orjson` writing 448 bytes) finish *encoding* faster than a typed MessagePack encoder writing 129 bytes, yet lose substantially on *decode*? (Compare with the source-level walkthrough in [Python: msgspec-msgpack vs. orjson](../401/python-msgspec-vs-orjson.md).)

??? note "Solution"
    On encode, writing UTF-8 bytes sequentially into a single contiguous buffer from existing dictionary keys is largely memory-bandwidth bound with low per-field dispatch overhead. On decode, an untyped JSON parser must scan 448 bytes, allocate nested hash tables, and intern/hash every string key, whereas a typed positional MessagePack decoder fills fixed C struct slots directly without allocating dictionaries or hashing keys.

3. **Hands-on measurement:** Run the companion notebook [Encode/decode cost](../notebooks/201/encode_decode_cost.ipynb) on *(a)* a flat numeric array and *(b)* a deeply nested map of short strings. Record which payload shows the larger relative speedup between text JSON and binary encoding, and explain why.

??? note "Solution"
    The flat numeric array typically shows the larger relative speedup because decimal–binary floating-point conversion ($T_{\text{conv}}$) and digit expansion dominate JSON time, whereas binary formats write raw IEEE 754 words directly. On a deeply nested map of short strings, per-object heap allocation ($T_{\text{alloc}}$) dominates both codecs, narrowing the relative gap.

---

## References

[^1]: Langdale, G., & Lemire, D. (2019). "Parsing Gigabytes of JSON per Second." *The VLDB Journal*, 28(6), 941–960. <https://doi.org/10.1007/s00778-019-00578-5>
[^2]: Lemire, D. (2021). "Number Parsing at a Gigabyte per Second." *Software: Practice and Experience*, 51(8), 1700–1727. <https://doi.org/10.1002/spe.2984>
[^3]: Adams, U. (2018). "Ryū: Fast Float-to-String Conversion." *Proceedings of the 39th ACM SIGPLAN Conference on Programming Language Design and Implementation (PLDI '18)*, 270–282.
[^4]: Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4. O'Reilly Media.
