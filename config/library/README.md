# Run config library

Named **run configs** select the measurement matrix:

- `types` (axis W): `type_id` + `type_config`
- `data_type_instance_count` (axis C): instances per serialize/deserialize call
- compression / execution knobs

Publication type ids: `message` · `document` · `telemetry` · `strings` · `event`  
Columnar / aligned type ids: `table` · `table_project` · `nested_table` · `signal`  
Graph type id: `graph`  
(catalog: `schemas/data_catalog_v2.yaml`).

## Files

| File | Purpose |
|------|---------|
| `smoke.yaml` | CI / quick sanity (`message` + `telemetry`, n=1) |
| `default.yaml` | Publication matrix (five types × [1, 100]) |
| `columnar-smoke.yaml` | Four new types × n=1. Requires a serializer allow-list. |
| `columnar.yaml` | Columnar and `signal` cells. Requires a serializer allow-list. |
| `graph.yaml` | Data type `graph` at N=1 and N=100. Requires a serializer allow-list. |

## Usage

```bash
# Expand cells (JSON on stdout)
./scripts/resolve_run_config.py config/library/default.yaml

# Pretty
./scripts/resolve_run_config.py config/library/smoke.yaml --pretty

# Python columnar smoke. The allow-list is required.
# "parquet" and "orc" also match the uncompressed rows.
cd python
BENCHMARK_RUN_CONFIG=../config/library/columnar-smoke.yaml \
  ./scripts/run-benchmarks.sh custom 2 "arrow-ipc,parquet,orc,orjson,protobuf,flatbuffers,avro"
```

Pin runs by **path + content hash** (sidecar). Do not edit published files in place for experiments—copy to a new file.

See `docs/analysis/test_data_configuration.md`.
