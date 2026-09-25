# Dagr schema

[Dagr](https://codeberg.org/mzaks/dagr) ("Data Graph") generates the per-language code from
one Python DSL schema, so the suite has no Dagr runtime dependency. `schema.py` is the source
and `dagr.lock.json` is the committed build receipt. The receipt records the generator version
(which the harnesses report as `SerializerVersion`) and a hash of every generated file.

| Choice | Why |
|--------|-----|
| One `DataGraph` per suite type, rooted at that type | The harnesses frame N instances themselves, so there are no `Batch_*` wrappers |
| Every node `packed` | Dagr's layout for schema-evolving payloads (the protobuf-comparable one) |
| `values` on `Telemetry` is `raw` | Random doubles don't compress. `raw` stores them native little-endian, the way protobuf's packed `repeated double` does |
| `f_float64` on `Message` is `raw` | The suite's float64s are random full-mantissa doubles, so the packed probe always ends at 8 raw bytes. `raw` writes them directly: same bytes, no probe (message encode −31% in Rust) |

Field sets match [`../protobuf/benchmark_v2.proto`](../protobuf/benchmark_v2.proto).

## Regenerate

```bash
pip install dagr-cli
cd schemas/v2/dagr && dagr build     # rewrites every target below + dagr.lock.json
dagr check                           # schema vs the committed receipt
dagr verify                          # detect hand-edits of generated files
```

| Language | Generated code |
|----------|----------------|
| Rust | `rust/dagr_gen/` (crate `benchmark_v2`) |
| Swift | `swift/DagrGen/` (package `BenchmarkV2`) |
| Go | `go/gen/dagrv2/` |
| JavaScript | `javascript/src/generated/dagr/` (TypeScript) |
| Python | `python/generated/dagr/` |
| Mojo | `mojo/src/gen/dagr/` |

Never edit generated files. Change `schema.py` and rebuild.
