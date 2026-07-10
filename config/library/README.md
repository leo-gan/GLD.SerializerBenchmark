# Run config library

Named **run configs** select the measurement matrix:

- `types` (axis W): `type_id` + `type_config`
- `data_type_instance_count` (axis C): instances per serialize/deserialize call
- compression / execution knobs

Type ids: `message` · `document` · `telemetry` · `strings` · `event`  
(catalog: `schemas/data_catalog_v2.yaml`).

## Files

| File | Purpose |
|------|---------|
| `smoke.yaml` | CI / quick sanity (`message` + `telemetry`, n=1) |
| `default.yaml` | Publication matrix (all five types × [1, 100]) |

## Usage

```bash
# Expand cells (JSON on stdout)
./scripts/resolve_run_config.py config/library/default.yaml

# Pretty
./scripts/resolve_run_config.py config/library/smoke.yaml --pretty
```

Pin runs by **path + content hash** (sidecar). Do not edit published files in place for experiments—copy to a new file.

See `docs/analysis/data_model_v2.md`.
