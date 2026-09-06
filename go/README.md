# Go Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Serializers (19)

| Name | Category | Package | Call path notes |
|------|----------|---------|-----------------|
| encoding/json | JSON | stdlib | `Marshal`/`Unmarshal`; stream `Encoder` with `SetEscapeHTML(false)` |
| sonic | JSON | `github.com/bytedance/sonic` | `ConfigDefault` + `Pretouch` in `prepare` |
| goccy/go-json | JSON | `github.com/goccy/go-json` | drop-in fast JSON; native stream |
| jsoniter | JSON | `github.com/json-iterator/go` | `ConfigCompatibleWithStandardLibrary` |
| segmentio/encoding/json | JSON | `github.com/segmentio/encoding/json` | Segment production JSON fork |
| ugorji/json | JSON | `github.com/ugorji/go/codec` | `JsonHandle` + `NewEncoderBytes`/`ResetBytes` |
| vmihailenco/msgpack | MessagePack | `github.com/vmihailenco/msgpack/v5` | **reused `Encoder.Reset`** + buffer |
| shamaton/msgpack | MessagePack | `github.com/shamaton/msgpack/v3` | `Marshal`/`Unmarshal`; **native stream** `MarshalWrite`/`UnmarshalRead` |
| shamaton/msgpack (array) | MessagePack | `github.com/shamaton/msgpack/v3` | `MarshalAsArray`/`UnmarshalAsArray`; **native stream** `MarshalWriteAsArray`/`UnmarshalReadAsArray` (struct-as-array, no field-name keys) |
| ugorji/msgpack | MessagePack | `github.com/ugorji/go/codec` | `MsgpackHandle` + EncoderBytes reuse |
| fxamacker/cbor | CBOR | `github.com/fxamacker/cbor/v2` | reused `EncMode`/`DecMode` |
| ugorji/cbor | CBOR | `github.com/ugorji/go/codec` | `CborHandle` + EncoderBytes reuse |
| kelindar/binary | Binary | `github.com/kelindar/binary` | reused `Encoder.Reset`; Go-only wire |
| encoding/gob | Native binary | stdlib | types registered once; buffer `Reset` |
| mongo-bson | Document | `go.mongodb.org/mongo-driver/bson` | Encoder+UseJSONStructTags; stream length-prefixed doc |
| goccy/go-yaml | YAML | `github.com/goccy/go-yaml` | `Marshal`/`Unmarshal`; stream Encoder |
| pelletier/go-toml | TOML | `github.com/pelletier/go-toml/v2` | batch wrapped as `{items:…}` untimed |
| protobuf | Schema | `google.golang.org/protobuf` | timed marshal/unmarshal; **stream adapted** (bytes-only API) |
| hamba/avro | Schema | `github.com/hamba/avro/v2` | frozen `API` + schema cache; **native stream** `NewEncoder`/`NewDecoder` |
| linkedin/goavro | Schema | `github.com/linkedin/goavro/v2` | `BinaryFromNative`; **stream adapted** (OCF is different format) |

### Call-path contract

1. `Prepare(fixture)` — untimed  
2. `SerializeBytes` / `DeserializeBytes` — timed  
3. Stream: **native** (library `io.Reader`/`io.Writer` APIs) or **adapted** (`Marshal`→`Write` / `ReadAll`→`Unmarshal`) via `StreamMode`

### Not registered (by design)

- **easyjson / gogen / msgp**: per-type codegen beyond shared models  
- **flatbuffers / cap’n proto**: heavy IDL + zero-copy fidelity model  
- **gotiny**: README marks early-stage / not production-ready  

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

- `scripts/generate-protobuf.sh` regenerates Data Model v2 protobuf bindings into `gen/pbv2/`.  
- Generated code under `gen/pbv2/` is committed for offline builds.
