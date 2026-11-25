# Serialization 401: Codec Internals

Part IV is an implementer elective. Whereas [Part III (301)](../301/index.md) governs architectural selection under conflicting production constraints, Part IV descends to **wire bytes, parser loops, code generation, memory ownership, and source-level library call sites**.

**Prerequisites:** [Part I (101)](../101/index.md), [Part II (201)](../201/index.md), and reading fluency in Python, Rust, or C. [Part III (301)](../301/index.md) is recommended for trust-boundary and measurement discipline.

---

## Part A: Protocol Buffers Wire Format and Runtimes

Part A studies one schema-driven binary standard—**Protocol Buffers** (see [Compliance catalog](../../compliance/index.md) for other standards)—from raw hexadecimal wire layout through three contrasting runtime architectures and a hands-on subset codec lab.

Teaching examples in Part A use a compact four-field schema (`MiniUser`) rather than the suite's larger `schemas/v2/protobuf/benchmark_v2.proto`, keeping hexadecimal traces short enough to verify by hand.

| Chapter | Topic | Core Focus | Companion Lab |
|---|---|---|---|
| [4.1 Protocol Buffers wire format](protobuf-wire-format.md) | Tags, base-128 varints, LEN frames, nesting, repeated fields | Reading and writing proto3 binary bytes by hand; safe unknown-field skipping | [Playground](../notebooks/401/wire_format_playground.ipynb) |
| [4.2 Lab: MiniUser subset codec](lab-mini-protobuf-encoder.md) | Hands-on encoder and decoder implementation | Passing golden vectors G1–G5, bounds checks, and official-parser cross-validation | [Encoder Lab](../notebooks/401/lab_mini_protobuf_encoder.ipynb) |
| [4.3 Python: `google.protobuf`](protobuf-python.md) | Codegen, `upb` vs. pure-Python backends, descriptors | Tracing `SerializeToString` / `ParseFromString`, merge semantics, and `bytes` ownership | — |
| [4.4 Rust: `prost`](protobuf-rust-prost.md) | Compile-time monomorphization via `prost-build` | Tracing `encoded_len`, `encode_raw`, and generated `merge_field` dispatch | — |
| [4.5 C: `protobuf-c`](protobuf-c-protobuf-c.md) | Descriptor-table interpreter and manual heap lifecycle | Tracing two-pass size/pack, scan/unpack, and `free_unpacked` discipline | — |
| [4.6 C: `nanopb` vs. `protobuf-c`](protobuf-c-nanopb-compare.md) | Heap-allocated trees vs. static embedded memory budgets | Contrasting dynamic allocation against compile-time `max_size`/`max_count` streams | — |
| [4.7 Cross-language fidelity](protobuf-cross-language-fidelity.md) | Interoperability matrices and canonical encoding | Separating logical equivalence, bit-identity, local round-trips, and spec compliance | — |

Multi-language homework companions for the `MiniUser` lab are available for [Go](../notebooks/companions/go/README.md) and [Rust](../notebooks/companions/rust/README.md); see [Lab notebooks](../notebooks/README.md) for setup instructions.

### Four Protocol Buffers Runtimes at a Glance

All four libraries emit and consume the same wire specification; they diverge in **runtime architecture and memory ownership**:

| Dimension | Python (`google.protobuf`) | Rust (`prost`) | C (`protobuf-c`) | C (`nanopb`) |
|---|---|---|---|---|
| **Schema representation** | Runtime descriptors + C `upb` (or pure-Python) backend | Monomorphized per-type code generated at compile time | Static `ProtobufCMessageDescriptor` tables walked by one interpreter | Compact field tables + compile-time size/count limits |
| **Encoded buffer ownership** | New immutable `bytes` (GC-managed) | Caller-owned `Vec<u8>` / `BufMut` | Caller-allocated `uint8_t[]` sized via `get_packed_size` | Caller static buffer or `pb_ostream_t` callback |
| **Decoded object ownership** | GC-managed `Message` instance | Owned Rust struct (`String`, `Vec`) | Heap tree requiring `*_free_unpacked` | Pre-allocated static/stack struct (zero heap in default mode) |
| **Failure reporting** | `DecodeError` exception | `Result<T, DecodeError>` | `NULL` return on unpack error | `false` return (including static-limit overflow) |

---

## Part B: Comparative Codec Case Studies

Part B opens the actual timed call sites in this repository on the `document` ($n = 1$) payload to isolate **five recurring engineering mechanisms** that determine real-world codec performance and benchmark validity. Each study quotes an illustrative L1 Dashboard snapshot alongside source-level analysis (see [Timing honesty](../../analysis/TIMING_HONESTY.md)).

| Chapter | Comparison | Engineering Mechanism Isolated |
|---|---|---|
| [4.8 Typed positional vs. dynamic maps](python-msgspec-vs-orjson.md) | Python `msgspec-msgpack` vs. `orjson` & `msgpack` | Positional typed struct slots eliminating key hashing and dict allocation on decode |
| [4.9 Direct fixed-width vs. generic visitor](rust-speedy-vs-bincode.md) | Rust `Speedy` vs. `Bincode` (Serde) | Direct fixed-width stores vs. generic visitor abstraction and varint branching |
| [4.10 Zero-copy layouts under materialization](rust-rkyv-vs-speedy.md) | Rust `rkyv` vs. `Speedy` | Why an archive layout loses when timed via owned `from_bytes` materialization instead of `access` |
| [4.11 Same wire bytes, three implementations](javascript-three-protobufs.md) | JS `google-protobuf`, `protobufjs`, `protobuf-es` | Pure implementation variance when all three libraries emit identical 155-byte Protobuf wire output |
| [4.12 Auditing parse-only and DOM adapters](cpp-simdjson-wrapper.md) | C++ `simdjson` wrapper vs. `Glaze` & `nlohmann` | Identifying asymmetric encode fallbacks and extra DOM-copy stages hidden behind a leaderboard label |

### Additional Language Call-Site Notes

Seventeen additional per-language call-site walkthroughs (covering C, C++, C#, Fortran, Go, Java, JavaScript, Kotlin, Mojo, PHP, Python, Rust, Swift, and Zig) are cataloged under **[Benchmarks → Call-site notes](../../analysis/call-sites/index.md)**.

---

## Course Rules and Further Reading

- **Wire format is shared; implementation and memory contracts vary.** Language tours are parallel architecture studies, not cross-language rankings.
- **Honest scope in the subset lab:** `MiniUser` intentionally omits packed repeated fields, ZigZag `sint`, maps, `oneof`, and production hardening; see [3.2 Untrusted input](../301/untrusted-input.md) for operational parser defense.
- **Authoritative live numbers:** Consult the [Dashboard](../../dashboard/index.html) and [Claims and replication](../../analysis/CLAIMS_AND_REPLICATION.md) rather than prose snapshots.
- **Suite schema reference:** `schemas/v2/protobuf/benchmark_v2.proto` (and [Adding a serializer](../../analysis/ADDING_A_SERIALIZER.md) for runner integration).
