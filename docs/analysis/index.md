# Benchmark Analysis

Statistical analysis tools for comparing serializer performance across C# and Python.

## Overview

The analysis pipeline processes raw CSV logs, normalizes time units, filters outliers, and generates comparative reports with visualizations.

```
Raw Logs (CSV)
    ↓
Time Unit Normalization (ticks → nanoseconds)
    ↓
Warmup Exclusion (RepetitionIndex 0)
    ↓
IQR Outlier Filtering
    ↓
Statistics Computation
    ↓
Report Generation (Markdown + HTML)
```

## Quick Start

```bash
cd analysis
uv run analyze-benchmarks --generate-dashboard --generate-summary
```

## Output

| File | Description |
|------|-------------|
| `reports/BENCHMARK_SUMMARY.md` | Markdown tables and analysis |
| `reports/dashboard/index.html` | Interactive Chart.js dashboard |
| `reports/dashboard/violin_*.png` | Distribution visualizations |

## Key Components

### Statistics Module

```python
from benchmark_analysis.stats import compute_stats, filter_outliers

# Time unit normalization
ns_time = normalize_time_unit(raw_time)

# Outlier filtering
filtered = filter_outliers(data, method='iqr')

# Statistics computation
stats = compute_stats(filtered)
# → avg_time_ser_ns, avg_ops_per_sec, median_size_bytes, etc.
```

### Report Generation

```python
from benchmark_analysis.reports import generate_dashboard, generate_summary

# HTML dashboard with Chart.js
generate_dashboard(stats, output_dir='reports/dashboard')

# Markdown summary
generate_summary(stats, output_file='reports/BENCHMARK_SUMMARY.md')
```

## Statistical Methods

### Time Unit Normalization

| Source | Unit | Conversion |
|--------|------|------------|
| C# | Ticks (100ns) | × 100 → nanoseconds |
| Python | Nanoseconds | Use as-is |

Auto-detection: values > 1,000,000 are C# ticks.

### Tukey's IQR Method

```
Q1 = 25th percentile
Q3 = 75th percentile
IQR = Q3 - Q1

Valid range: [Q1 - 1.5×IQR, Q3 + 1.5×IQR]
```

Applied per group: `(SerializerName, TestDataName, Mode)`

### Warmup Exclusion

The first repetition of each group is excluded before IQR filtering:
- Removes JIT compilation overhead
- Eliminates static initialization effects
- Clears cold cache penalties

## Metrics

| Metric | Description | Units |
|--------|-------------|-------|
| `avg_time_ser_ns` | Mean serialization time | nanoseconds |
| `avg_time_deser_ns` | Mean deserialization time | nanoseconds |
| `avg_time_total_ns` | Mean combined time | nanoseconds |
| `avg_ops_per_sec` | Operations per second | ops/sec |
| `min_ops_per_sec` | Minimum ops/sec | ops/sec |
| `max_ops_per_sec` | Maximum ops/sec | ops/sec |
| `median_size_bytes` | Median payload size | bytes |
| `runs_raw` | Original measurement count | count |
| `warmup_skipped` | Warmup runs excluded | count |
| `outliers_removed` | IQR-filtered measurements | count |

## Dashboard Features

### Charts

- **Performance charts**: Top serializers by ops/sec
- **Pivot tables**: Serializer × mode, serializer × data type
- **Cross-language comparison**: C# vs Python winners

### Violin Plots

Distribution of serialize (top) vs deserialize (bottom) times:
- Reveals bimodal distributions
- Shows variance within serializers
- Identifies remaining outliers

## Validation

Verify analysis correctness:

1. Check outlier counts in console output
2. Cross-check pivot tables for consistency
3. Compare with Jupyter notebook (`Analysis.ipynb`)
4. Sanity check: no >1s averages for simple objects

## CLI Reference

```bash
uv run analyze-benchmarks [OPTIONS]

Options:
  --input-dir PATH        Input directory with CSV logs [default: ../logs]
  --output-dir PATH       Output directory for reports [default: reports]
  --generate-dashboard    Generate HTML dashboard
  --generate-summary      Generate Markdown summary
  --verbose               Enable verbose output
```

## Detailed Documentation

- **[Analysis Methodology](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/main/analysis/docs/ANALYSIS_METHODOLOGY.md)** — Complete statistical methods and data pipeline
- **[Analysis README](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/main/analysis/docs/README.md)** — Component reference and quick start

## Jupyter Notebook

Interactive analysis: `analysis/Analysis.ipynb`

```python
import pandas as pd
from benchmark_analysis.stats import load_logs, compute_stats

# Load data
df = load_logs('../logs')

# Compute statistics
stats = compute_stats(df)

# Visualize
import matplotlib.pyplot as plt
stats.plot(kind='bar')
```

## See Also

- [Methodology](../methodology.md) — High-level methodology overview
- [Benchmark Results](../benchmark-results.md) — View generated reports
- [GitHub Repository](https://github.com/leo-gan/GLD.SerializerBenchmark) — Source code
