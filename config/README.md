# Config

| File | Purpose |
|------|---------|
| `benchmark_config.yaml` | Suite-wide run settings (languages, modes, data sets, analysis) |
| `serializer-sources.json` | Source-repo URL, last measured `SerializerVersion` (from `<lang>_latest.json.gz`), and origin paragraph for every registered serializer. Authored by `dashboard/scripts/write-serializer-sources.py`. The Dashboard and `docs/<lang>/index.md` Specifics consume this file. |
| `library/` | Named run configs (smoke / default matrix) |
| `dimensions.yaml` | Standard primary rules and optional I/O. Data Set membership is `data_sets` in `benchmark_config.yaml` |

Do not hand-edit `serializer-sources.json`. Change `dashboard/scripts/write-serializer-sources.py` and re-run it, then `python3 scripts/apply-serializer-sources-to-docs.py`.
