# Course Syllabus: Data Serialization

This course examines how computer systems represent structured in-memory data as linear sequences of bytes for storage, caching, and network interchange. It pairs conceptual models and primary specifications with empirical measurements from the accompanying multi-language benchmark suite.

## Prerequisites and Scope

The course assumes introductory familiarity with programming data structures (records, arrays, strings, references), hexadecimal notation, and basic operating-system concepts (processes, memory addresses, files, and sockets). No prior background in distributed systems or binary protocol design is required.

The curriculum separates **representation theory** (Parts I–IV below) from **benchmark methodology** (documented under [Benchmarks](../analysis/index.md)) and **live measurements** (published on the [Dashboard](../dashboard/index.html)).

## Curriculum Structure

| Part | Track | Focus | Prerequisites |
|---|---|---|---|
| **Part I** | [101: Foundations](101/index.md) | The four-layer serialization model, design axes, historical evolution, and domain lenses (data science and systems engineering) | None |
| **Part II** | [201: Mechanisms](201/index.md) | Memory layout, bit width vs. bus width, encode/decode cost centers, self-describing vs. schema-dependent encodings, schema evolution, zero-copy access, and compression | Part I |
| **Part III** | [301: Production Systems](301/index.md) | Architectural judgment under conflicting constraints: trust boundaries, untrusted input, schema registries, row vs. columnar scale, latency tails, and capstone case studies | Parts I–II |
| **Part IV** | [401: Codec Internals](401/index.md) | Byte-level Protocol Buffers wire format, runtime paths (Python, Rust, C), a hands-on subset codec lab (`MiniUser`), and source-level library comparisons | Parts I–II; reading fluency in Python, Rust, or C |

**Recommended reading order:** Follow Parts I → II → III for system design and format selection. Take Part IV after Part II if you implement, debug, or integrate codecs directly.

## Methodological Principles

Five rules govern how theory pages connect to measured numbers throughout the course:

1. **No format wins universally.** Every recommendation is conditional on stated constraints—trust boundary, payload shape, retention horizon, language estate, and latency budget.
2. **Separate standard from implementation.** A serialization *standard* defines what bytes mean; a *library* realizes that contract in one runtime. Implementation quality frequently outweighs format labels.
3. **Compare within a controlled cell.** Performance rankings on the [Dashboard](../dashboard/index.html) are valid within one **language**, one **standard**, one **data set**, and one **data type** ([Terminology](../analysis/terminology.md)). Cross-language absolute timings mix runtimes, allocators, and garbage collectors, and serve only as directional context.
4. **Separate performance from conformance.** Round-trip *fidelity* checks whether the benchmark sample survives encode and decode. Specification *conformance* is tested independently under [Compliance](../compliance/index.md) and the [Dashboard Compliance view](../dashboard/index.html#compliance).
5. **Prose numbers are illustrative.** Authoritative measurements for this suite's runners, software versions, and statistical policies live on the [Dashboard](../dashboard/index.html) at claim level **L1** ([Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)).

## Laboratory Notebooks and Teaching Schemas

Thirteen interactive Python notebooks accompany selected chapters and run locally or in Google Colab; see [Lab notebooks](notebooks/README.md) for installation instructions and the complete index.

Where byte-level examples appear in Part IV, chapters use a compact four-field teaching schema (`MiniUser`) rather than the larger benchmark schemas under `schemas/v2/`, keeping hexadecimal dumps small enough to trace by hand. Multi-language companion stubs for the Part IV encoder lab are provided in Go and Rust under `docs/theory/notebooks/companions/`.
