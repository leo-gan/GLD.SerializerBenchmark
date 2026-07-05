# JavaScript (Node.js) Serializer Benchmark

## Serializers (18–19)

JSON: `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional)  
Binary: `msgpackr`, `@msgpack/msgpack`, `json-pack-msgpack`, `cbor-x`, `cbor`, `bson`, `bser`, `sia`  
Schema: `avsc`, `protobufjs`, `protobuf-es`, `flatbuffers`, `flexbuffers`, `bebop`  
Native: `v8-serializer`, `devalue`

See [docs/javascript/index.md](../docs/javascript/index.md).

## Setup

```bash
npm install
npm run generate:protobuf-es   # requires protoc on PATH
```

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
npm test
```

Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv`
