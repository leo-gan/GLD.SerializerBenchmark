# Adding a language

This page is a **checklist for implementers**. Follow it when you want a new programming language in the suite without changing the shared analysis core.

Background (layout, timing model, contract): [Benchmark architecture](architecture.md).  
Test data: [Test data](test_data_configuration.md).  
How CSVs become tables: [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Learning goals

After this page you should be able to:

1. Register a language in the master config.
2. Implement a benchmark runner that writes a valid CSV and respects the timing rules.
3. Hook the runner into scripts, documentation, and continuous integration.

---

## 1. Register the language

Edit **`config/benchmark_config.yaml`**. That file is read by `scripts/read-config.py`, `scripts/run-all-benchmarks.sh`, and `analyze-benchmarks`.

```yaml
languages:
  go:  # example id — use a short lowercase id
    display_name: Go
    enabled: true
    runner_dir: go
    runner_script: scripts/run-benchmarks.sh
    log_dir: logs/go
    time_unit: nanoseconds
    docs_dir: docs/go
    serializers: [...]
```

If your config uses `paths.language_log_dirs`, add an entry such as `go: logs/go`.

---

## 2. Implement the benchmark runner contract

Meet the [benchmark runner contract](architecture.md#harness-contract-summary) and [measurement model](architecture.md#measurement-model). In particular:

| Requirement | Detail |
|-------------|--------|
| Output CSV | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with columns from `csv_schema` |
| `Language` column | Must match the language id (for example `go`) |
| Time unit | **Nanoseconds** for all runners (including C#) |
| Modes | `bytes` and `stream` (or `string` / `stream` if matching legacy C#) |
| Warmup | Log repetition index 0; analysis excludes it from aggregates |
| Prepare outside the loop | Schema compile, type registration, buffer pools, bind data-type encode function — not timed |
| Timed section | Serialize and deserialize only |
| Output buffer | Runner-owned / pre-sized buffer reused across reps — see [timing rules](architecture.md#timing-methodology-suite-wide-issue-59) |
| Optimization barriers | `black_box` / `DoNotOptimize` / `KeepAlive` (or equivalent) on timed I/O for native compilers |
| Fidelity | Semantic round-trip check; write `logs/<lang>/<ts>.errors.csv` only when errors occur |
| Optional sidecars | `*.configs.json` (environment plus optional dataset / serializer metadata) |
| Seed | Master config `reproducibility.random_seed` / `BENCHMARK_SEED`; document the PRNG and any magic constants |

---

## 3. Test data types

Implement `make_one` (or the language equivalent) and run-config **cells** for the suite type ids:

`message` · `document` · `telemetry` · `strings` · `event`

See [Test data](test_data_configuration.md) for field shapes and batch rules.

- Expand cells with `./scripts/resolve_run_config.py`.
- Emit CSV columns `DataTypeInstanceCount` and `TypeConfigHash` when measuring batch cells.
- Generators live under each language tree (for example `python/.../data_v2`, `go/model/v2`, `rust/src/data_v2.rs`, `javascript/src/data_v2.js`).
- Wire schemas: `schemas/v2/` and `scripts/schemas/generate-all.sh`.
- Catalog defaults: `schemas/data_catalog_v2.yaml`.

---

## 4. Runner script

`runner_dir/scripts/run-benchmarks.sh` must accept modes:

`smoke` | `all-single` | `full` | `research`

Source `scripts/lib/config.sh` and use `bench_mode_reps "$MODE"` (reads `modes.<name>.repetitions`). Set `BENCHMARK_SEED` from `bench_random_seed`. Do **not** hard-code repetition counts.

---

## 5. Documentation

- `docs/<lang>/index.md` — ecosystem overview, registered inventory, caveats.
- After benchmarks: run `analyze-benchmarks` so `docs/<lang>/results.md` can be produced when logs exist.
- Register Overview and Results under the language tab (and Benchmarks if needed) in `mkdocs.yml`.

---

## 6. Wire orchestration

Update `scripts/run-all-benchmarks.sh` if it does not already pick up `languages.*.enabled` automatically.

Analysis auto-discovers timestamped CSVs under `logs/<lang>/`. You can also pass explicit paths:

```bash
analyze-benchmarks --logs go=logs/go
```

Also check:

- `_KNOWN_LANGS` fallbacks and aliases in `analysis/` if config is unreadable.
- `generate_language_results_pages` / language maps in `reports.py` (and docs-dir maps) when the docs folder id differs from the language id (for example `csharp` → `docs/c-sharp/`).
- Host scripts: `scripts/check-host-requirements.sh`, `scripts/install-host-requirements.sh`.
- Prepare-PR language detect: `.grok/skills/prepare-pr/scripts/detect-changed-langs.sh`.

---

## 7. GitHub Actions (required)

Update **`.github/workflows/benchmark-ci.yml`**:

1. `changes` job outputs and a `dorny/paths-filter` entry for `runner_dir/**` (and `schemas/**` if shared test data apply).
2. A new `*-benchmark` job: install the toolchain, run `check-host-requirements.sh <id>`, run `./scripts/run-benchmarks.sh` (smoke by default).
3. Analysis smoke step: assert the new id appears in `--enabled-langs` / `--lang-runners`.

Without this, pull requests that only touch the new benchmark runner never run it in CI.

---

## 8. Tests

At minimum:

- A smoke run produces a non-empty CSV.
- Times are positive.
- Required columns are present.
