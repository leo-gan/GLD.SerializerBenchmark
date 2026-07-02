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

After installation, the `analyze-benchmarks` command is available. Each benchmark run creates a timestamped file like `2026-06-12-123415.csv` — runs are never overwritten. By default analysis auto-discovers the **latest** timestamped result per language.

```bash
# Generate reports (uses latest result per language automatically)
analyze-benchmarks --generate-summary --generate-plots

# Use a specific historical run
analyze-benchmarks --rust-logs logs/rust/2026-06-12-123415.csv --generate-summary

# Shorthands work too
analyze-benchmarks --rust-logs rust:2026-06-12 --generate-summary  # partial timestamp match
analyze-benchmarks --rust-logs rust:latest --generate-summary       # latest timestamped file
analyze-benchmarks --rust-logs logs/rust --generate-summary         # directory → picks latest

# List all available result files
analyze-benchmarks --list

# Extra language (future harnesses)
analyze-benchmarks --extra-logs go=logs/go --generate-summary

# Compare two runs (great for serializer code experiments)
analyze-benchmarks --compare-a rust:2026-06-11 --compare-b rust:2026-06-12

# Check for regressions
analyze-benchmarks --check-regression --regression-threshold 10

# Save new baseline
analyze-benchmarks --save-baseline
```

Reports are written to `reports/` (gitignored). Documentation snapshots go to `docs/` for the MkDocs site.

| Flag | Description |
|------|-------------|
| `--logs-root` | Root logs directory (default: repo `logs/`) |
| `--csharp-logs` / `--python-logs` / ... | CSV path, directory, or shorthand (e.g. `rust:2026-06-12`) |
| `--extra-logs` | `lang=path` pairs (repeatable) |
| `--generate-summary` | Write Markdown summary |
| `--generate-plots` | Write violin plots under `reports/plots/violin/` |
| `--compare-a` / `--compare-b` | Compare two result files (path, dir, or shorthand) |
| `--check-regression` / `--save-baseline` / `--baseline-file` / `--regression-threshold` | Regression gates |
| `--config` | Path to `benchmark_config.yaml` |
| `--list` | List available result files per language |

## Environment Capture

Each benchmark run also captures hardware/OS/runtime metadata as a sidecar file (`*.environment.json`) beside the result CSV. This records CPU model, core count, RAM, runtime versions, git commit, etc.

```python
from benchmark_analysis import capture_environment, load_environment

# Capture (done automatically by harnesses)
capture_environment("logs/rust/2026-06-12-123415.csv")

# Load when analyzing
env = load_environment("logs/rust/2026-06-12-123415.csv")
print(env["cpu"]["model"], env["memory"]["total_bytes"])
```

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
│       ├── regression.py
│       └── environment.py
├── pyproject.toml
└── README.md
```

## API Usage

```python
from benchmark_analysis import parse_csv_file, compute_statistics

records = parse_csv_file('logs/rust/2026-06-12-123415.csv', language_hint='rust')
stats = compute_statistics(records, language_hint='rust')
```

See [docs/analysis/ANALYSIS_METHODOLOGY.md](../docs/analysis/ANALYSIS_METHODOLOGY.md) for statistics details (site docs). Internal review notes (not published on the site): [CRITIQUE_AND_IMPROVEMENTS.md](CRITIQUE_AND_IMPROVEMENTS.md).
