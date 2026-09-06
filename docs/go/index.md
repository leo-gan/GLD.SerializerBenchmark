---
title: "Go"
---

Go
===

Go’s serialization landscape mixes **stdlib** codecs (`encoding/json`, `encoding/gob`), a competitive **JSON performance tier** (sonic, goccy, jsoniter, segmentio, ugorji), **schemaless binary** (MessagePack, CBOR, kelindar/binary, BSON), **text documents** (YAML, TOML), and **schema/IDL** stacks (protobuf, Avro).

## Runtime

### What it is

Go compiles to **native machine code** before the process starts. There is no Java-style virtual machine and no intermediate language such as .NET IL. The compiler still embeds a small **runtime** in every binary. That runtime includes a concurrent garbage collector, a scheduler for goroutines (Go’s lightweight threads), and the stacks those goroutines use. You do not install a separate “Go VM” in order to run the benchmark.

| | This suite |
|---|---|
| Language / module | Go **1.24** (`go.mod` toolchain `go1.24.13`) |
| Host bootstrap | Go **1.22 or newer**. `GOTOOLCHAIN=auto` may download 1.24. |
| Prepare | `./scripts/install-host-requirements.sh go` installs into `~/.local/go` |
| Run | `go/scripts/run-benchmarks.sh` runs `go build` and then the binary |
| Memory | Concurrent garbage collector inside the Go runtime |

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

| Serializer | Category | Package | Native path | Stream | Notes |
|------------|----------|---------|-------------|--------|-------|
| encoding/gob | Native | stdlib | registered types | native | Buffer Reset between encodes |
| encoding/json | JSON | stdlib | struct tags | native | Stream `SetEscapeHTML(false)` |
| fxamacker/cbor | CBOR | cbor/v2 | reused Enc/DecMode | native | Default EncOptions (not CoreDet) |
| goccy/go-json | JSON | goccy/go-json | drop-in API | native | Fast stdlib substitute |
| goccy/go-yaml | YAML | goccy/go-yaml | Marshal/Unmarshal | native | High-perf YAML |
| hamba/avro | Schema | hamba/avro/v2 | frozen API + schema cache | **native** | Stream `NewEncoder`/`NewDecoder`; schema parse once |
| jsoniter | JSON | json-iterator/go | compatible config | native | Widely deployed |
| kelindar/binary | Binary | kelindar/binary | Encoder.Reset | native | Go-only compact packer |
| linkedin/goavro | Schema | goavro/v2 | BinaryFromNative maps | **adapted** | Bytes-only codec; OCF is a different format; map convert untimed |
| mongo-bson | Document | mongo-driver/bson | Encoder+JSON tags | native | Batch wrap `{items}`; length-prefixed stream read |
| pelletier/go-toml | TOML | go-toml/v2 | Marshal/Unmarshal | native | Batch wrapped `{items}` untimed |
| protobuf | Schema | protobuf + gen | Message in prepare | **adapted** | MarshalAppend; ToDomain untimed; no native stream API |
| segmentio/encoding/json | JSON | segmentio/encoding | drop-in API | native | Production fork |
| shamaton/msgpack | MessagePack | msgpack/v3 | Marshal/Unmarshal | **native** | Stream `MarshalWrite`/`UnmarshalRead` |
| shamaton/msgpack (array) | MessagePack | msgpack/v3 | MarshalAsArray/UnmarshalAsArray | **native** | Struct-as-array (no field-name keys); stream `MarshalWriteAsArray`/`UnmarshalReadAsArray` |
| sonic | JSON | bytedance/sonic | `ConfigDefault` + Pretouch | native | SIMD-oriented hot path |
| ugorji/cbor | CBOR | ugorji/go/codec | CborHandle + EncoderBytes | native | go-codec multi-format |
| ugorji/json | JSON | ugorji/go/codec | JsonHandle + EncoderBytes | native | go-codec multi-format |
| ugorji/msgpack | MessagePack | ugorji/go/codec | MsgpackHandle + EncoderBytes | native | go-codec multi-format |
| vmihailenco/msgpack | MessagePack | msgpack/v5 | reused Encoder | native | `Encoder.Reset` + buffer |

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
