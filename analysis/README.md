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
analyze-benchmarks

# Use a specific historical run
analyze-benchmarks --logs rust=logs/rust/2026-06-12-123415.csv

# Shorthands work too
analyze-benchmarks --logs rust:2026-06-12  # partial timestamp match
analyze-benchmarks --logs rust:latest       # latest under logs-root
analyze-benchmarks -l rust --logs logs/rust # directory → picks latest

# List all available result files
analyze-benchmarks --list

# Extra language (future harnesses)
analyze-benchmarks --logs go=logs/go

# Compare two runs (great for serializer code experiments)
analyze-benchmarks --compare-a csharp:190424 --compare-b csharp:191316

# Check for regressions (against saved baseline)
analyze-benchmarks --check-regression --regression-threshold 5

# Save current full run as new baseline
analyze-benchmarks --save-baseline
```

### Full benchmark + analysis workflow

```bash
# Run full (100 reps) benchmarks for all languages and save as baseline
./scripts/run-all-benchmarks.sh -m full -b

# Process the data: stats, outliers, plots, summaries, and per-language pages
cd analysis
uv run analyze-benchmarks

# Typical output for a full run:
#   Loaded 35200 csharp records -> 352 stat groups
#   ...
#   Total: 88400 records, 884 stat groups
#   Generated 32 violin plots
```

You can also run the orchestrator without `-b` and save baseline separately.

#### Example regression output

```
REGRESSION: 234 entries exceeded threshold
  REGRESSION: rmp-serde on Telemetry (bytes) - 18.6% slower (1,391ns → 1,650ns, CI low 1,636ns)
  REGRESSION: sonic-rs on Telemetry (stream) - 28.2% slower (4,554ns → 5,836ns, CI low 5,829ns)
  ...
```

(The tool uses the full statistical pipeline: IQR filtering, bootstrap CIs, and optional hypothesis testing.)
```

Reports are written to `reports/` (gitignored). Documentation snapshots go to `docs/` for the MkDocs site.

| Flag | Description |
|------|-------------|
| `--logs-root` | Root logs directory (default: repo `logs/`) |
| `--logs SPEC` | Log override (repeatable): `LANG=PATH`, bare path with `-l`, or `LANG:stamp` |
| `-l` / `--language LANG` | Only generate for one language (repeatable) |
| `--skip-generate` | Skip docs/plots (for compare/regression-only runs) |
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

records, skipped = parse_csv_file('logs/rust/2026-06-12-123415.csv', language_hint='rust')
stats = compute_statistics(records, language_hint='rust')
```

See [docs/analysis/ANALYSIS_METHODOLOGY.md](../docs/analysis/ANALYSIS_METHODOLOGY.md) for statistics details (site docs). Internal review notes (not published on the site): [CRITIQUE_AND_IMPROVEMENTS.md](CRITIQUE_AND_IMPROVEMENTS.md).
