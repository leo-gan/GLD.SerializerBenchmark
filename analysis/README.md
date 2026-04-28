# Benchmark Analysis

Python package for analyzing serializer benchmark results.

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

After installation, the `analyze-benchmarks` command is available:

```bash
# Generate dashboard and summary
analyze-benchmarks \
    --csharp-logs logs/csharp/benchmark-log.csv \
    --python-logs logs/python/benchmark-log.csv \
    --output-dir reports/ \
    --generate-dashboard \
    --generate-summary

# Check for regressions
analyze-benchmarks \
    --csharp-logs logs/csharp/benchmark-log.csv \
    --python-logs logs/python/benchmark-log.csv \
    --check-regression \
    --regression-threshold 10 \
    --baseline-file baseline.json

# Save new baseline
analyze-benchmarks \
    --csharp-logs logs/csharp/benchmark-log.csv \
    --python-logs logs/python/benchmark-log.csv \
    --save-baseline \
    --baseline-file baseline.json
```

## Package Structure

```
analysis/
├── src/
│   └── benchmark_analysis/
│       ├── __init__.py       # Package exports
│       ├── cli.py            # Main entry point
│       ├── parser.py         # CSV parsing
│       ├── stats.py          # Statistics computation
│       ├── reports.py        # HTML/Markdown report generation
│       └── regression.py     # Baseline comparison
├── scripts/                  # Helper scripts (future)
├── pyproject.toml            # Package configuration
└── README.md                 # This file
```

## API Usage

```python
from benchmark_analysis import parse_csv_file, compute_statistics, generate_markdown_summary

# Parse CSV records
records = parse_csv_file('logs/csharp/benchmark-log.csv')

# Compute statistics
stats = compute_statistics(records)

# Generate report
generate_markdown_summary(stats, {}, 'reports/summary.md')
```
