---
title: "Go"
---

Go
===

Go’s serialization landscape mixes **stdlib** codecs (`encoding/json`, `encoding/gob`), a competitive **JSON performance tier** (sonic, goccy, jsoniter, segmentio, ugorji), **schemaless binary** (MessagePack, CBOR, kelindar/binary, BSON), **text documents** (YAML, TOML), and **schema/IDL** stacks (protobuf, Avro).

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
