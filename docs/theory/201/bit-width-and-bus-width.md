# 2.2 Bit Width Is Not Bus Width

## Problem Statement

Two distinct hardware facts are frequently conflated when designing binary formats:

1. **Hardware moves memory in wide transfers:** Modern server cache lines are 64 bytes (512 bits), on-chip memory buses and DMA engines transfer 4–64 bytes per beat, and SIMD registers operate on 128–512 bits simultaneously.
2. **Values often carry fewer than 8 bits of information:** A 12-bit sensor reading, a 4-bit quantized neural-network weight, or a 17-bit bounded identifier occupies strictly less entropy than standard 16-, 32-, or 64-bit scalar types.

Conflating these two facts leads to two opposite design errors: widening every serialized field to match a 64-byte bus width, or assuming sub-byte bit-packing yields free speedup without unpacking overhead.

---

## Separating the Three Widths

!!! note "Definition: Information, Addressable, and Transfer Widths"
    - **Information width** ($b_{\text{val}}$): The minimum number of bits required to represent a value's domain (e.g., $\lceil \log_2 1000 \rceil = 10$ bits for integers in $[0, 999]$).
    - **Addressable unit**: The 8-bit **byte** (*octet* in formal IETF/ISO specifications), which is the smallest unit a program directly addresses and exchanges across OS I/O interfaces.
    - **Transfer width**: The hardware granularity moved per operation—a 64-byte cache line, a DMA burst, a SIMD vector register, or a GPU memory transaction.

```text
  Information width  ──►  Packed or aligned into Bytes (octets)  ──►  Moved in Transfer-width chunks
  (e.g., 4b, 12b)         (format contract)                           (cache lines, DMA, SIMD)
```

A contiguous byte buffer already saturates wide hardware transfers. The memory controller fetches entire 64-byte cache lines and DMA copies contiguous regions regardless of whether logical fields inside that buffer are 1 byte, 4 bytes, or 12 bits wide. Buffer **start alignment** (for example, aligning a column buffer to 64 bytes as recommended by Apache Arrow) improves hardware load efficiency without abandoning the byte as the interchange unit.

---

## Sub-Byte Bit-Packing vs. Byte-Aligned Layouts

### Packing Narrow Values

Packing $N$ values of bit width $b_{\text{val}}$ tightly into contiguous bytes requires $\lceil N \cdot b_{\text{val}} / 8 \rceil$ bytes (excluding headers and alignment padding). For example, $N = 10^6$ readings of 12-bit sensor data occupy:

$$\text{Packed: } \frac{10^6 \times 12}{8} = 1.5\text{ MB} \qquad\text{vs.}\qquad \text{16-bit aligned: } 2.0\text{ MB} \qquad\text{vs.}\qquad \text{64-bit float: } 8.0\text{ MB}$$

Tight packing cuts storage and bandwidth by 25% relative to 16-bit integers (and 81% relative to 64-bit floats), at the cost of decode-time extraction: the CPU must shift and mask individual values back into addressable machine registers before arithmetic. Bit-order within a byte (LSB-first vs. MSB-first) also becomes part of the wire contract.

Two prominent real-world families illustrate sub-byte packing:

- **ASN.1 Unaligned PER (Packed Encoding Rules):** Encodes constrained integers in their exact minimum bit width across byte boundaries (e.g., an integer constrained to $0\text{–}999$ consumes 10 bits, not 16).[^1]
- **SIMD-friendly bit-packing (FastLanes / Parquet RLE–bit-packing):** Arranges blocks of e.g. 1,024 narrow integers in interleaved lanes so a single SIMD load fills a vector register and parallel bit-shifts unpack many values per cycle without cross-lane shuffles.[^2]

### Aligned Direct-Load Layouts

Conversely, aligned formats spend padding bytes so readers can execute direct native loads without bit extraction:

- **Cap'n Proto** organizes messages into 64-bit words with natural field alignment.
- **SBE (Simple Binary Encoding)** assigns fixed aligned offsets inside each record body (with variable-length data appended at the end).
- **Apache Arrow** recommends 64-byte alignment on columnar buffers so SIMD kernels can scan contiguous numeric columns directly.[^3]

| Design Axis | Aligned Byte Layout (Arrow, Cap'n Proto, SBE) | Sub-Byte Bit-Packing (Unaligned PER, FastLanes) |
|---|---|---|
| **CPU read cost** | Direct native load (when endianness and alignment match) | Shift-and-mask extraction or SIMD block unpack |
| **Wire / file size** | Larger due to type width rounding and alignment padding | Minimal bits per value (plus metadata/scales) |
| **Random field access** | $O(1)$ arithmetic offset | Often requires unpacking an enclosing bit-block |
| **Contract complexity** | Specify byte order and alignment | Also specify intra-byte bit order and block layout |

### Quantized Tensors: Stored Order vs. Compute Order

Low-precision machine-learning weights (4-bit or 8-bit quantized tensors) combine sub-byte packing with shared floating-point **scale** (and optional zero-point) multipliers per group of elements. Two distinct layouts arise:

- **Stored order:** Compact sequential layout optimized for file size and `mmap` loading.
- **Calculation order:** Tiled/interleaved micro-blocks required by specific CPU or GPU matrix-multiplication kernels.

A portable quantized format must declare element bit width, group size, scale placement, and stored layout; the CPU/GPU time spent repacking stored order into calculation order is part of the end-to-end load cost.

### Link-Layer Coding Sits Below Serialization

Physical links (PCIe, Ethernet, CXL) apply their own line coding (8b/10b, 64b/66b, 128b/130b) and group bytes into fixed-size **flits** for clock recovery and forward error correction. Those mechanisms belong strictly to the hardware link controller below the byte-buffer abstraction; application serializers never target physical flit widths directly.

---

## Connection to the Benchmark Suite

This suite's portable primitive catalog (`bool`, `int32`, `int64`, `float64`, `utf8_string`, and epoch-millisecond `int64` timestamps; see [Data sets](../../analysis/test_data_configuration.md)) measures byte-addressable codecs across `suite`, `columnar`, `graph`, `array`, and `tensor` data sets. It does not currently benchmark sub-byte bit-packed or quantized-error data types; exact round-trip `mean_fidelity` applies to lossless codecs, whereas quantized formats require bounded-error evaluation rather than bit-exact equality.

---

## Exercises

1. **Bit-packing arithmetic:** A telemetry stream logs $4 \times 10^6$ unsigned status codes restricted to the range $[0, 19]$. Compute the raw payload size (ignoring headers) when stored as *(a)* 32-bit integers, *(b)* 8-bit bytes, and *(c)* tightly bit-packed values.

??? note "Solution"
    Twenty distinct values ($0\text{–}19$) require $\lceil \log_2 20 \rceil = 5$ bits per value.
    - *(a)* 32-bit integers: $4 \times 10^6 \times 4 = 16\,000\,000\text{ B}$ ($16.0\text{ MB}$).
    - *(b)* 8-bit bytes: $4 \times 10^6 \times 1 = 4\,000\,000\text{ B}$ ($4.0\text{ MB}$).
    - *(c)* 5-bit packed: $4 \times 10^6 \times 5 / 8 = 2\,500\,000\text{ B}$ ($2.5\text{ MB}$, 37.5% smaller than 1 byte/value).

2. **Bus-width fallacy:** An engineer proposes padding every boolean field in an RPC message to 64 bytes so that each field matches the CPU's 64-byte cache line. Explain why this degrades performance instead of improving it.

??? note "Solution"
    Padding each boolean to 64 bytes increases memory footprint by 64× (or 512× vs. a 1-bit bitmap), causing 64× as many cache-line transfers over the memory bus and evicting useful working set from L1/L2 caches. Packing 64 contiguous 1-byte booleans (or 512 1-bit flags) into a *single* cache line transfers all of them in one hardware transaction.

3. **Exact fidelity vs. quantization:** Why is `mean_fidelity == 1.0` (exact round-trip equality) the wrong acceptance criterion for a 4-bit quantized weight serializer?

??? note "Solution"
    Quantization is deliberately lossy: mapping 32-bit floating-point weights to 4-bit integers plus a group scale discards precision. Correctness for a quantized codec must verify structural metadata integrity plus a bounded reconstruction error (e.g., max absolute error or cosine similarity) rather than bit-exact floating-point equality.

---

## References

[^1]: ITU-T. *Recommendation X.691: ASN.1 Encoding Rules — Specification of Packed Encoding Rules (PER)*.
[^2]: Afroozeh, A., & Boncz, P. (2023). "The FastLanes Compression Layout: Decoding > 100 Billion Integers per Second with Scalar Code." *Proceedings of the VLDB Endowment*, 16(9), 2132–2144.
[^3]: Apache Software Foundation. *Apache Arrow Columnar Format Specification (§ Buffer Alignment and Padding)*. <https://arrow.apache.org/docs/format/Columnar.html>
