# Adding a language

**Job of this page:** implementer checklist to grow a language harness **without** changing the analysis core.

Background (layout, timing model, contract summary): [Benchmark architecture](architecture.md).  
Fixtures: [Test data types](test_data_configuration.md).  
Stats after you have CSVs: [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## 1. Register the language

Edit **`config/benchmark_config.yaml`** (used by `scripts/read-config.py`, `scripts/run-all-benchmarks.sh`, and `analyze-benchmarks`):

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

Meet the [harness contract summary](architecture.md#harness-contract-summary) and [measurement model](architecture.md#measurement-model). In particular:

| Requirement | Detail |
|-------------|--------|
| Output CSV | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with `csv_schema` |
| `Language` column | Must match the language id (e.g. `go`) |
| Time unit | **Nanoseconds** for all runners (including C#) |
| Modes | `bytes` and `stream` (or `string`/`stream` if matching legacy C#) |
| Warmup | Repetition index 0 excluded by analysis |
| Prepare outside loop | Schema compile, type registration, buffer pools — not timed |
| Timed section | Serialize + deserialize only |
| Fidelity | Round-trip semantic check; errors in `logs/<lang>/<ts>.errors.csv` (same timestamp stem as the result CSV) |
| Optional sidecars | `*.configs.json` (environment + optional dataset/serializer metadata; legacy `*.environment.json` still readable) |
| event | Attribute map / envelope |
| Seed | From `schemas/test_data_config.json` / config `reproducibility.random_seed` |

## 3. Test data types

**Data Model v2 (suite default):** implement `make_one` / cells for `message`, `document`, `telemetry`, `strings`, `event` (see data_model_v2.md).

**Data Model v2 (cutover path):** see [Data Model v2](data_model_v2.md). Implement `make_one` for `message`, `document`, `telemetry`, `strings`, `event`; expand cells from `./scripts/resolve_run_config.py`; emit `DataTypeInstanceCount` and `TypeConfigHash`. Generators exist under language trees (`python/.../data_v2`, `go/model/v2`, `rust/src/data_v2.rs`, `javascript/src/data_v2.js`, …). Schema artifacts: `schemas/v2/` + `scripts/schemas/generate-all.sh`.

Use collection sizes from `schemas/test_data_config.json` — [Test data types](test_data_configuration.md).

## 4. Runner script

`runner_dir/scripts/run-benchmarks.sh` must accept modes:

`smoke` | `all-single` | `full` | `research`

Source `scripts/lib/config.sh` and use `bench_mode_reps "$MODE"` (reads `modes.<name>.repetitions`). Set `BENCHMARK_SEED` from `bench_random_seed`. Do **not** hard-code repetition counts.

## 5. Documentation

- `docs/<lang>/index.md` — ecosystem overview, registered inventory, caveats  
- After benchmarks: `analyze-benchmarks` so `docs/<lang>/results.md` can be produced when logs exist  
- Register under Benchmarks in `mkdocs.yml` (Overview + Results)

## 6. Wire orchestration

Update `scripts/run-all-benchmarks.sh` to invoke the new runner.

Auto-discovers timestamped CSVs under `logs/<lang>/`; or pass:

```bash
analyze-benchmarks --logs go=logs/go
```

- Update `_KNOWN_LANGS` in `analysis/src/benchmark_analysis/cli.py` so `--compare-a/--compare-b` and path inference recognize the new id.  
- Extend `generate_language_results_pages` / `_LANG_*` maps in `reports.py` (and `_LANG_DOCS_DIR`) if the docs folder id differs from the language id (e.g. `csharp` → `docs/c-sharp/`).

## 7. Tests

At least: smoke run produces non-empty CSV; times positive; required columns present.
