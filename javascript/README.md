# JavaScript (Node.js) Serializer Benchmark

## Serializers (12–13)

| Name | Category | Optimal API |
|------|----------|-------------|
| JSON.stringify | JSON baseline | `JSON.stringify` / `JSON.parse` |
| fast-json-stringify | JSON | compiled `stringify` + `JSON.parse` |
| simdjson | JSON (optional) | `simdjson.parse` (if addon builds) |
| msgpackr | MessagePack | reused `Packr` / `Unpackr` |
| @msgpack/msgpack | MessagePack | `encode` / `decode` |
| cbor-x | CBOR | reused `Encoder` / `Decoder` |
| cbor | CBOR | `encode` / `decodeFirstSync` |
| bson | BSON | `BSON.serialize` / `deserialize` |
| bser | Binary | `dumpToBuffer` / `loadFromBuffer` |
| avsc | Avro | explicit `Type.forSchema`, then `toBuffer` / `fromBuffer` |
| protobufjs | Protobuf | real fixture `Type.encode` / `decode` |
| flatbuffers | FlatBuffers | `Builder` / `ByteBuffer` |
| v8-serializer | Native | `v8.serialize` / `v8.deserialize` |

See [docs/javascript/index.md](../docs/javascript/index.md).

## Run

```bash
./scripts/run-benchmarks.sh smoke
npm test
```

Output: `logs/javascript/YYYY-MM-DD-HHMMSS.csv` (timestamped)

Cross-language analysis: install `analysis/`, then `analyze-benchmarks -l javascript` (see root README).
