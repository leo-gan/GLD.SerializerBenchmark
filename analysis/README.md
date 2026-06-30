# Benchmark Analysis

Python package for analyzing serializer benchmark results across all language harnesses (C#, Python, Rust, C, JavaScript).

## Installation

```bash
cd analysis
uv pip install -e .
```

Or with pip:
```bash
cd analysis
pip install -e .
```

## Usage

After installation, the `analyze-benchmarks` command is available. By default it **auto-discovers** `logs/<lang>/benchmark-log.csv` under the repo `logs/` tree.

```bash
# Generate summary and violin plots (all discovered languages)
analyze-benchmarks \
    --generate-summary \
    --generate-plots \
    --output-dir reports/

# Explicit per-language paths
analyze-benchmarks \
    --csharp-logs logs/csharp/benchmark-log.csv \
    --python-logs logs/python/benchmark-log.csv \
    --rust-logs logs/rust/benchmark-log.csv \
    --c-logs logs/c/benchmark-log.csv \
    --javascript-logs logs/javascript/benchmark-log.csv \
    --output-dir reports/ \
    --generate-summary \
    --generate-plots

# Extra language (future harnesses)
analyze-benchmarks --extra-logs go=logs/go/benchmark-log.csv --generate-summary

# Serializer version A vs B (same schema CSVs)
analyze-benchmarks --compare-a logs/rust/v1.csv --compare-b logs/rust/v2.csv --output-dir reports

# Check for regressions
analyze-benchmarks \
    --check-regression \
    --regression-threshold 10 \
    --baseline-file baseline.json

# Save new baseline
analyze-benchmarks \
    --save-baseline \
    --baseline-file baseline.json
```

| Flag | Description |
|------|-------------|
| `--logs-root` | Root logs directory (default: repo `logs/`) |
| `--csharp-logs` / `--python-logs` / `--rust-logs` / `--c-logs` / `--javascript-logs` | Per-language CSV paths |
| `--extra-logs` | `lang=path` pairs (repeatable) |
| `--output-dir` | Report output directory |
| `--generate-summary` | Write Markdown summary |
| `--generate-plots` | Write violin plot images |
| `--generate-dashboard` | Alias for `--generate-plots` (compat) |
| `--compare-a` / `--compare-b` | Version A/B compare CSVs |
| `--check-regression` / `--save-baseline` / `--baseline-file` / `--regression-threshold` | Regression gates |
| `--config` | Path to `benchmark_config.yaml` |

## Package Structure

```
analysis/
├── src/
│   └── benchmark_analysis/
│       ├── __init__.py
│       ├── cli.py
│       ├── parser.py
│       ├── stats.py
│       ├── reports.py
│       └── regression.py
├── pyproject.toml
└── README.md
```

## API Usage

```python
from benchmark_analysis import parse_csv_file, compute_statistics, generate_markdown_summary

records = parse_csv_file('logs/rust/benchmark-log.csv', language_hint='rust')
stats = compute_statistics(records, language_hint='rust')
generate_markdown_summary({}, {}, 'reports/summary.md', multi_lang_stats=stats, multi_lang_records={'rust': records})
```

See [docs/analysis/ANALYSIS_METHODOLOGY.md](../docs/analysis/ANALYSIS_METHODOLOGY.md) for statistics details.
