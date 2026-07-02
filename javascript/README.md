# JavaScript (Node.js) Serializer Benchmark

## Serializers (11–12)

| Name | Category | Optimal API |
|------|----------|-------------|
| JSON.stringify | JSON baseline | `JSON.stringify` / `JSON.parse` |
| fast-json-stringify | JSON | compiled `stringify` + `JSON.parse` |
| simdjson | JSON (optional) | `simdjson.parse` (if addon builds) |
| msgpackr | MessagePack | reused `Packr` / `Unpackr` |
| @msgpack/msgpack | MessagePack | `encode` / `decode` |
| cbor-x | CBOR | reused `Encoder` / `Decoder` |
| cbor | CBOR | `encode` / `decodeFirstSync` |
| avsc | Avro | `Type.forValue` once, then `toBuffer` / `fromBuffer` |
| protobufjs | Protobuf | preloaded `Type.encode` / `decode` |
| bson | BSON | `BSON.serialize` / `deserialize` |
| v8-serializer | Native | `v8.serialize` / `v8.deserialize` |
| bser | Binary | `dumpToBuffer` / `loadFromBuffer` |

## Run

```bash
./scripts/run-benchmarks.sh smoke
npm test
```

Output: `logs/javascript/YYYY-MM-DD-HHMMSS.csv` (timestamped)

Cross-language analysis and docs snapshots: install `analysis/`, run `analyze-benchmarks` (see root README and [Benchmark architecture — Goals](../docs/analysis/architecture.md)). Write published tables/plots into `docs/analysis/` and `docs/<lang>/results.md` locally and commit; CI does not regenerate them.
