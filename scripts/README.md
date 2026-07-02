# Benchmark runner scripts

Scripts for running harnesses and analysis **locally**. GitHub Actions may smoke-test harnesses, but **never** regenerates result tables or plots for documentation — those are committed under `docs/analysis/` after a local `analyze-benchmarks` run.

Each benchmark run creates timestamped result files (`YYYY-MM-DD-HHMMSS.csv`) plus environment metadata sidecars (`*.environment.json`). Runs are never overwritten.

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

Each benchmark run creates a timestamped `YYYY-MM-DD-HHMMSS.csv` file — results are never overwritten. When run via `run-all-benchmarks.sh`, all languages share the same timestamp.

**Usage (after installing analysis package):**
```bash
cd analysis && pip install -e .   # once

# Generate reports (auto-discovers latest result per language)
analyze-benchmarks --generate-summary --generate-plots

# List all available result files
analyze-benchmarks --list

# Use a specific run
analyze-benchmarks --rust-logs rust:2026-06-12 --generate-summary

# Compare two runs (great for serializer experiments)
analyze-benchmarks --compare-a rust:2026-06-11 --compare-b rust:2026-06-12
```

| Argument | Description |
|----------|-------------|
| `--logs-root PATH` | Root logs directory |
| `--csharp-logs` / `--python-logs` / ... | CSV path, directory, or shorthand (`rust:2026-06-12`, `rust:latest`) |
| `--extra-logs lang=path` | Additional languages (repeatable) |
| `--generate-summary` | Generate Markdown summary |
| `--generate-plots` | Generate violin plot images |
| `--compare-a` / `--compare-b` | Compare two result files (path, dir, or shorthand) |
| `--check-regression` | Check for regressions against baseline |
| `--regression-threshold PCT` | Regression threshold percentage |
| `--baseline-file PATH` | Path to baseline JSON file |
| `--save-baseline` | Save current results as baseline |
| `--config PATH` | Master `benchmark_config.yaml` |
| `--list` | List available result files per language |

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
| **Published site snapshot** | Tables + plots on GitHub Pages | **`docs/<lang>/results.md`** + **`docs/analysis/plots/violin/*.png`** (indexes under `docs/analysis/`) — generate locally and commit |
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
