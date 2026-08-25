# Benchmark Analysis

Python package for analyzing serializer benchmark results across all language benchmark runners (C#, Python, Rust, C, JavaScript, Go).

## Installation

```bash
cd analysis
uv pip install -e .
# or: pip install -e .
```

## Usage

Each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv` (never overwritten). Analysis picks the **latest** per language by default.

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`.

```bash
analyze-benchmarks
analyze-benchmarks -l python
analyze-benchmarks --logs rust=logs/rust/2026-06-12-123415.csv
analyze-benchmarks --logs rust:2026-06-12
analyze-benchmarks --logs rust:latest
analyze-benchmarks -l rust --logs logs/rust
analyze-benchmarks --list
analyze-benchmarks --compare-a csharp:190424 --compare-b csharp:191316
analyze-benchmarks --check-regression --regression-threshold 5
analyze-benchmarks --save-baseline
```

### Full workflow

```bash
./scripts/run-all-benchmarks.sh -m full -b
cd analysis && uv run analyze-benchmarks
```

| Flag | Description |
|------|-------------|
| `--logs-root` | Root logs directory (default: repo `logs/`) |
| `--logs SPEC` | Log override (repeatable) |
| `-l` / `--language LANG` | One language (repeatable) |
| `--skip-generate` | Skip docs/plots |
| `--compare-a` / `--compare-b` | Compare two runs |
| `--check-regression` / `--save-baseline` / `--baseline-file` / `--regression-threshold` / `--regression-combine` | Regression gates (default **and**: practical % **and** CI; see methodology) |
| `--config` | Path to `benchmark_config.yaml` |
| `--list` | List result files |

## Run config / environment capture

Sidecar `*.configs.json` beside each result CSV (hardware, OS, runtimes, optional dataset/serializer blocks). Older `*.environment.json` files are still loaded.

```python
from benchmark_analysis import capture_environment, load_environment

capture_environment("logs/rust/2026-06-12-123415.csv")
env = load_environment("logs/rust/2026-06-12-123415.csv")
print(env["environment"]["cpu"]["model"])
```

## Package structure

```
analysis/
├── src/benchmark_analysis/
│   ├── cli.py
│   ├── parser.py
│   ├── stats.py
│   ├── reports.py
│   ├── regression.py
│   ├── environment.py
│   ├── run_config_v2.py
│   └── config_loader.py
├── pyproject.toml
└── README.md
```

## API

```python
from benchmark_analysis import parse_csv_file, compute_statistics

records, skipped = parse_csv_file('logs/rust/2026-06-12-123415.csv', language_hint='rust')
stats = compute_statistics(records, language_hint='rust')
```

See [docs/analysis/ANALYSIS_METHODOLOGY.md](../docs/analysis/ANALYSIS_METHODOLOGY.md). Internal notes: [CRITIQUE_AND_IMPROVEMENTS.md](CRITIQUE_AND_IMPROVEMENTS.md).
