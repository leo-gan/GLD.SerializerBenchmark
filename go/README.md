# Go Serializer Benchmark

Part of the [cross-language serializer benchmark](../README.md).

## Serializers (12)

| Name | Category | Package | Call path notes |
|------|----------|---------|-----------------|
| encoding/json | JSON | stdlib | `Marshal`/`Unmarshal`; **native** stream via `Encoder`/`Decoder` |
| sonic | JSON | `github.com/bytedance/sonic` | `ConfigDefault` + `Pretouch` in `prepare` |
| goccy/go-json | JSON | `github.com/goccy/go-json` | drop-in fast JSON; native stream |
| jsoniter | JSON | `github.com/json-iterator/go` | `ConfigCompatibleWithStandardLibrary` |
| segmentio/encoding/json | JSON | `github.com/segmentio/encoding/json` | Segment production JSON fork |
| vmihailenco/msgpack | MessagePack | `github.com/vmihailenco/msgpack/v5` | most popular Go msgpack; native stream |
| shamaton/msgpack | MessagePack | `github.com/shamaton/msgpack/v3` | high-perf pure Go (benchmark staple) |
| fxamacker/cbor | CBOR | `github.com/fxamacker/cbor/v2` | reused `EncMode`/`DecMode` (CoreDet) |
| encoding/gob | Native binary | stdlib | types registered once; native stream |
| mongo-bson | Document | `go.mongodb.org/mongo-driver/bson` | official BSON |
| protobuf | Schema | `google.golang.org/protobuf` | generated from shared `.proto` in `prepare` |
| hamba/avro | Schema | `github.com/hamba/avro/v2` | schema parsed once per fixture type |

### Call-path contract (aligned with Python/Rust)

1. `Prepare(fixture)` — untimed (codec config, Pretouch, schema parse, proto convert)
2. `SerializeBytes` / `DeserializeBytes` — timed
3. Stream mode: **native** or **adapted** (see `StreamMode`)

### Not registered (by design)

- **easyjson / gogen**: require per-type codegen comments beyond shared models
- **flatbuffers / cap’n proto**: heavy IDL + zero-copy fidelity model (same deferral as other harnesses)
- **ObjectGraph**: cycles unsupported by most formats

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

Or directly (writes under monorepo `logs/go/`):

```bash
go build -o bin/serializer-benchmark-go .
./bin/serializer-benchmark-go 100
```

Requires Go **1.24+** on `PATH` (and `protoc` + `protoc-gen-go` only if regenerating protobuf).
Module versions are minimums in `go.mod` / `go.sum` (MVS); refresh non-breaking
updates with `go get -u=patch ./...` and selected `@latest` within the same major path.

`LOG_DIR` may point at a logs **root** (results go to `$LOG_DIR/go/`).

Cross-language analysis: `analyze-benchmarks -l go` (see root README).

## Build notes

- `scripts/generate-protobuf.sh` injects `go_package` into a temp copy of `../schemas/benchmark_data.proto`.
- Generated code lives in `gen/pb/` (committed for offline builds).
