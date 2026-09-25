# JavaScript (Node.js) Serializer Benchmark

## Serializers (24)

JSON: `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional)  
Binary: `msgpackr`, `@msgpack/msgpack`, `json-pack-msgpack`, `cbor-x`, `cbor`, `bson`, `bser`, `sia`  
Schema: `avsc`, `protobufjs`, `protobuf-es`, `google-protobuf`, `flatbuffers`, `flexbuffers`, `bebop`, `dagr-packed`, `dagr-regular`, `dagr-frozen`, `dagr-frozen-packed`  
Native: `v8-serializer`, `devalue`

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

See [docs/javascript/index.md](../docs/javascript/index.md).

## Setup

```bash
npm install
npm run generate:protobuf   # protobuf-es + google-protobuf (jspb) stubs
npm run generate:dagr       # esbuild src/generated/dagr/*.ts -> src/generated/dagr_bundle.js
# google-protobuf codegen needs cpp/scripts/setup-protobuf-sysroot.sh once
```

**Dagr:** `src/generated/dagr/*.ts` is emitted by `cd schemas/v2/dagr && dagr build`
(`pip install dagr-cli`). The TypeScript is compiled (types stripped, imports resolved,
no type-check) into the checked-in `src/generated/dagr_bundle.js` by `npm run generate:dagr`
(esbuild, a devDependency) — the generated TS uses extension-less imports that Node's
native type stripping cannot resolve, and CI runs Node 20. Re-run it after every `dagr build`.
`SerializerVersion` is the generator version from `schemas/v2/dagr/dagr.lock.json`.
The four Dagr rows are the four node layouts of the same schema (`dagr-packed`,
`dagr-regular`, `dagr-frozen`, `dagr-frozen-packed`). The packed-rooted two encode with the
generated direct builder; regular and frozen have none, so their native model is the
generated arena (built in `prepare()`) and only the arena serializer is timed
(`<Graph>_serde.writeInto` into the same reused `Builder` as the direct builder).

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
npm test
```

Logs: `logs/javascript/YYYY-MM-DD-HHMMSS.csv` (+ `.configs.json`; `.errors.csv` only on failures).
