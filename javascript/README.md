# JavaScript (Node.js) Serializer Benchmark

## Serializers (20)

JSON: `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional)  
Binary: `msgpackr`, `@msgpack/msgpack`, `json-pack-msgpack`, `cbor-x`, `cbor`, `bson`, `bser`, `sia`  
Schema: `avsc`, `protobufjs`, `protobuf-es`, `google-protobuf`, `flatbuffers`, `flexbuffers`, `bebop`  
Native: `v8-serializer`, `devalue`

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

See [docs/javascript/index.md](../docs/javascript/index.md).

## Setup

```bash
npm install
npm run generate:protobuf   # protobuf-es + google-protobuf (jspb) stubs
# google-protobuf codegen needs cpp/scripts/setup-protobuf-sysroot.sh once
```

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
npm test
```

Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv` (+ `.configs.json`; `.errors.csv` only on failures).
