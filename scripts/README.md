# Benchmark runner scripts

Scripts for running harnesses and analysis **locally**. GitHub Actions may smoke-test harnesses, but **never** regenerates result tables or plots for documentation — those are committed under `docs/analysis/` after a local `analyze-benchmarks` run.

Each benchmark run creates timestamped artifacts with the **same stem** (never overwritten):

- `YYYY-MM-DD-HHMMSS.csv` — timings
- `YYYY-MM-DD-HHMMSS.errors.csv` — fidelity / harness failures (only when errors occur)
- `YYYY-MM-DD-HHMMSS.configs.json` — run config + environment sidecar
- `YYYY-MM-DD-HHMMSS.environment.json` — older env-only sidecar (still loaded if present)

## Scripts

### `resolve_run_config.py`

Expand a **run config** into resolved cells (type_id × type_config × `data_type_instance_count`):

```bash
./scripts/resolve_run_config.py config/library/default.yaml --pretty
./scripts/resolve_run_config.py config/library/smoke.yaml --seed 42
```

Catalog: `schemas/data_catalog_v2.yaml`. Docs: `docs/analysis/test_data_configuration.md`.

### Schema codegen (`scripts/schemas/`)

```bash
./scripts/schemas/generate-all.sh      # protoc (and future IDLs) → language artifacts
./scripts/schemas/check-generated.sh   # drift check for CI
```

Sources: `schemas/v2/`.

### `read-config.py` / `lib/config.sh`

```bash
./scripts/read-config.py --mode-reps full
./scripts/read-config.py --enabled-langs
./scripts/read-config.py --lang-runners
./scripts/read-config.py --seed
source scripts/lib/config.sh && bench_mode_reps smoke
```

Language `run-benchmarks.sh` scripts source `lib/config.sh` so mode repetition counts and `BENCHMARK_SEED` match the YAML.

### `run-all-benchmarks.sh`

Unified runner for **enabled languages** in [`config/benchmark_config.yaml`](../config/benchmark_config.yaml).

```bash
./scripts/run-all-benchmarks.sh [OPTIONS]
```

| Flag | Description |
|------|-------------|
| `-m, --mode MODE` | `smoke`, `all-single`, `full`, or `research` (default: `all-single`) |
| `-l, --lang LANG` | One language id (`csharp`, `python`, `rust`, `c`, `javascript`, `go`, …) |
| `-a, --analyze` | Generate analysis artifacts via `analyze-benchmarks` |
| `-r, --regression-check` | Check for performance regressions |
| `-t, --threshold PERCENT` | Regression threshold (default from config) |
| `-b, --save-baseline` | Save current results as baseline |
| `-h, --help` | Help |

```bash
./scripts/run-all-benchmarks.sh --mode smoke
./scripts/run-all-benchmarks.sh --mode full --lang rust
./scripts/run-all-benchmarks.sh --mode all-single --regression-check --threshold 15
./scripts/run-all-benchmarks.sh --mode all-single --save-baseline
```

### `analyze-benchmarks`

Console script from the `analysis/` package.

Suite type ids in logs: `message`, `document`, `telemetry`, `strings`, `event`.  
Each run: `YYYY-MM-DD-HHMMSS.{csv,configs.json}` (+ `.errors.csv` only on failures). Orchestrator runs share one timestamp stem.

```bash
cd analysis && pip install -e .

analyze-benchmarks
analyze-benchmarks -l python
analyze-benchmarks --logs rust:2026-06-12
analyze-benchmarks --list
analyze-benchmarks --compare-a rust:2026-06-11 --compare-b rust:2026-06-12
```

| Argument | Description |
|----------|-------------|
| `--logs-root PATH` | Root with `logs/<lang>/` (default: repo `logs/`) |
| `-l` / `--language LANG` | One language (aliases: `py`, `cs`, `js`) |
| `--logs SPEC` | Override: `LANG=PATH`, `LANG:stamp`, `LANG:latest` |
| `--skip-generate` | Skip docs/plots |
| `--compare-a` / `--compare-b` | Compare two runs |
| `--check-regression` / `--save-baseline` / `--baseline-file` / `--regression-threshold` | Regression gates |
| `--config PATH` | Master `benchmark_config.yaml` |
| `--list` | List result files |

### `verify-results.sh`

```bash
./scripts/verify-results.sh
BENCHMARK_TS=2026-07-02-173247 ./scripts/verify-results.sh
./scripts/verify-results.sh go
```

## Baseline management

```bash
./scripts/run-all-benchmarks.sh --mode all-single --save-baseline
```

## Outputs

| Output | Location |
|--------|----------|
| Raw CSVs / sidecars | `logs/<lang>/` (gitignored) |
| Language results + plots | `docs/<lang>/results.md`, violin PNGs under `docs/analysis/plots/` |
| Local iteration plots | `reports/plots/` (gitignored) |
| Baseline JSON | path you pass / config |

```bash
analyze-benchmarks
git add docs/analysis docs/*/results.md && git commit -m "docs: refresh benchmark snapshot"
```

CI does not write these files.

## Modes (shared)

| Mode | Repetitions | Source |
|------|-------------|-----------------|
| `smoke` | 2 | `config/benchmark_config.yaml` → `modes` |
| `all-single` | 10 | same |
| `full` | 100 | same |
| `research` | 500 | same |

Smoke runners typically filter to a cheap cell (e.g. `message`).
