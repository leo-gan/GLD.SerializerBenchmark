# Adding a language

Grow language harnesses without changing the analysis core. Background: [Benchmark architecture](architecture.md).

## 1. Register the language

Edit **`config/benchmark_config.yaml`** (master config — used at runtime by
`scripts/read-config.py`, `scripts/run-all-benchmarks.sh`, and
`analyze-benchmarks`):

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

Add `paths.language_log_dirs.go: logs/go` if your config uses that map.

## 2. Implement the harness contract

| Requirement | Detail |
|-------------|--------|
| Output CSV | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with schema in `csv_schema` |
| `Language` column | Must match the language id (e.g. `go`) |
| Time unit | **Nanoseconds** for all new runners |
| Modes | `bytes` and `stream` (or `string`/`stream` if matching legacy C#) |
| Warmup | Repetition index 0 excluded by analysis |
| Prepare outside loop | Schema compile, type registration, buffer pools — not timed |
| Timed section | Serialize + deserialize only |
| Fidelity | Round-trip semantic check; errors in `logs/<lang>/<ts>.errors.csv` (same stem as the result CSV) |
| ObjectGraph | Skip serializers without cycle support |
| Seed | `RandomSeed` from `schemas/test_data_config.json` (or config `reproducibility.random_seed`) |

Timing model: [Benchmark architecture](architecture.md#measurement-model).

## 3. Test data types

Implement equivalents of: `Person`, `Integer`, `Telemetry`, `SimpleObject`, `StringArray`, `EDI_835`, `ObjectGraph`.

Use collection sizes from `schemas/test_data_config.json` — [Test Data Configuration](test_data_configuration.md).

## 4. Runner script

`runner_dir/scripts/run-benchmarks.sh` must accept:

```text
smoke | all-single | full | research
```

Source `scripts/lib/config.sh` and use `bench_mode_reps "$MODE"` (reads
`modes.<name>.repetitions`). Set `BENCHMARK_SEED` from `bench_random_seed`.
Do **not** hard-code repetition counts.

## 5. Documentation

- `docs/<lang>/index.md` — ecosystem overview, registered serializer inventory, caveats
- After benchmarks: regenerate site snapshots (`analyze-benchmarks`) so `docs/<lang>/results.md` can be produced when logs exist
- Register the language under Benchmarks in `mkdocs.yml` (Overview + Results)

## 6. Wire orchestration

Update `scripts/run-all-benchmarks.sh` to invoke the new runner.

Auto-discovers timestamped CSVs under `logs/<lang>/`; or pass:

```bash
analyze-benchmarks --logs go=logs/go
```

- Update `_KNOWN_LANGS` in `analysis/src/benchmark_analysis/cli.py` so that `--compare-a/--compare-b` and path-based inference recognize the new language id.
- Extend `generate_language_results_pages` / `_LANG_*` maps in `reports.py` (and `_LANG_DOCS_DIR`) if the docs folder id differs from the language id (e.g. `csharp` → `docs/c-sharp/`).

## 7. Tests

At least: smoke run produces non-empty CSV; times positive; required columns present.
