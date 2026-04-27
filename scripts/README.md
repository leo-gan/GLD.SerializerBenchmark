# CI Integration Scripts

This directory contains scripts for integrating serializer benchmarks into your CI/CD pipeline, turning performance measurement into a quality gate.

## Scripts

### `run-all-benchmarks.sh`

Unified benchmark runner for all languages. Coordinates C# and Python benchmark execution with report generation.

**Usage:**
```bash
./scripts/run-all-benchmarks.sh [OPTIONS]
```

**Options:**
| Flag | Description |
|------|-------------|
| `-m, --mode MODE` | Benchmark mode: `smoke`, `all-single`, `full` |
| `-d, --dashboard` | Generate HTML dashboard with visualizations |
| `-s, --summary` | Generate Markdown summary report |
| `-r, --regression-check` | Check for performance regressions |
| `-t, --threshold PERCENT` | Regression threshold (default: 10%) |
| `-b, --save-baseline` | Save current results as baseline |
| `-h, --help` | Show help message |

**Examples:**
```bash
# Quick smoke test
./scripts/run-all-benchmarks.sh --mode smoke

# Full benchmarks with reports
./scripts/run-all-benchmarks.sh --mode full --dashboard --summary

# CI check with regression detection
./scripts/run-all-benchmarks.sh --mode all-single --regression-check --threshold 15

# Save new baseline after intentional performance improvements
./scripts/run-all-benchmarks.sh --mode all-single --save-baseline
```

### `analyze-benchmarks`

Console script from `analysis/` package. Analyzes benchmark CSV outputs and generates reports.

**Usage (after installing analysis package):**
```bash
analyze-benchmarks \
    --csharp-logs logs/csharp/benchmark-log.csv \
    --python-logs logs/python/benchmark-log.csv \
    --output-dir reports/ \
    --generate-dashboard \
    --generate-summary
```

**Arguments:**
| Argument | Description |
|----------|-------------|
| `--csharp-logs PATH` | Path to C# benchmark CSV |
| `--python-logs PATH` | Path to Python benchmark CSV |
| `--output-dir DIR` | Output directory for reports |
| `--generate-dashboard` | Generate HTML dashboard |
| `--generate-summary` | Generate Markdown summary |
| `--check-regression` | Check for regressions against baseline |
| `--regression-threshold PCT` | Regression threshold percentage |
| `--baseline-file PATH` | Path to baseline JSON file |
| `--save-baseline` | Save current results as baseline |

## GitHub Actions Integration

The `.github/workflows/benchmark-ci.yml` workflow provides:

1. **Parallel Benchmark Execution**: Runs C# and Python benchmarks concurrently
2. **Artifact Upload**: Stores raw benchmark results
3. **Report Generation**: Creates HTML dashboard and Markdown summary
4. **Regression Detection**: Optionally fails CI on performance degradation
5. **GitHub Pages Deployment**: Auto-deploys dashboard to Pages
6. **Summary Commit**: Updates `BENCHMARK_SUMMARY.md` in the repository

### Manual Workflow Dispatch

Trigger via GitHub UI with parameters:
- **Mode**: `smoke`, `all-single`, or `full`
- **Fail on regression**: Enable to block on performance regressions
- **Regression threshold**: Percentage slowdown that triggers failure

### Required Secrets/Permissions

For GitHub Pages deployment, ensure:
1. Repository Settings → Pages → Source: GitHub Actions
2. Workflow has `pages: write` and `id-token: write` permissions

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

**Checking against baseline in CI:**
The GitHub workflow supports `fail_on_regression` input. When enabled, the workflow will fail if any serializer is slower than the baseline by the threshold percentage.

## Outputs

| Output | Description | Location |
|--------|-------------|----------|
| Raw CSVs | Benchmark timing data | `logs/csharp/`, `logs/python/` |
| HTML Dashboard | Interactive charts | `reports/dashboard/index.html` |
| Markdown Summary | Tabular results | `reports/BENCHMARK_SUMMARY.md` |
| Baseline JSON | Performance baseline | `baseline.json` |
