---
title: "Rust"
---

# Rust

Rust serialization centers on the `serde` derive ecosystem (`serde_json`, `bincode`, `postcard`, `bitcode`, `rmp-serde`, `ciborium`, `serde_avro_fast`, `sonic-rs`), complemented by direct-trait and zero-copy crates (`speedy`, `rkyv`, `minicbor`, `nanoserde`, `prost`, `dagr`, `sbe`, `gld-kiln`) and native `arrow-rs` columnar writers.

## Runtime & Environment

Rust compiles ahead of time to native machine code (`cargo build --release`) with compile-time ownership and deterministic stack/heap deallocation—no virtual machine and no garbage collector. Release optimizations are mandatory; unoptimized Debug builds are orders of magnitude slower and are never comparable to published Dashboard numbers. Code generation for `prost` runs at build time via `build.rs`. Language semantics are specified in [The Rust Reference](https://doc.rust-lang.org/reference/) (guide at [The Rust Book](https://doc.rust-lang.org/book/)).

| Property | Configuration |
|---|---|
| Language / spec | Rust 2021 edition ([The Rust Reference](https://doc.rust-lang.org/reference/)) |
| Build & toolchain | `rustc` / `cargo` (`cargo build --release`) |
| Memory model | Compile-time ownership; no garbage collector |
| Runner & logs | `rust/scripts/run-benchmarks.sh` → `logs/rust/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`rust/src/serializers/mod.rs`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/rust/src/serializers/mod.rs) |
| Data sets | `suite`, `columnar`, `graph`, `array`, `tensor` |

## Registered Serializers

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [arrow-ipc](https://docs.rs/arrow) | `arrow` | `columnar` | `adapted` | `arrow` 60.0.0 IPC stream; `RecordBatch` built in `serialize`; `table_project` passes `Some(vec![0])` |
| [bincode](https://github.com/bincode-org/bincode) | `custom` | `suite` | `adapted` | `bincode` 2 via `serde` (`Fixture` enum); config cached in `prepare` |
| [bitcode](https://github.com/SoftbearStudios/bitcode) | `custom` | `suite` | `adapted` | Bit-packed binary via `serde` |
| [bson](https://github.com/mongodb/bson-rust) | `bson` | `suite` | `adapted` | `bson` crate via `serde` |
| [ciborium](https://github.com/enarx/ciborium) | `cbor` | `suite` | `native` | `ciborium` CBOR via `serde` with reused write buffer |
| [ctoon](https://github.com/MohammadRaziei/ctoon) | `toon` | `suite` | `adapted` | Rust binding over C99 TOON core (`dumps` / `loads`); size in UTF-8 bytes |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Generated arena in `prepare`; timed arena serialize + lazy reader→domain |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct value structs in `prepare`; timed `write_into` + lazy reader→domain |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct value structs in `prepare`; timed `write_into` + lazy reader→domain |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Generated arena in `prepare`; timed arena serialize + lazy reader→domain |
| [flexbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite` | `adapted` | Schemaless FlexBuffers via `serde` |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | `fory` crate (`ForyStruct` derive, native mode) with reused output buffer |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-rust) | `kiln` | `suite`, `tensor` | `adapted` | `gld-kiln` 0.2.0 `encode_into` reused buffer; `tensor_view` borrows payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `array`, `tensor` | `adapted` | Pure x86-64 Assembly Kiln v2 C-ABI (`libkiln_asm_bench.a`); `table_project` uses `KILN_OPT_EMBEDDED` O(1) column skip; `tensor_view` borrows payload |
| [hdf5-metno](https://github.com/metno/hdf5-rust) | `hdf5` | `array` | `adapted` | `hdf5-metno` bindings to `libhdf5`; hyperslab read for `grid_window` |
| [ion-rs](https://github.com/amazon-ion/ion-rust) | `ion` | `suite` | `adapted` | Official `ion-rs` (`experimental-serde` `to_binary` / `from_ion`) |
| [minicbor](https://github.com/twittner/minicbor) | `cbor` | `suite` | `adapted` | Direct `Encode` / `Decode` traits on structs (no `serde`) |
| [nanoserde](https://github.com/not-fl3/nanoserde) | `custom` | `suite` | `adapted` | Zero-dependency `SerBin` / `DeBin` traits |
| [parquet](https://docs.rs/parquet) | `parquet` | `columnar` | `adapted` | `parquet` 60.0.0 `ArrowWriter` with explicit `Compression::SNAPPY`; `table_project` uses `ProjectionMask` |
| [parquet-uncompressed](https://docs.rs/parquet) | `parquet` | `columnar` | `adapted` | Same `ArrowWriter` with `Compression::UNCOMPRESSED` |
| [postcard](https://github.com/jamesmunns/postcard) | `custom` | `suite` | `adapted` | `no_std`-oriented varint binary via `serde` |
| [prost](https://github.com/tokio-rs/prost) | `protobuf` | `suite`, `columnar` | `adapted` | `prost-build` messages converted in untimed `prepare_many`; timed `encode` / `decode` |
| [rkyv](https://github.com/rkyv/rkyv) | `custom` | `suite` | `adapted` | `rkyv` 0.8 `Archive` on structs; timed deserialize materializes owned `T` for fidelity |
| [rmp-serde](https://github.com/3Hren/msgpack-rust) | `msgpack` | `suite` | `adapted` | `rmp-serde` `to_vec_named` (named MessagePack maps) |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | `sbe` | `columnar` | `adapted` | `sbe-tool` 1.40.2 flyweight filled in `serialize` (`nested_table` unsupported); version reports generator |
| [scuffle-amf0](https://github.com/scufflecloud/scuffle) | `amf0` | `suite` | `native` | Pure-Rust AMF0 via `serde` (no object references) |
| [serde_avro_fast](https://github.com/Ten0/serde_avro_fast) | `avro` | `suite`, `columnar` | `native` | One-pass `serde` Avro datum with reused `SerializerConfig` (avoids `apache-avro` `Value` intermediate) |
| [serde_json](https://github.com/serde-rs/json) | `json` | `suite`, `columnar` | `native` | Standard `serde_json` baseline |
| [serde_yaml](https://github.com/dtolnay/serde-yaml) | `yaml` | `suite` | `adapted` | `serde_yaml` YAML 1.2 via `serde` |
| [simd-json](https://github.com/simd-lite/simd-json) | `json` | `suite` | `adapted` | SIMD JSON parse on decode; encode uses `serde_json` |
| [sonic-rs](https://github.com/cloudwego/sonic-rs) | `json` | `suite` | `adapted` | `serde`-compatible SIMD JSON encoder and parser |
| [speedy](https://github.com/koute/speedy) | `custom` | `suite` | `adapted` | Direct `Writable` / `Readable` fixed-width binary traits |
| [toon-format](https://github.com/toon-format/toon-rust) | `toon` | `suite` | `adapted` | Official Rust TOON crate via `serde` (`encode_default` / `decode_default`); size in UTF-8 bytes |
| [tru](https://github.com/Dicklesworthstone/toon_rust) | `toon` | `suite` | `adapted` | `toon_rust` (`tru`) `encode` / `try_decode`; size in UTF-8 bytes |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[arrow-ipc](https://docs.rs/arrow)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times arrow-rs 60.0.0 IPC stream writer and reader inside the bytes API, not the Arrow file format. The schema is chosen in prepare. The RecordBatch is built inside serialize. table_project passes field index 0 to StreamReader::try_new. No compliance decoder.
    - **[bincode](https://github.com/bincode-org/bincode)** — bincode is a compact binary format for serde. It was created so Rust programs could pack serde types without a public schema. It is a Rust-centric encoding, not a cross-language standard.
    - **[bitcode](https://github.com/SoftbearStudios/bitcode)** — bitcode is a bit-packed binary format for serde. It was written to squeeze serialized Rust values smaller than typical byte-aligned packers.
    - **[bson](https://github.com/mongodb/bson-rust)** — BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.
    - **[ciborium](https://github.com/enarx/ciborium)** — ciborium is a CBOR implementation for serde (Enarx). CBOR is the IETF binary JSON-like format. The crate exists to give Rust a serde CBOR backend.
    - **[ctoon](https://github.com/MohammadRaziei/ctoon)** — ctoon is the Rust binding over the C99 TOON core. The crate has no Serde layer. The timed path builds that value tree and calls dumps and loads. The Size column is the UTF-8 byte length.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.
    - **[flexbuffers](https://github.com/google/flatbuffers)** — FlexBuffers is the schemaless cousin of FlatBuffers. It was created so you can have a FlatBuffers-family binary without compiling a schema. The same Google repository implements it.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses the fory crate with ForyStruct-derived serializers in native mode and a reused output buffer.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-rust)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) statically linked via shared `libkiln_asm_bench.a`. Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), `array` (KLNT v2 with strided window copy), and `tensor` (KLNT v2 with zero-copy `tensor_view`).
    - **[hdf5-metno](https://github.com/metno/hdf5-rust)** — hdf5-metno is the maintained Rust binding for HDF5, the active fork of hdf5-rust. This row times one contiguous float64 dataset named grid. grid_window reads a hyperslab. The buffer is the file. The row does not time the five suite types.
    - **[ion-rs](https://github.com/amazon-ion/ion-rust)** — Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. ion-rs is the official Rust implementation. This row uses the crate's experimental serde feature (to_binary / from_ion).
    - **[minicbor](https://github.com/twittner/minicbor)** — minicbor is a compact, often no_std CBOR codec with its own Encode/Decode traits. The problem was serde overhead and no_std needs. It implements RFC 8949 directly on structs.
    - **[nanoserde](https://github.com/not-fl3/nanoserde)** — nanoserde is a tiny, dependency-light serializer for Rust (SerBin/DeBin). The problem was serde's compile-time and dependency weight in constrained crates. nanoserde generates a minimal binary path.
    - **[parquet](https://docs.rs/parquet)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times arrow-rs 60 ArrowWriter. arrow-rs DEFAULT_COMPRESSION is UNCOMPRESSED, so this row sets Compression::SNAPPY. Encodings stay at the builder default. table_project uses ProjectionMask::columns on f_float_0. No compliance decoder.
    - **[parquet-uncompressed](https://docs.rs/parquet)** — This is the same arrow-rs Parquet writer as parquet, with Compression::UNCOMPRESSED. Encodings stay at the builder default. The name is the override. No compliance decoder.
    - **[postcard](https://github.com/jamesmunns/postcard)** — postcard is a compact, no_std-friendly binary format for serde (James Munns). It was created for embedded Rust where alloc and self-describing formats are too heavy.
    - **[prost](https://github.com/tokio-rs/prost)** — prost is the de-facto Protocol Buffers implementation for Rust (tokio-rs). The problem was that Google does not ship an official Rust runtime. prost-build generates Rust from `.proto` and times encode/decode on those messages.
    - **[rkyv](https://github.com/rkyv/rkyv)** — rkyv is a zero-copy deserialization framework for Rust. The problem was that even fast binary codecs still allocate an owned value on decode. rkyv archives data so it can be accessed in place; this suite still materializes owned `T` for fidelity.
    - **[rmp-serde](https://github.com/3Hren/msgpack-rust)** — rmp-serde is MessagePack for serde (msgpack-rust). MessagePack exists as compact binary JSON. This crate maps serde types to named MessagePack maps.
    - **[sbe](https://github.com/aeron-io/simple-binary-encoding)** — SBE (Simple Binary Encoding) was created for word-aligned financial messages: a fixed block, then repeating groups, then variable-length data. The problem was tag/length codecs that touch every field on the hot path. This row fills the sbe-tool 1.40.2 Rust flyweight inside serialize. The logged version is the generator, not the vendored crate 0.1.0. It encodes table, table_project, and signal. nested_table is not an SBE body. The signal wire order is fixed fields, then the legs group, then symbol and venue. No compliance decoder.
    - **[scuffle-amf0](https://github.com/scufflecloud/scuffle)** — scuffle-amf0 is a pure-Rust AMF0 encoder and decoder from the Scuffle RTMP stack. AMF0 is the command encoding inside RTMP. The timed path is to_bytes and from_slice through Serde. The crate does not write object references.
    - **[serde_avro_fast](https://github.com/Ten0/serde_avro_fast)** — serde_avro_fast is a high-performance Avro datum codec for serde. Avro exists for compact, schema-driven records. This crate avoids the official apache-avro Value intermediate, which is multi-× slower on small records.
    - **[serde_json](https://github.com/serde-rs/json)** — serde_json is the standard JSON backend for Rust's serde. Serde was created so Rust types could implement Serialize/Deserialize once and plug in many formats. serde_json is the JSON instance of that idea.
    - **[serde_yaml](https://github.com/dtolnay/serde-yaml)** — serde_yaml is YAML via serde. YAML exists as a human-friendly config language. This crate is the usual Rust YAML backend (unmaintained upstream; still the historical serde path).
    - **[simd-json](https://github.com/simd-lite/simd-json)** — simd-json is a SIMD JSON parser for Rust (the simdjson port). The problem was parse speed vs serde_json. This row uses SIMD for parse; serialize still goes through serde_json.
    - **[sonic-rs](https://github.com/cloudwego/sonic-rs)** — sonic-rs is a SIMD-oriented JSON library for Rust, in the same family as ByteDance sonic. The problem was JSON cost on the hot path. It offers a serde-compatible encode/decode.
    - **[speedy](https://github.com/koute/speedy)** — speedy is a fast binary framework for Rust with its own Writable/Readable traits. It was written to beat generic serde binaries on the encode/decode hot path.
    - **[toon-format](https://github.com/toon-format/toon-rust)** — toon-format is the official Rust codec for TOON, with Serde. The timed path is encode_default and decode_default of the suite value. The stream path writes that UTF-8 buffer. The Size column is the byte length, not a token count.
    - **[tru](https://github.com/Dicklesworthstone/toon_rust)** — tru is the published crate for Dicklesworthstone's TOON codec. The library name is toon. The timed path is encode and try_decode of the JSON value. The Size column is the UTF-8 byte length.

## Measurement Caveats

- **`rkyv` materialization:** Timed `rkyv` deserialize constructs owned Rust structs via `from_bytes` so round-trip fidelity can be checked uniformly; in-place zero-copy `access` without allocation is faster and is examined separately in [4.10 Rust: `rkyv` vs. `Speedy`](../theory/401/rust-rkyv-vs-speedy.md).
- **`Serde` enum wrapper asymmetry:** `serde`-based adapters serialize the runner's `Fixture` enum wrapper, whereas direct-trait adapters (`speedy`, `rkyv`, `minicbor`, `dagr`) serialize inner domain structs directly; see [4.9 Rust: `Speedy` vs. `Bincode`](../theory/401/rust-speedy-vs-bincode.md) and [Timing contract](../analysis/TIMING_HONESTY.md).
- **`simd-json` split path:** `simd-json` accelerates parsing only; timed encode delegates to `serde_json`.
- **Columnar and SBE rules:** `arrow-ipc`, `parquet*`, and `sbe` construct `RecordBatch` / flyweights inside timed serialize ([Timing contract rule 8](../analysis/TIMING_HONESTY.md)); `sbe` logs the `sbe-tool` generator version (`1.40.2`) rather than the vendored crate version `0.1.0`.
- **Other notes:** `prost` maps ISO timestamps through millisecond integers (fidelity tolerates date-string drift where configured). `flatbuffers` and `capnp` are not registered in Rust (`flexbuffers` covers schemaless FlatBuffers).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Rust)](../dashboard/index.html?lang=rust&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Rust)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Rust: `Speedy` vs. `Postcard`](../analysis/call-sites/rust-speedy-vs-postcard.md) · [4.4 Rust: `prost`](../theory/401/protobuf-rust-prost.md) · [4.9 Rust: `Speedy` vs. `Bincode`](../theory/401/rust-speedy-vs-bincode.md) · [4.10 Rust: `rkyv` vs. `Speedy`](../theory/401/rust-rkyv-vs-speedy.md)
- **Build & run guide:** [`rust/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/rust/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
