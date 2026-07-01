# Analysis methodology

How the `analysis` package turns harness CSVs into group statistics, effect sizes, published **Results** tables, and violin plots. Timing *collection* (what is timed in the harness) is defined in [Benchmark architecture](architecture.md). Defaults live under `statistics:` and `modes:` in [`config/benchmark_config.yaml`](../../config/benchmark_config.yaml).

Regenerate site snapshots **locally** (`analyze-benchmarks --generate-summary --generate-plots --output-dir docs/analysis`); CI does not re-run analysis. Numbers appear on language **Results** pages ([Benchmark Results](BENCHMARK_SUMMARY.md) hub).

## Inputs

| Source | Role |
|--------|------|
| `logs/<lang>/benchmark-log.csv` | Per-language harness output (gitignored) |
| `Language` column | Language id (`csharp`, `python`, `rust`, `c`, `javascript`, …) |
| `csv_schema` in master config | Required/optional columns |

Core columns: `StringOrStream`, `TestDataName`, `Repetitions`, `RepetitionIndex`, `SerializerName`, `TimeSer`, `TimeDeser`, `Size`, `TimeSerAndDeser`, ops/sec fields as emitted by runners. Optional: `MemoryPeakBytes`, `FidelityScore`, `SerializerVersion`, …

Fixtures: [Test data types](test_data_configuration.md). Paradigms: [Serialization Categories](serialization_categories.md).

## Pipeline

Processing is **per group**: `(Language, SerializerName, TestDataName, StringOrStream)` unless noted.

```text
CSV → normalize times to ns → drop warmup → outlier filter → descriptive stats
    → bootstrap CI on mean → effect sizes vs fastest in group
```

### Time units

| Runner | Stored unit | Normalization |
|--------|-------------|---------------|
| New harnesses (Python, Rust, C, JS, …) | Nanoseconds | As-is |
| Legacy C# | Ticks (1 tick = 100 ns) | Prefer `Language=csharp`; else magnitude heuristic (very large values treated as ticks × 100) |

All analysis and published tables use **nanoseconds** (plots often show **µs**).

Ops/sec in reports is derived consistently as **`1e9 / mean_time_ns`** (config: `statistics.throughput_from`), not by trusting mixed runner-reported ops fields across languages.

### Warmup exclusion

If `statistics.exclude_warmup` is true (default), rows with **`RepetitionIndex == 0`** are dropped before outlier filtering and summaries. That removes typical JIT / static-init / cold-cache spikes from aggregates. Count tracked as `warmup_skipped`; `runs_raw` is the pre-warmup size.

Default warmup policy in config also lists `reproducibility.warmup_repetitions` for harness guidance.

### Outlier filtering

Default method: **Tukey IQR** (`statistics.outlier_method: iqr`, `iqr_k: 1.5`).

```text
Q1, Q3 = 25th / 75th percentiles of the group series
IQR = Q3 − Q1
fences = [Q1 − k·IQR, Q3 + k·IQR]
```

| Rule | Default behavior |
|------|------------------|
| Group size | Apply only if ≥ `min_samples_for_outlier_filter` (10) |
| IQR = 0 | No removal |
| Would drop entire group | Keep original series |
| Method `none` | Skip filtering |

Removed count: `outliers_removed`. Final sample size: `runs`.

IQR reduces the impact of rare GC/scheduling stalls on the **mean**; it is not a substitute for reporting dispersion and CIs.

### Descriptive statistics (per group)

After filtering, analysis records (names as in code / optional extended fields):

| Kind | Metrics |
|------|---------|
| Central tendency | Mean and median of ser / deser / total times (`avg_*` / `total_mean_ns` / `total_median_ns`) |
| Dispersion | Std, MAD, CV, min/max, percentiles (default 5, 25, 50, 75, 95, 99) |
| Size | Median serialized `Size` (bytes) |
| Throughput | Ops/s from mean total time (see above) |
| Provenance | `runs`, `runs_raw`, `warmup_skipped`, `outliers_removed` |

Exact keys depend on the analysis version; published markdown pivots emphasize mean total time and ops/s by serializer × mode or × fixture.

### Bootstrap CI on the mean

When `statistics.bootstrap.enabled` (default): **percentile** bootstrap on the group’s total-time series (`iterations` 2000, `confidence_level` 0.95, `seed` 42). Yields `total_ci_low_ns` / `total_ci_high_ns` around the mean. Non-parametric; does not assume normality.

### Effect sizes vs fastest in group

When `statistics.effect_sizes.enabled` (default), within the same language, fixture, and I/O mode, each serializer is compared to the **fastest** (lowest mean total time) in that group:

| Method | Role |
|--------|------|
| **Cliff’s δ** | Non-parametric dominance; labels via config thresholds (negligible / small / medium / large) |
| **Hedges’ g** | Bias-corrected standardized mean difference |

Fields such as `effect_vs_fastest_cliffs_delta`, `effect_vs_fastest_hedges_g`, `fastest_in_group` support within-language interpretation—not cross-runtime rankings.

### Version A/B (same serializer, two builds)

```bash
analyze-benchmarks --compare-a old.csv --compare-b new.csv --output-dir reports
```

Writes `VERSION_COMPARE.md` with percent change, Cliff’s δ, Hedges’ g, **Mann–Whitney U**, and **Holm**-adjusted p-values when `statistics.hypothesis_tests` is enabled (`alpha` 0.05). Prefer this for author-facing regressions rather than comparing unrelated libraries.

## Outputs

| Output | Content |
|--------|---------|
| `docs/<lang>/results.md` | Pivot tables + violin embeds for one language |
| `docs/analysis/plots/violin/*.png` | Split violins: serialize vs deserialize distributions (µs; log scale when medians span ≥5×) |
| `docs/analysis/BENCHMARK_SUMMARY.md` | Hub links to language Results |
| Console | Load counts, warmup/outlier tallies |

Violins show spread and multimodality that means hide; they still reflect post-filter samples used for summaries when generated from the same run.

## Limitations

- **Cross-language absolute times** are at best directional (GC, allocator, runtime differ). Prefer within-language ranks and effect sizes.
- **C** default builds may use portable stand-ins under real library names—see [C overview](../c/index.md) before citing as library rankings.
- **Rust** schema/zero-copy rows may use documented intermediate/envelope paths—see [Rust overview](../rust/index.md).
- **Stream** mode is not always a true incremental API (some harnesses buffer then write).
- **Fidelity** is semantic/structural, not bit-identical across formats (e.g. floats/datetimes).
- Outlier removal and warmup policy affect means; always consider `runs`, CIs, and effect sizes.

## References

- Tukey, J.W. (1977). *Exploratory Data Analysis* (IQR fences)
- Cliff’s delta; Hedges’ g; Mann–Whitney U (standard non-parametric toolkit)
- [Seaborn violin / catplot](https://seaborn.pydata.org/generated/seaborn.catplot.html)
