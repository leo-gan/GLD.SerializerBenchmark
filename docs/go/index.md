# Go

Go’s serialization landscape mixes **stdlib** codecs (`encoding/json`, `encoding/gob`), a competitive **JSON performance tier** (sonic, goccy, jsoniter, segmentio), **schemaless binary** (MessagePack, CBOR, BSON), and **schema/IDL** stacks (protobuf, Avro).

## Benchmark harness

- Directory: `go/` (repository root)
- Output: monorepo `logs/go/YYYY-MM-DD-HHMMSS.csv` (`Language=go`, times in **nanoseconds**)
- Runner: `go/scripts/run-benchmarks.sh {smoke|all-single|full|research}` or `go build && ./bin/serializer-benchmark-go <reps>`
- Registration: [`go/serializers/registry.go`](../../go/serializers/registry.go)

## Serializers (12)

| Serializer | Category | Package | Native path | Stream | Notes |
|------------|----------|---------|-------------|--------|-------|
| encoding/gob | Native | stdlib | registered types | native | Buffer Reset between encodes |
| encoding/json | JSON | stdlib | struct tags | native | Stream `SetEscapeHTML(false)` |
| fxamacker/cbor | CBOR | cbor/v2 | reused Enc/DecMode | native | Default EncOptions (not CoreDet) |
| goccy/go-json | JSON | goccy/go-json | drop-in API | native | Fast stdlib substitute |
| hamba/avro | Schema | hamba/avro/v2 | frozen API + schema cache | adapted | Parse once per fixture name |
| jsoniter | JSON | json-iterator/go | compatible config | native | Widely deployed |
| mongo-bson | Document | mongo-driver/bson | struct tags | adapted | MongoDB interop |
| protobuf | Schema | protobuf + gen | Message in prepare | adapted | MarshalAppend; ToDomain untimed |
| segmentio/encoding/json | JSON | segmentio/encoding | drop-in API | native | Production fork |
| shamaton/msgpack | MessagePack | msgpack/v3 | Marshal/Unmarshal | adapted | Benchmark staple |
| sonic | JSON | bytedance/sonic | `ConfigDefault` + Pretouch | native | SIMD-oriented hot path |
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

- **ObjectGraph:** flat `{root, nodes[]}` with integer edges (`parent`/`related`/`children` indices, `GRAPH_NULL = -1`). Every registered serializer supports it (same portable encoding as C/Rust/JS/Python).
- **Integer:** skipped for `protobuf` (no bare scalar message in shared schema).
- **protobuf** date fields go through millisecond timestamps; fidelity compares identity fields and allows date-string drift on Person passport expiration / timestamps where unchecked.
- **encoding/gob** is not a cross-language wire format.
- Stream mode is **native** only where noted; others are adapted bytes+buffer (same honesty model as other harnesses).

Also: [`go/README.md`](../../go/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Design choices

1. **Prepare outside the loop** — configs, Pretouch, EncMode, Avro schema, protobuf messages.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **Shared domain types** in `go/model` with format struct tags for reflection codecs.
