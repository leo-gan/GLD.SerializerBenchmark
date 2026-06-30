# CI Integration Scripts

This directory contains scripts for integrating serializer benchmarks into your CI/CD pipeline.

## Scripts

### `run-all-benchmarks.sh`

Unified benchmark runner for **all enabled languages** (C#, Python, Rust, C, JavaScript). Modes and paths follow [`config/benchmark_config.yaml`](../config/benchmark_config.yaml).

**Usage:**
```bash
./scripts/run-all-benchmarks.sh [OPTIONS]
```

**Options:**

| Flag | Description |
|------|-------------|
| `-m, --mode MODE` | `smoke`, `all-single`, `full`, or `research` (default: `all-single`) |
| `-l, --lang LANG` | Only run one language: `csharp` \| `python` \| `rust` \| `c` \| `javascript` |
| `-d, --dashboard` | Generate plots dashboard (`--generate-plots`) |
| `-s, --summary` | Generate Markdown summary report |
| `-r, --regression-check` | Check for performance regressions |
| `-t, --threshold PERCENT` | Regression threshold (default: 10%) |
| `-b, --save-baseline` | Save current results as baseline |
| `-h, --help` | Show help message |

**Examples:**
```bash
# Quick smoke test (all languages)
./scripts/run-all-benchmarks.sh --mode smoke

# One language only
./scripts/run-all-benchmarks.sh --mode full --lang rust

# Full benchmarks with reports
./scripts/run-all-benchmarks.sh --mode full --dashboard --summary

# CI check with regression detection
./scripts/run-all-benchmarks.sh --mode all-single --regression-check --threshold 15

# Save new baseline after intentional performance improvements
./scripts/run-all-benchmarks.sh --mode all-single --save-baseline
```

### `analyze-benchmarks`

Console script from the `analysis/` package. Analyzes benchmark CSV outputs and generates reports.

**Usage (after installing analysis package):**
```bash
cd analysis && pip install -e .   # once
analyze-benchmarks \
    --generate-summary \
    --generate-plots \
    --output-dir reports/
```

Auto-discovers `logs/<lang>/benchmark-log.csv`. Explicit flags:

| Argument | Description |
|----------|-------------|
| `--logs-root PATH` | Root logs directory |
| `--csharp-logs PATH` | C# benchmark CSV |
| `--python-logs PATH` | Python benchmark CSV |
| `--rust-logs PATH` | Rust benchmark CSV |
| `--c-logs PATH` | C benchmark CSV |
| `--javascript-logs PATH` | JavaScript benchmark CSV |
| `--extra-logs lang=path` | Additional languages (repeatable) |
| `--output-dir DIR` | Output directory for reports |
| `--generate-plots` | Generate violin plot images |
| `--generate-dashboard` | Alias for `--generate-plots` |
| `--generate-summary` | Generate Markdown summary |
| `--compare-a` / `--compare-b` | Version A/B CSV compare |
| `--check-regression` | Check for regressions against baseline |
| `--regression-threshold PCT` | Regression threshold percentage |
| `--baseline-file PATH` | Path to baseline JSON file |
| `--save-baseline` | Save current results as baseline |
| `--config PATH` | Master `benchmark_config.yaml` |

### `verify-results.sh`

Lightweight check on C# log presence (legacy helper). Prefer language smoke modes for full validation.

## Baseline Management

Baselines are stored as JSON files with the format:
```json
{
  "SerializerName|TestData|Mode": {
    "avg_time_total_ns": 12345,
    "avg_ops_per_sec": 10000,
    "median_size_bytes": 256
  }
}
```

**Creating a baseline:**
```bash
./scripts/run-all-benchmarks.sh --mode all-single --save-baseline
```

## Outputs

| Output | Description | Location |
|--------|-------------|----------|
| Raw CSVs | Benchmark timing data | `logs/csharp/`, `logs/python/`, `logs/rust/`, `logs/c/`, `logs/javascript/` |
| Markdown Summary | Tabular results | `reports/BENCHMARK_SUMMARY.md` |
| Violin plots | Per-language/data charts | `reports/dashboard/` (or docs site copies under `docs/analysis/dashboard/`) |
| Baseline JSON | Performance baseline | `baseline.json` (or path you pass) |

## Modes (shared)

| Mode | Repetitions | Source of truth |
|------|-------------|-----------------|
| `smoke` | 2 | `config/benchmark_config.yaml` → `modes` |
| `all-single` | 10 | same |
| `full` | 100 | same |
| `research` | 500 | same |
