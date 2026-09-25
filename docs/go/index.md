---
title: "Go"
---

# Go

Go’s serialization landscape mixes **stdlib** codecs (`encoding/json`, `encoding/gob`), a competitive **JSON performance tier** (sonic, goccy, jsoniter, segmentio, ugorji), **schemaless binary** (MessagePack, CBOR, kelindar/binary, BSON), **text documents** (YAML, TOML), and **schema/IDL** stacks (protobuf, Avro).

## Runtime

### What it is

Go compiles to **native machine code** before the process starts. There is no Java-style virtual machine and no intermediate language such as .NET IL. The compiler still embeds a small **runtime** in every binary. That runtime includes a concurrent garbage collector, a scheduler for goroutines (Go’s lightweight threads), and the stacks those goroutines use. You do not install a separate “Go VM” in order to run the benchmark.

|                   | This suite                                                              |
| ----------------- | ----------------------------------------------------------------------- |
| Language / module | Go **1.25** (`go.mod`)                                                  |
| Host bootstrap    | Go **1.22 or newer**. `GOTOOLCHAIN=auto` may download 1.25.             |
| Prepare           | `./scripts/install-host-requirements.sh go` installs into `~/.local/go` |
| Run               | `go/scripts/run-benchmarks.sh` runs `go build` and then the binary      |
| Memory            | Concurrent garbage collector inside the Go runtime                      |

### What this suite runs

The runner is a normal `go build` of the `go/` tree with the compiler’s default optimizations. The install script only needs a bootstrap compiler. If that bootstrap is older than the version pinned in `go.mod`, the Go toolchain setting `GOTOOLCHAIN=auto` downloads the exact version the module asks for.

### What changes the numbers

Go’s garbage collector is designed for short pauses, but allocation still matters. Rows that reuse an `Encoder`, an `EncMode`, or a buffer — sonic’s `Pretouch`, ugorji Handles — often pull ahead of `encoding/json` for that reason. SIMD libraries such as sonic also depend on the host CPU. `encoding/gob` and `kelindar/binary` are Go-only wire formats.

### Suite-specific gotchas

**protobuf** and **linkedin/goavro** have no native stream API in this suite. Their stream rows are **adapted**: the timed path is still bytes, then a write or read of those bytes.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`go/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/go/README.md). The language overview is the [Go documentation](https://go.dev/doc/).

## Benchmark runner

- Directory: `go/` (repository root)
- Output: monorepo `logs/go/YYYY-MM-DD-HHMMSS.csv` (`Language=go`, times in **nanoseconds**)
- Runner: `go/scripts/run-benchmarks.sh {smoke|all-single|full|research}` or `go build && ./bin/serializer-benchmark-go <reps>`
- Registration: [`go/serializers/registry.go`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/go/serializers/registry.go)

## Serializers

| Serializer                                                                  | Category    | Package            | Native path                     | Stream      | Notes                                                                                     |
| --------------------------------------------------------------------------- | ----------- | ------------------ | ------------------------------- | ----------- | ----------------------------------------------------------------------------------------- |
| [encoding/gob](https://github.com/golang/go/tree/master/src/encoding/gob)   | Native      | stdlib             | registered types                | native      | Buffer Reset between encodes                                                              |
| [encoding/json](https://github.com/golang/go/tree/master/src/encoding/json) | JSON        | stdlib             | struct tags                     | native      | Stream `SetEscapeHTML(false)`                                                             |
| [fory](https://github.com/apache/fory)                                      | Native      | fory/go/fory       | registered structs              | adapted     | Native mode; registration outside timing                                                  |
| [fxamacker/cbor](https://github.com/fxamacker/cbor)                         | CBOR        | cbor/v2            | reused Enc/DecMode              | native      | Default EncOptions (not CoreDet)                                                          |
| [goccy/go-json](https://github.com/goccy/go-json)                           | JSON        | goccy/go-json      | drop-in API                     | native      | Fast stdlib substitute                                                                    |
| [goccy/go-yaml](https://github.com/goccy/go-yaml)                           | YAML        | goccy/go-yaml      | Marshal/Unmarshal               | native      | High-perf YAML                                                                            |
| [hamba/avro](https://github.com/hamba/avro)                                 | Schema      | hamba/avro/v2      | frozen API + schema cache       | **native**  | Stream `NewEncoder`/`NewDecoder`; schema parse once                                       |
| [jsoniter](https://github.com/json-iterator/go)                             | JSON        | json-iterator/go   | compatible config               | native      | Widely deployed                                                                           |
| [kelindar/binary](https://github.com/kelindar/binary)                       | Binary      | kelindar/binary    | Encoder.Reset                   | native      | Go-only compact packer                                                                    |
| [linkedin/goavro](https://github.com/linkedin/goavro)                       | Schema      | goavro/v2          | BinaryFromNative maps           | **adapted** | Bytes-only codec; OCF is a different format; map convert untimed                          |
| [mongo-bson](https://github.com/mongodb/mongo-go-driver)                    | Document    | mongo-driver/bson  | Encoder+JSON tags               | native      | Batch wrap `{items}`; length-prefixed stream read                                         |
| [pelletier/go-toml](https://github.com/pelletier/go-toml)                   | TOML        | go-toml/v2         | Marshal/Unmarshal               | native      | Batch wrapped `{items}` untimed                                                           |
| [protobuf](https://github.com/protocolbuffers/protobuf-go)                  | Schema      | protobuf + gen     | Message in prepare              | **adapted** | MarshalAppend; ToDomain untimed; no native stream API                                     |
| [segmentio/encoding/json](https://github.com/segmentio/encoding)            | JSON        | segmentio/encoding | drop-in API                     | native      | Production fork                                                                           |
| [shamaton/msgpack](https://github.com/shamaton/msgpack)                     | MessagePack | msgpack/v3         | Marshal/Unmarshal               | **native**  | Stream `MarshalWrite`/`UnmarshalRead`                                                     |
| [shamaton/msgpack (array)](https://github.com/shamaton/msgpack)             | MessagePack | msgpack/v3         | MarshalAsArray/UnmarshalAsArray | **native**  | Struct-as-array (no field-name keys); stream `MarshalWriteAsArray`/`UnmarshalReadAsArray` |
| [sonic](https://github.com/bytedance/sonic)                                 | JSON        | bytedance/sonic    | `ConfigDefault` + Pretouch      | native      | SIMD-oriented hot path                                                                    |
| [ugorji/cbor](https://github.com/ugorji/go)                                 | CBOR        | ugorji/go/codec    | CborHandle + EncoderBytes       | native      | go-codec multi-format                                                                     |
| [ugorji/json](https://github.com/ugorji/go)                                 | JSON        | ugorji/go/codec    | JsonHandle + EncoderBytes       | native      | go-codec multi-format                                                                     |
| [ugorji/msgpack](https://github.com/ugorji/go)                              | MessagePack | ugorji/go/codec    | MsgpackHandle + EncoderBytes    | native      | go-codec multi-format                                                                     |
| [vmihailenco/msgpack](https://github.com/vmihailenco/msgpack)               | MessagePack | msgpack/v5         | reused Encoder                  | native      | `Encoder.Reset` + buffer                                                                  |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [encoding/gob](https://github.com/golang/go/tree/master/src/encoding/gob) · `go1.24.13`

encoding/gob is Go's native binary stream for Go types. It was created so Go programs can RPC and persist values without an IDL. It is not a cross-language wire format.

#### [encoding/json](https://github.com/golang/go/tree/master/src/encoding/json) · `go1.24.13`

Go's `encoding/json` is the standard library JSON codec. It exists so every Go program can speak RFC 8259 with struct tags. This row is the baseline other Go JSON libraries try to beat.

#### [fory](https://github.com/apache/fory)

Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses github.com/apache/fory/go/fory in native mode on registered structs and slices.

#### [fxamacker/cbor](https://github.com/fxamacker/cbor) · `2.9.4`

fxamacker/cbor is a widely used Go CBOR codec for RFC 8949. CBOR is the IETF binary JSON-like format. This library focuses on correctness options (including deterministic modes) and reusable Enc/DecMode values.

#### [goccy/go-json](https://github.com/goccy/go-json) · `0.10.6`

goccy/go-json was written as a faster drop-in for `encoding/json`. The problem was stdlib JSON cost in high-QPS Go services. It keeps the same API and implements a faster encode/decode path.

#### [goccy/go-yaml](https://github.com/goccy/go-yaml) · `1.19.2`

goccy/go-yaml is a high-performance YAML 1.2 library for Go. The problem was that go-yaml v2/v3 was often the slow path in config-heavy services. It aims at a faster Marshal/Unmarshal.

#### [hamba/avro](https://github.com/hamba/avro) · `2.31.0`

hamba/avro is a high-performance Avro library for Go. Avro was created for compact, schema-driven records. hamba focuses on a frozen API and schema cache so the timed path is encode/decode, not schema parse.

#### [jsoniter](https://github.com/json-iterator/go) · `1.1.12`

json-iterator/go was created as a high-performance, stdlib-compatible JSON library for Go. The problem was the same stdlib bottleneck. It solves it with a compatible config and a faster implementation.

#### [kelindar/binary](https://github.com/kelindar/binary) · `1.0.19`

kelindar/binary is a compact, Go-only packer. It was written for high-throughput in-process and Go-to-Go payloads where a public schema is not required. Encoder.Reset is the reuse path.

#### [linkedin/goavro](https://github.com/linkedin/goavro) · `2.15.0`

LinkedIn goavro is an Avro binary codec for Go, used in Kafka/Avro pipelines. Avro exists so producers and consumers share a schema. goavro speaks BinaryFromNative maps (OCF is a different format).

#### [mongo-bson](https://github.com/mongodb/mongo-go-driver) · `1.17.9`

BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.

#### [pelletier/go-toml](https://github.com/pelletier/go-toml) · `2.4.3`

pelletier/go-toml is a TOML 1.0 parser/encoder for Go. TOML was created as an obvious config language. This library is a common Go implementation of that spec.

#### [protobuf](https://github.com/protocolbuffers/protobuf-go) · `1.36.12`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [segmentio/encoding/json](https://github.com/segmentio/encoding) · `0.5.4`

segmentio/encoding/json is a production fork of a faster Go JSON stack, kept as a drop-in for `encoding/json`. The problem was stdlib JSON in large Go services. This row times that API.

#### [shamaton/msgpack](https://github.com/shamaton/msgpack) · `3.2.3`

shamaton/msgpack is another Go MessagePack implementation, including a struct-as-array mode that omits field-name keys. The problem was MessagePack map overhead for known structs. Array mode solves that with positional fields.

#### [shamaton/msgpack (array)](https://github.com/shamaton/msgpack) · `3.2.3`

shamaton/msgpack is another Go MessagePack implementation, including a struct-as-array mode that omits field-name keys. The problem was MessagePack map overhead for known structs. Array mode solves that with positional fields. This row uses struct-as-array (no field-name keys) and the matching stream helpers.

#### [sonic](https://github.com/bytedance/sonic) · `1.15.4`

Bytedance sonic was written to push Go JSON through JIT and SIMD on the hot path. The problem was that even fast reflection JSON was not enough at ByteDance scale. sonic solves it with `ConfigDefault` plus optional Pretouch.

#### [ugorji/cbor](https://github.com/ugorji/go) · `1.3.2`

ugorji/go (go-codec) was created as one Go library that speaks several formats (JSON, MessagePack, CBOR, Binc) through a shared handle/encoder model. The problem was maintaining a separate stack per format. This row times one handle of that multi-format codec. This row times the CborHandle.

#### [ugorji/json](https://github.com/ugorji/go) · `1.3.2`

ugorji/go (go-codec) was created as one Go library that speaks several formats (JSON, MessagePack, CBOR, Binc) through a shared handle/encoder model. The problem was maintaining a separate stack per format. This row times one handle of that multi-format codec. This row times the JsonHandle.

#### [ugorji/msgpack](https://github.com/ugorji/go) · `1.3.2`

ugorji/go (go-codec) was created as one Go library that speaks several formats (JSON, MessagePack, CBOR, Binc) through a shared handle/encoder model. The problem was maintaining a separate stack per format. This row times one handle of that multi-format codec. This row times the MsgpackHandle.

#### [vmihailenco/msgpack](https://github.com/vmihailenco/msgpack) · `5.4.1`

vmihailenco/msgpack is a popular MessagePack library for Go. MessagePack exists as compact binary JSON. This implementation emphasizes a familiar Encoder/Decoder API with buffer reuse.

### Call-path contract (same idea as Python/Rust)

```text
prepare(fixture)                 # untimed: config, Pretouch, schema, proto convert
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed (codec only)
  ToDomain (if DomainConverter)  # untimed (e.g. protobuf Message → model)
  fidelity(expected, actual)     # untimed
```

### Caveats

- **protobuf** date fields may use millisecond timestamps; fidelity allows limited date-string drift where configured.
- **encoding/gob** and **kelindar/binary** are not cross-language wire formats.
- **pelletier/go-toml** wraps multi-instance cells as a TOML table with `items` (TOML cannot use bare array roots).
- **Stream adapted** only for **protobuf** and **linkedin/goavro** (bytes-only libraries; OCF/gRPC would change wire format). All other registered Go codecs use **native** stream APIs.
- **mongo-bson** uses official Encoder/Decoder + `UseJSONStructTags` (no JSON map bridge).

Also: [`go/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/go/README.md) (call-path table). [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=go&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

## Design choices

1. **Prepare outside the loop** — configs, Pretouch, EncMode, Avro schema, protobuf messages, ugorji Handles, goavro maps.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print; no JSON envelopes for binary codecs.
3. **Dual mode** — `bytes` and `stream` with honest `StreamMode` metadata (native vs adapted).
4. **Shared domain types** in `go/model` with format struct tags for reflection codecs.
