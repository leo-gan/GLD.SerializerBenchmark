# Adding a Language Benchmark

This project is designed to grow language harnesses without changing the analysis core.

## 1. Register the language

Edit [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml):

```yaml
languages:
  go:  # example
    display_name: Go
    enabled: true
    runner_dir: go
    runner_script: scripts/run-benchmarks.sh
    log_dir: logs/go
    time_unit: nanoseconds
    docs_dir: docs/go
    serializers: [...]
```

Add `paths.language_log_dirs.go: logs/go`.

## 2. Implement the harness contract

| Requirement | Detail |
|-------------|--------|
| Output CSV | `logs/<lang>/benchmark-log.csv` with schema in `csv_schema` |
| `Language` column | Must match the language id (e.g. `go`) |
| Time unit | **Nanoseconds** for all new runners |
| Modes | `bytes` and `stream` (or `string`/`stream` if that matches existing C# convention) |
| Warmup | Repetition index 0 is excluded by analysis |
| Prepare outside loop | Schema compile, type registration, buffer pools — not timed |
| Timed section | Serialize + deserialize only |
| Fidelity | Round-trip semantic check; record error in `benchmark-errors.csv` |
| ObjectGraph | Skip serializers without cycle support |
| Seed | Read `RandomSeed` from `schemas/test_data_config.json` (or config `reproducibility.random_seed`) |

## 3. Test data types

Implement equivalents of: `Person`, `Integer`, `Telemetry`, `SimpleObject`, `StringArray`, `EDI_835`, `ObjectGraph`.

Use the same collection sizes from `schemas/test_data_config.json`.

## 4. Runner script

`runner_dir/scripts/run-benchmarks.sh` must accept:

```
smoke | all-single | full | research
```

Map repetitions from `modes` in `benchmark_config.yaml`.

## 5. Documentation

- `docs/<lang>/index.md` — ecosystem overview
- `docs/<lang>/index.md` — ecosystem overview plus serializer inventory (table + caveats)

## 6. Wire orchestration

Update `scripts/run-all-benchmarks.sh` to invoke the new runner.

Analysis auto-discovers `logs/<lang>/benchmark-log.csv`; pass explicitly via:

```bash
analyze-benchmarks --extra-logs go=logs/go/benchmark-log.csv
```

## 7. Tests

Add at least: smoke run produces non-empty CSV; times are positive; required columns present.
