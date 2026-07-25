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

```bash
export BENCHMARK_SCHEDULE=block_shuffle   # or none for legacy fixed order
```

Default schedule is **block_shuffle** (serializers reshuffled each rep within a cell×mode; optional CSV `RunOrder` / `SchedulePosition`). See [architecture — schedule](../docs/analysis/architecture.md#timed-trial-schedule).

Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv` (+ `.configs.json`; `.errors.csv` only on failures).
