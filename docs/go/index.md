---
title: "Go"
---

# Go

Go serialization combines standard-library codecs (`encoding/json`, `encoding/json/v2`, `encoding/gob`), high-throughput JIT/SIMD and reflection-caching JSON drop-ins (`sonic`, `goccy/go-json`, `jsoniter`, `segmentio`), schemaless binaries (`MessagePack`, `CBOR`, `BSON`, `Ion`, `AMF0`), schema-driven codecs (`protobuf`, `Avro`, `Dagr`, `SBE`), and Arrow columnar writers.

## Runtime & Environment

Go compiles ahead of time to native machine code embedding a small runtime that provides goroutine scheduling and a concurrent, low-pause tracing garbage collector. Because allocation pressure directly drives GC work and cache misses, codecs that reuse encoders, buffers, or pre-compiled type plans (`sonic` Pretouch, `Encoder.Reset`, `ugorji` handles) consistently outperform allocating reflection paths. The language and concurrency semantics are defined by the [Go Programming Language Specification](https://go.dev/ref/spec) and the [Go Memory Model](https://go.dev/ref/mem).

| Property | Configuration |
|---|---|
| Language / spec | Go 1.27 (`go.mod` toolchain `go1.27.1`; bootstrap Go 1.22+ with `GOTOOLCHAIN=auto`) |
| Build & toolchain | `go build` (default compiler optimizations) |
| Memory model | Concurrent tracing garbage collector |
| Runner & logs | `go/scripts/run-benchmarks.sh` → `logs/go/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`go/serializers/registry.go`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/go/serializers/registry.go) |
| Data sets | `suite`, `columnar`, `graph`, `tensor` |

## Registered Serializers

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [arrow-ipc](https://github.com/apache/arrow-go) | `arrow` | `columnar` | `adapted` | `arrow-go/v18` IPC stream bytes; record batch built in `SerializeBytes`; `table_project` reads `f_float_0` buffer |
| [dagr-frozen](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Generated arena in `Prepare`; timed `AppendTo<Graph>` + lazy reader→domain |
| [dagr-frozen-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct value structs in `Prepare`; timed `BuildAppend` + lazy reader→domain |
| [dagr-packed](https://codeberg.org/mzaks/dagr) | `custom` | `suite` | `adapted` | Direct value structs in `Prepare`; timed `BuildAppend` + lazy reader→domain |
| [dagr-regular](https://codeberg.org/mzaks/dagr) | `custom` | `suite`, `graph` | `adapted` | Generated arena in `Prepare`; timed `AppendTo<Graph>` + lazy reader→domain |
| [encoding/gob](https://github.com/golang/go/tree/master/src/encoding/gob) | `custom` | `suite` | `native` | Stdlib Go-only binary stream; registered types and `Buffer.Reset` |
| [encoding/json](https://github.com/golang/go/tree/master/src/encoding/json) | `json` | `suite`, `columnar` | `native` | Stdlib v1 JSON (`SetEscapeHTML(false)` on stream) |
| [encoding/json/v2](https://github.com/golang/go/tree/master/src/encoding/json/v2) | `json` | `suite` | `native` | Go 1.27 stricter stdlib JSON (`MarshalWrite` / `UnmarshalRead`) |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | Apache Fory native mode on pre-registered structs |
| [fxamacker/cbor](https://github.com/fxamacker/cbor) | `cbor` | `suite` | `native` | Reused `EncMode` / `DecMode` with default `EncOptions` (not CoreDet) |
| [gamf-amf0](https://github.com/gnolizuh/gamf) | `amf0` | `suite` | `adapted` | `gamf` AMF0 `Marshal` / `Unmarshal` |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-go) | `kiln` | `suite`, `tensor` | `adapted` | Positional Kiln v2 `Append` / `Decode` into reused buffer; `tensor_view` borrows payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `tensor` | `adapted` | Pure x86-64 Assembly Kiln v2 via flat-pointer cgo (`libkiln_asm_bench.a`); `TableColumns` + `KILN_OPT_EMBEDDED` O(1) skip; KLNT v2 zero-copy `tensor_view` |
| [go-amf0](https://github.com/yutopp/go-amf0) | `amf0` | `suite` | `native` | Reflection `Encoder` / `Decoder` for AMF0 objects and strict arrays |
| [goccy/go-json](https://github.com/goccy/go-json) | `json` | `suite` | `native` | Drop-in accelerated JSON replacement for `encoding/json` |
| [goccy/go-yaml](https://github.com/goccy/go-yaml) | `yaml` | `suite` | `native` | YAML 1.2 `Marshal` / `Unmarshal` |
| [hamba/avro](https://github.com/hamba/avro) | `avro` | `suite`, `columnar` | `native` | Frozen API with cached schema; `NewEncoder` / `NewDecoder` on stream |
| [ion-go](https://github.com/amazon-ion/ion-go) | `ion` | `suite` | `native` | Official Ion binary `MarshalBinary` / `Unmarshal` (Go field names on wire) |
| [jsoniter](https://github.com/json-iterator/go) | `json` | `suite` | `native` | `json-iterator/go` stdlib-compatible configuration |
| [kelindar/binary](https://github.com/kelindar/binary) | `custom` | `suite` | `native` | Compact Go-only binary packer with `Encoder.Reset` |
| [linkedin/goavro](https://github.com/linkedin/goavro) | `avro` | `suite` | `adapted` | `BinaryFromNative` on pre-built maps (untimed conversion; not OCF) |
| [mongo-bson](https://github.com/mongodb/mongo-go-driver) | `bson` | `suite` | `native` | Official driver `Encoder` / `Decoder` with `UseJSONStructTags`; `{items}` batch wrapper |
| [parquet](https://github.com/apache/arrow-go) | `parquet` | `columnar` | `adapted` | `arrow-go` `pqarrow` with explicit Snappy compression; `table_project` reads column 0 |
| [parquet-uncompressed](https://github.com/apache/arrow-go) | `parquet` | `columnar` | `adapted` | Same `pqarrow` writer with `Codecs.Uncompressed` |
| [pelletier/go-toml](https://github.com/pelletier/go-toml) | `toml` | `suite` | `native` | TOML v2 `Marshal` / `Unmarshal`; `{items}` batch wrapper built untimed |
| [protobuf](https://github.com/protocolbuffers/protobuf-go) | `protobuf` | `suite`, `columnar` | `adapted` | Official `protobuf-go` `MarshalAppend` on prepared `Message`; `ToDomain` untimed |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | `sbe` | `columnar` | `adapted` | `sbe-tool` 1.40.2 flyweight filled in `SerializeBytes`; `nested_table` unsupported |
| [segmentio/encoding/json](https://github.com/segmentio/encoding) | `json` | `suite` | `native` | High-throughput stdlib-compatible JSON |
| [shamaton/msgpack](https://github.com/shamaton/msgpack) | `msgpack` | `suite` | `native` | Map-encoded MessagePack (`MarshalWrite` / `UnmarshalRead` on stream) |
| [shamaton/msgpack (array)](https://github.com/shamaton/msgpack) | `msgpack` | `suite` | `native` | Positional struct-as-array MessagePack (omits string field keys) |
| [sonic](https://github.com/bytedance/sonic) | `json` | `suite` | `native` | JIT/SIMD JSON (`ConfigDefault` + untimed `Pretouch`) |
| [toon-go](https://github.com/toon-format/toon-go) | `toon` | `suite` | `adapted` | Official Go TOON codec with reused `Encoder`; size in UTF-8 bytes |
| [ugorji/cbor](https://github.com/ugorji/go) | `cbor` | `suite` | `native` | `go-codec` `CborHandle` + `EncoderBytes` |
| [ugorji/json](https://github.com/ugorji/go) | `json` | `suite` | `native` | `go-codec` `JsonHandle` + `EncoderBytes` |
| [ugorji/msgpack](https://github.com/ugorji/go) | `msgpack` | `suite` | `native` | `go-codec` `MsgpackHandle` + `EncoderBytes` |
| [vmihailenco/msgpack](https://github.com/vmihailenco/msgpack) | `msgpack` | `suite` | `native` | Reused `Encoder.Reset` and output buffer |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[arrow-ipc](https://github.com/apache/arrow-go)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times arrow-go's IPC stream writer and reader inside the suite's bytes mode, not the Arrow file format. Record batches are built inside SerializeBytes. table_project reads the f_float_0 value buffer only, because arrow-go's ipc.Reader has no included-fields option. No compliance decoder.
    - **[dagr-frozen](https://codeberg.org/mzaks/dagr)**, **[dagr-frozen-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-packed](https://codeberg.org/mzaks/dagr)**, **[dagr-regular](https://codeberg.org/mzaks/dagr)** — Dagr ("Data Graph") is a schema-driven binary format that can store shared nodes and cycles, built on an arena model. One Python DSL schema generates the code for every target language (`dagr build`), so there is no runtime library: the suite commits the generated code from `schemas/v2/dagr/schema.py`. The five suite types are emitted in all four node layouts, one row each. The graph data type is emitted only for regular and frozen, because a packed reference cannot store the person ring. On suite types, prepare builds the native value and the timed call writes every field (direct builder or arena serializer) and reads them back.
        - `dagr-frozen`: This row uses the `frozen` node layout (positional, no evolution). It also times the graph data type.
        - `dagr-frozen-packed`: This row uses the `frozen`+`packed` node layout (positional and inline, no evolution). It does not support the graph data type.
        - `dagr-packed`: This row uses the `packed` node layout (tagged, evolvable). It does not support the graph data type.
        - `dagr-regular`: This row uses the `regular` node layout (vtable, evolvable). It also times the graph data type.
    - **[encoding/gob](https://github.com/golang/go/tree/master/src/encoding/gob)** — encoding/gob is Go's native binary stream for Go types. It was created so Go programs can RPC and persist values without an IDL. It is not a cross-language wire format.
    - **[encoding/json](https://github.com/golang/go/tree/master/src/encoding/json)** — Go's `encoding/json` is the standard library JSON codec. It exists so every Go program can speak RFC 8259 with struct tags. This row is the baseline other Go JSON libraries try to beat. On Go 1.27 the package keeps v1 semantics. The stricter defaults are the separate `encoding/json/v2` row.
    - **[encoding/json/v2](https://github.com/golang/go/tree/master/src/encoding/json/v2)** — `encoding/json/v2` is the Go 1.27 standard library JSON API with stricter defaults than `encoding/json`: invalid UTF-8 and duplicate object names are errors, and `<`, `>`, and `&` are not HTML-escaped. This row times `Marshal` / `Unmarshal` and `MarshalWrite` / `UnmarshalRead`.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses github.com/apache/fory/go/fory in native mode on registered structs and slices.
    - **[fxamacker/cbor](https://github.com/fxamacker/cbor)** — fxamacker/cbor is a widely used Go CBOR codec for RFC 8949. CBOR is the IETF binary JSON-like format. This library focuses on correctness options (including deterministic modes) and reusable Enc/DecMode values.
    - **[gamf-amf0](https://github.com/gnolizuh/gamf)** — gamf is a Go AMF0 codec. AMF0 is the command encoding inside RTMP. The timed path is Marshal, shaped like encoding/json. Version 1.0.0 panics while decoding AMF3 into a struct, so there is no AMF3 row.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-go)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly Kiln Wire Format v2 codec linked statically into Go via a flat-pointer cgo bridge (`libkiln_asm_bench.a`). Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), and `tensor` (KLNT v2 with zero-copy `tensor_view`). Full RFC 3629 UTF-8 validation is always active.
    - **[go-amf0](https://github.com/yutopp/go-amf0)** — go-amf0 is a Go AMF0 encoder and decoder. AMF0 is the command encoding inside RTMP. The timed path reuses an Encoder and calls Encode on the suite struct. The library does not implement AMF0 references, so a graph is skipped.
    - **[goccy/go-json](https://github.com/goccy/go-json)** — goccy/go-json was written as a faster drop-in for `encoding/json`. The problem was stdlib JSON cost in high-QPS Go services. It keeps the same API and implements a faster encode/decode path.
    - **[goccy/go-yaml](https://github.com/goccy/go-yaml)** — goccy/go-yaml is a high-performance YAML 1.2 library for Go. The problem was that go-yaml v2/v3 was often the slow path in config-heavy services. It aims at a faster Marshal/Unmarshal.
    - **[hamba/avro](https://github.com/hamba/avro)** — hamba/avro is a high-performance Avro library for Go. Avro was created for compact, schema-driven records. hamba focuses on a frozen API and schema cache so the timed path is encode/decode, not schema parse.
    - **[ion-go](https://github.com/amazon-ion/ion-go)** — Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. ion-go is the official Go implementation. This row times MarshalBinary / Unmarshal and the binary encoder stream.
    - **[jsoniter](https://github.com/json-iterator/go)** — json-iterator/go was created as a high-performance, stdlib-compatible JSON library for Go. The problem was the same stdlib bottleneck. It solves it with a compatible config and a faster implementation.
    - **[kelindar/binary](https://github.com/kelindar/binary)** — kelindar/binary is a compact, Go-only packer. It was written for high-throughput in-process and Go-to-Go payloads where a public schema is not required. Encoder.Reset is the reuse path.
    - **[linkedin/goavro](https://github.com/linkedin/goavro)** — LinkedIn goavro is an Avro binary codec for Go, used in Kafka/Avro pipelines. Avro exists so producers and consumers share a schema. goavro speaks BinaryFromNative maps (OCF is a different format).
    - **[mongo-bson](https://github.com/mongodb/mongo-go-driver)** — BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.
    - **[parquet](https://github.com/apache/arrow-go)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times arrow-go pqarrow. arrow-go WriterProperties defaults to uncompressed, so this row sets Snappy, which is the suite's parquet page codec. table_project passes column index 0 to GetRecordReader. The schema is prepared untimed. The batch is built inside SerializeBytes. No compliance decoder.
    - **[parquet-uncompressed](https://github.com/apache/arrow-go)** — This is the same arrow-go pqarrow writer as parquet, with compression left off (Codecs.Uncompressed). Encodings stay at the library default. The name is the override. No compliance decoder.
    - **[pelletier/go-toml](https://github.com/pelletier/go-toml)** — pelletier/go-toml is a TOML 1.0 parser/encoder for Go. TOML was created as an obvious config language. This library is a common Go implementation of that spec.
    - **[protobuf](https://github.com/protocolbuffers/protobuf-go)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[sbe](https://github.com/aeron-io/simple-binary-encoding)** — SBE (Simple Binary Encoding) was created for word-aligned financial messages: a fixed block, then repeating groups, then variable-length data. The problem was tag/length codecs that touch every field on the hot path. This row fills the sbe-tool 1.40.2 Go flyweight inside SerializeBytes. It encodes table, table_project, and signal. nested_table is not an SBE body. No compliance decoder.
    - **[segmentio/encoding/json](https://github.com/segmentio/encoding)** — segmentio/encoding/json is a production fork of a faster Go JSON stack, kept as a drop-in for `encoding/json`. The problem was stdlib JSON in large Go services. This row times that API.
    - **[shamaton/msgpack](https://github.com/shamaton/msgpack)**, **[shamaton/msgpack (array)](https://github.com/shamaton/msgpack)** — shamaton/msgpack is another Go MessagePack implementation, including a struct-as-array mode that omits field-name keys. The problem was MessagePack map overhead for known structs. Array mode solves that with positional fields.
        - `shamaton/msgpack (array)`: This row uses struct-as-array (no field-name keys) and the matching stream helpers.
    - **[sonic](https://github.com/bytedance/sonic)** — Bytedance sonic was written to push Go JSON through JIT and SIMD on the hot path. The problem was that even fast reflection JSON was not enough at ByteDance scale. sonic solves it with `ConfigDefault` plus optional Pretouch.
    - **[toon-go](https://github.com/toon-format/toon-go)** — toon-go is the official Go codec for TOON. Struct fields use a toon tag and fall back to the json tag. The timed path reuses an Encoder and calls Marshal and Unmarshal. The stream path writes that buffer. The Size column is the UTF-8 byte length.
    - **[ugorji/cbor](https://github.com/ugorji/go)**, **[ugorji/json](https://github.com/ugorji/go)**, **[ugorji/msgpack](https://github.com/ugorji/go)** — ugorji/go (go-codec) was created as one Go library that speaks several formats (JSON, MessagePack, CBOR, Binc) through a shared handle/encoder model. The problem was maintaining a separate stack per format. This row times one handle of that multi-format codec.
        - `ugorji/cbor`: This row times the CborHandle.
        - `ugorji/json`: This row times the JsonHandle.
        - `ugorji/msgpack`: This row times the MsgpackHandle.
    - **[vmihailenco/msgpack](https://github.com/vmihailenco/msgpack)** — vmihailenco/msgpack is a popular MessagePack library for Go. MessagePack exists as compact binary JSON. This implementation emphasizes a familiar Encoder/Decoder API with buffer reuse.

## Measurement Caveats

- **Stream honesty:** `fory`, `protobuf`, `linkedin/goavro`, `arrow-ipc`, `parquet*`, `sbe`, `gamf-amf0`, `gld-kiln`, `gld-kiln-asm`, `toon-go`, and all four `dagr-*` rows have no native stream API for the same wire bytes and are logged as `StreamMode=adapted`. All other registered Go codecs use native stream APIs.
- **Dagr decode boundary:** Like `protobuf`, `dagr-packed` and `dagr-frozen-packed` build value structs in untimed `Prepare` (and `dagr-regular`/`dagr-frozen` build arenas in `Prepare`). Unlike `protobuf` (`ToDomain` untimed), Dagr materializes domain values from lazy readers **inside** timed deserialize, and $N > 1$ batches use the suite `[u32 count][u32 len][record]` frame.
- **Root-array wrappers:** `pelletier/go-toml` and `mongo-bson` wrap $N > 1$ batches in an `{items: [...]}` document because neither format permits a bare root array.
- **Go-only formats & CPU sensitivity:** `encoding/gob` and `kelindar/binary` are Go-specific wire formats. `sonic` uses architecture-specific JIT/SIMD paths sensitive to host CPU extensions.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Go)](../dashboard/index.html?lang=go&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Go)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Go: `kelindar/binary` vs. `hamba/avro`](../analysis/call-sites/go-kelindar-vs-avro.md)
- **Build & run guide:** [`go/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/go/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
