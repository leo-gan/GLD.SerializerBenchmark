# Timing Contract

This document defines the suite's **timing honesty contract**: precisely which computational work belongs inside timed `serialize` and `deserialize` calls, and which setup or conversion work must stay outside the clock. Runner lifecycle and scheduling live in [Benchmark architecture](architecture.md).

Comparisons are valid only when competing adapters on the same Dashboard slice time commensurate work. Historically, an early JavaScript `google-protobuf` adapter encoded bytes inside `prepare` and timed only a `Buffer` copy—an implementation defect rather than encoder performance. Every adapter in this repository is audited against the rules below.

## Timed vs. Untimed Boundaries

```text
  suite value
       │
       ▼
  prepare          [untimed]   compile schemas, bind codecs, convert suite value → library model, allocate buffers
       │
       ▼
  serialize        [TIMED]     encode library model → wire bytes
       │
       ▼
  deserialize      [TIMED]     decode wire bytes → library model
       │
       ▼
  to-domain        [untimed]   convert library model → suite value (when supported by runner)
       │
       ▼
  fidelity         [untimed]   verify semantic equality against expected suite value
```

| Stage | Frequency | Timed | Permitted Work | Prohibited Work |
|---|---|---|---|---|
| **prepare** | Once per cell | No | Schema loading/compilation, encoder/decoder instantiation, type binding, converting suite data to the library's native in-memory model (e.g., generated `Message`, DOM `Document`, `msgspec.Struct`, plain dict), reusable buffer allocation. | Generating output wire bytes or caching pre-encoded payloads. |
| **serialize** | Every repetition | **Yes** | Traversing the prepared in-memory value and emitting encoded bytes (or language-native equivalent). | Returning cached bytes from `prepare`; recompiling schemas or rebuilding encoders when reuse is supported. |
| **deserialize** | Every repetition | **Yes** | Parsing wire bytes and reconstructing the library's native in-memory value. | Substituting a different parser or bypassing decode. |

## Normative Rules

1. **Never cache wire output in `prepare`:** Timed `serialize` must perform actual encoding, not `memcpy`. Parse-only libraries (`simdjson`, `simd-json`) must time a documented companion JSON writer during `serialize` and disclose that split on the language page and in the row label where applicable.
2. **Never time one-time schema or reflection setup:** Schema parsing, `ClassCache` construction, `MakeGenericMethod`, and encoder instantiation belong in `prepare`.
3. **Keep domain–native mapping untimed when supported, and symmetric across paired audits:** Most runners map back to suite domain objects after timing (`to-domain`). Where one library operates directly on suite domain structs (`Protostuff`, `FlatBuffers` in Java/Kotlin/Swift), both adapters in a paired comparison must share the same end-to-end suite boundary (`suite → bytes → suite`).
4. **Match batch cardinality $N$:** A cell with `DataTypeInstanceCount = N` must encode and decode all $N$ instances (or one documented batch frame of $N$).
5. **Enforce stream honesty:** Stream rows must call a genuine stream API (`native` or `text_on_stream`) or be explicitly tagged `adapted`; label-only aliases of `bytes` must not be emitted ([I/O & run modes](modes.md#three-levels-of-stream-honesty)).
6. **Align row names with timed code:** Row labels must reflect what runs on the clock; any fallback encoder or envelope wrapper must be documented on the language page.
7. **Rule 8 — Columnar and SBE layout construction stays timed:** For `table`, `table_project`, `nested_table`, and `signal`, constructing an Arrow `RecordBatch`, Parquet/ORC columns, or SBE flyweight from suite rows is intrinsic to the format and stays inside timed `serialize` (schema objects and writer properties stay in `prepare`). On `table_project`, timed `deserialize` returns `f_float_0` only; row codecs that decode all columns before slicing keep that full decode on the clock.
8. **Rule 9 — Array and Tensor file/view rules:** For `grid` and `grid_window`, allocating host arrays stays in `prepare`; creating, writing, and reading the file or window are timed. `grid_window` must use native partial selection (HDF5 hyperslab, NetCDF `start`/`count`, ADIOS selection)—a full read plus host slice is invalid except where explicitly caveated (`gld-hdf5`). For `tensor_view`, timed `deserialize` must borrow from the encoded buffer without copying the 4 MiB matrix.

## Documented Contract Exceptions

| Exception | Rationale | Required Disclosure |
|---|---|---|
| Parse-only JSON libraries (`simdjson`, `simd-json`) | Upstream library ships no encoder. | Encode calls a named JSON writer on the clock; disclosed on language page and in [4.12 C++: `simdjson`](../theory/401/cpp-simdjson-wrapper.md). |
| Columnar / SBE conversion (Rule 8) | Row-to-column shredding or flyweight packing is core format cost. | Schema setup in `prepare`; layout conversion in `serialize`. |
| Teaching envelopes (C `ubj`, `flatcc`, `avro-c`) | Measures framing overhead around in-tree binary baseline. | Disclosed on [C overview](../c/index.md) and [C: `custom-binary` vs. `ubj`](call-sites/c-custom-binary-vs-ubj.md). |
| Eager materialization of zero-copy archives (`rkyv`) | Required for uniform round-trip fidelity verification. | Disclosed on [Rust overview](../rust/index.md) and [4.10 Rust: `rkyv` vs. `Speedy`](../theory/401/rust-rkyv-vs-speedy.md). |
| Symmetric suite-boundary pairs | Comparing a POJO codec (`Protostuff`) with a generated-message codec (`protobuf-java`). | Both adapters time `suite → bytes → suite`. |

## Adapter Review Checklist

Before publishing results for any new or modified adapter, verify four invariants:

1. `prepare` terminates before invoking any function that emits encoded bytes.
2. Timed `serialize` invokes the library's encode/write/marshal entry point (or documented stand-in).
3. Timed `deserialize` invokes the library's decode/parse/unmarshal entry point.
4. Any paired comparison in a [401 case study](../theory/401/index.md) or [call-site note](call-sites/index.md) uses matching boundaries on both sides (or documents the asymmetry explicitly).

## Audit Summary

### Course 401 Case Studies (`docs/theory/401/`)

| Case Study | Timed Work Audited | Status |
|---|---|---|
| [4.8 Python: `msgspec-msgpack` vs. `orjson`](../theory/401/python-msgspec-vs-orjson.md) | Typed `Struct` vs. `dict` JSON; domain conversion untimed on both | Honest (different layouts, same boundary) |
| [4.9 Rust: `Speedy` vs. `Bincode`](../theory/401/rust-speedy-vs-bincode.md) | Direct `Document` vs. `Serde` `Fixture` enum wrapper | Documented wrapper asymmetry |
| [4.10 Rust: `rkyv` vs. `Speedy`](../theory/401/rust-rkyv-vs-speedy.md) | Both materialize owned `Document`; `rkyv` does not time zero-copy `access` | Honest (eager decode disclosed) |
| [4.11 JavaScript: three Protobufs](../theory/401/javascript-three-protobufs.md) | All three encode in `serialize` and decode to native message; `toDomain` untimed | Honest |
| [4.12 C++: `simdjson` wrapper](../theory/401/cpp-simdjson-wrapper.md) | Encode is `nlohmann::json::dump`; decode is `simdjson` parse + DOM walk | Honest (encode stand-in disclosed) |

### Call-Site Reference Notes (`docs/analysis/call-sites/`)

| Call-Site Note | Timed Work Audited | Status |
|---|---|---|
| [C: `custom-binary` vs. `ubj`](call-sites/c-custom-binary-vs-ubj.md) | `ubj` encodes `custom-binary` plus UBJSON envelope | Honest (envelope disclosed) |
| [C#: `BinaryPack` vs. `MS Bond Fast`](call-sites/csharp-binarypack-vs-bond.md) | Both time native `bytes` encode/decode on domain POCOs | Honest |
| [C++: `Bitsery` vs. `YAS`](call-sites/cpp-bitsery-vs-yas.md) | Both serialize C++ domain structs | Honest |
| [Fortran: `json-fortran` vs. `rojff`](call-sites/fortran-json-fortran-vs-rojff.md) | Both time suite document ↔ compact JSON text | Honest |
| [Go: `kelindar/binary` vs. `hamba/avro`](call-sites/go-kelindar-vs-avro.md) | Both encode/decode Go domain structs | Honest |
| [Java: `Protostuff` vs. `protobuf-java`](call-sites/java-protostuff-vs-protobuf.md) | Both time suite `Document` → bytes → suite `Document` | Honest (symmetric suite boundary) |
| [JavaScript: `JSON.stringify` vs. `google-protobuf`](call-sites/javascript-json-vs-protobuf.md) | Both encode and decode on the clock (post-copy-bug fix) | Honest |
| [Kotlin: `FlatBuffers` vs. `protobuf`](call-sites/kotlin-flatbuffers-vs-protobuf.md) | Both time suite `Document` → bytes → suite `Document` | Honest (symmetric suite boundary) |
| [Kotlin: `kotlinx-json` vs. `Moshi`](call-sites/kotlin-kotlinx-json-vs-moshi.md) | Both encode/decode suite `Document` as named JSON | Honest |
| [Kotlin: `Protostuff` vs. `protobuf`](call-sites/kotlin-protostuff-vs-protobuf.md) | Both time suite `Document` → bytes → suite `Document` | Honest (symmetric suite boundary) |
| [Mojo: `EmberJson` vs. `mojo-avro`](call-sites/mojo-emberjson-vs-avro.md) | Both time suite `Document` (`serialize`/`deserialize` vs. `AvroDatum`) | Honest |
| [PHP: `json` vs. `protobuf`](call-sites/php-json-vs-protobuf.md) | Both time suite arrays ↔ bytes (`protobuf` maps message internally) | Honest (symmetric suite boundary) |
| [Python: `msgspec` JSON vs. MessagePack](call-sites/python-msgspec-json-vs-msgpack.md) | Same `msgspec.Struct`, two wire encoders | Honest |
| [Python: `orjson` vs. stdlib `json`](call-sites/python-orjson-vs-json.md) | Both dump/load prepared `dict` (stdlib note flags uncached `JSONEncoder`) | Honest (caveat disclosed) |
| [Rust: `Speedy` vs. `Postcard`](call-sites/rust-speedy-vs-postcard.md) | Direct `Document` vs. `Serde` `Fixture` enum wrapper | Documented wrapper asymmetry |
| [Swift: `FlatBuffers` vs. `SwiftProtobuf`](call-sites/swift-flatbuffers-vs-protobuf.md) | Both time suite `Document` → bytes → suite `Document` | Honest (symmetric suite boundary) |
| [Zig: `std.json` vs. `serde.json`](call-sites/zig-std-json-vs-serde-json.md) | Both time suite structs ↔ compact JSON into reused buffer | Honest |

### Standalone Adapter Audits & Open Contract Gaps

- **Audited schema rows:** Zig `protobuf`, `flatbuffers`, and `capnproto` (C++ bridge), C++ `capnproto`, and `dagr-*` across seven languages keep schema/native preparation outside the clock (except Mojo and Swift Dagr, where builder/arena conversion is disclosed as timed on their language pages).
- **Known remaining gaps (disclosed, not silent):**
  - **C `protobuf`:** Runs `to_proto` / `from_proto` inside timed calls because the C runner lacks a `prepare_many` hook for $N > 1$ (Rust `prost` uses untimed `prepare_many`).
  - **C `nanopb` / `protobuf-c` / `protobuf-wire`:** Share one in-tree `fixture_pb_v2.h` wire helper rather than linking full upstream codegen runtimes.
  - **C `avro-c` / `flatcc` / `ubj`:** Wrap `custom-binary` inside format envelopes.
  - **C# legacy XML/JSON constructors:** `DataContract` and `XmlSerializer` perform lazy initialization on repetition 0 (excluded by warmup).

## Related Pages

- [Benchmark architecture](architecture.md#measurement-model) · [Adding a serializer](ADDING_A_SERIALIZER.md#timing-honesty) · [I/O & run modes](modes.md) · [Call-site notes](call-sites/index.md)
