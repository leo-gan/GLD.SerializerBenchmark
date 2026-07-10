# Go Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Serializers (12)

| Name | Category | Package | Call path notes |
|------|----------|---------|-----------------|
| encoding/json | JSON | stdlib | `Marshal`/`Unmarshal`; stream `Encoder` with `SetEscapeHTML(false)` |
| sonic | JSON | `github.com/bytedance/sonic` | `ConfigDefault` + `Pretouch` in `prepare` |
| goccy/go-json | JSON | `github.com/goccy/go-json` | drop-in fast JSON; native stream |
| jsoniter | JSON | `github.com/json-iterator/go` | `ConfigCompatibleWithStandardLibrary` |
| segmentio/encoding/json | JSON | `github.com/segmentio/encoding/json` | Segment production JSON fork |
| vmihailenco/msgpack | MessagePack | `github.com/vmihailenco/msgpack/v5` | **reused `Encoder.Reset`** + buffer |
| shamaton/msgpack | MessagePack | `github.com/shamaton/msgpack/v3` | high-perf pure Go |
| fxamacker/cbor | CBOR | `github.com/fxamacker/cbor/v2` | reused `EncMode`/`DecMode` |
| encoding/gob | Native binary | stdlib | types registered once; buffer `Reset` |
| mongo-bson | Document | `go.mongodb.org/mongo-driver/bson` | official BSON |
| protobuf | Schema | `google.golang.org/protobuf` | timed marshal/unmarshal; domain convert untimed |
| hamba/avro | Schema | `github.com/hamba/avro/v2` | frozen `API` + schema cache |

### Call-path contract

1. `Prepare(fixture)` — untimed  
2. `SerializeBytes` / `DeserializeBytes` — timed  
3. Stream: **native** or **adapted** (`StreamMode`)

### Not registered (by design)

- **easyjson / gogen**: per-type codegen beyond shared models  
- **flatbuffers / cap’n proto**: heavy IDL + zero-copy fidelity model  

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`  
(smoke filter default: `message`).

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

```bash
go build -o bin/serializer-benchmark-go .
./bin/serializer-benchmark-go 100
```

Requires Go **1.24+**. `LOG_DIR` may be a logs **root** (results under `$LOG_DIR/go/`).

Analysis: `analyze-benchmarks -l go`.

## Build notes

- `scripts/generate-protobuf.sh` regenerates protobuf bindings for the suite schema.  
- Generated code under `gen/` is committed for offline builds.
