# Analysis Documentation

This folder contains documentation for the benchmark analysis system.

## Files

- **[Analysis Methodology](./ANALYSIS_METHODOLOGY.md)** - Detailed description of the statistical methods, data pipeline, and algorithms used in the benchmark analysis.

## Quick Reference

### Running Analysis

```bash
cd analysis
uv run analyze-benchmarks --generate-dashboard --generate-summary
```

### Key Components

| File | Purpose |
|------|---------|
| `src/benchmark_analysis/stats.py` | Statistics computation with outlier filtering |
| `src/benchmark_analysis/reports.py` | Markdown and HTML report generation |
| `src/benchmark_analysis/cli.py` | Command-line interface |

### Output Locations

- `reports/BENCHMARK_SUMMARY.md` - Markdown summary report
- `reports/dashboard/index.html` - Interactive HTML dashboard
- `reports/dashboard/violin_*.png` - Violin plot visualizations
