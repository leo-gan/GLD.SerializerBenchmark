# Serializer Benchmark Summary

This page is a **placeholder for generated analysis output**.

Do not hand-edit performance tables here. After running benchmarks:

```bash
cd analysis && pip install -e .
analyze-benchmarks --generate-summary --generate-plots --output-dir ../reports
```

Then use `reports/BENCHMARK_SUMMARY.md` (and optionally sync it here for the docs site in CI).

## Methodology (scientific)

See [Analysis Methodology](ANALYSIS_METHODOLOGY.md). Summary of defaults from `config/benchmark_config.yaml`:

- Warmup exclusion (`RepetitionIndex` 0 when repetitions &gt; 1)
- IQR outlier filter (Tukey 1.5×IQR when group size allows)
- Mean / median / std / MAD / CV + bootstrap CI on the mean
- Within-group Cliff's δ / Hedges' g vs fastest serializer in group
- Version A/B: `analyze-benchmarks --compare-a A.csv --compare-b B.csv`

## Languages

Analysis auto-discovers CSV files under `logs/<lang>/benchmark-log.csv` for `csharp`, `python`, `rust`, `c`, and `javascript`.
