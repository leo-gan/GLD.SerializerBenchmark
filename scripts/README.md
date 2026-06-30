# Benchmark runner scripts

Scripts for running harnesses and analysis **locally**. GitHub Actions may smoke-test harnesses, but **never** regenerates result tables or plots for documentation — those are committed under `docs/analysis/` after a local `analyze-benchmarks` run.

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
| `-p, --plots` | Generate violin plots (`--generate-plots`) |
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

# Full benchmarks with reports (writes to reports/ by default; gitignored)
./scripts/run-all-benchmarks.sh --mode full --plots --summary

# Local regression check
./scripts/run-all-benchmarks.sh --mode all-single --regression-check --threshold 15

# Save new baseline after intentional performance improvements
./scripts/run-all-benchmarks.sh --mode all-single --save-baseline
```

### `analyze-benchmarks`

Console script from the `analysis/` package. Analyzes benchmark CSV outputs and generates reports.

**Usage (after installing analysis package):**
```bash
cd analysis && pip install -e .   # once
# Throwaway local output (gitignored):
analyze-benchmarks \
    --generate-summary \
    --generate-plots \
    --output-dir reports/
# Snapshot for GitHub Pages (commit docs/analysis/** after review):
analyze-benchmarks \
    --generate-summary \
    --generate-plots \
    --output-dir ../docs/analysis
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
| Raw CSVs | Benchmark timing data (gitignored) | `logs/<lang>/` |
| Markdown Summary (local) | Tabular results while iterating | `reports/BENCHMARK_SUMMARY.md` (gitignored) |
| Violin plots (local) | Per-language/data charts while iterating | `reports/plots/violin/` (gitignored) |
| **Published site snapshot** | Tables + plots on GitHub Pages | **`docs/analysis/`** (`BENCHMARK_SUMMARY.md`, `violin-plots.md`, `plots/violin/*.png`) — generate locally and commit |
| Baseline JSON | Performance baseline | `baseline.json` (or path you pass) |

Publish path for documentation:

```bash
analyze-benchmarks --generate-summary --generate-plots --output-dir docs/analysis
git add docs/analysis && git commit -m "docs: refresh benchmark snapshot"
```

CI does not write these files.

## Modes (shared)

| Mode | Repetitions | Source of truth |
|------|-------------|-----------------|
| `smoke` | 2 | `config/benchmark_config.yaml` → `modes` |
| `all-single` | 10 | same |
| `full` | 100 | same |
| `research` | 500 | same |
