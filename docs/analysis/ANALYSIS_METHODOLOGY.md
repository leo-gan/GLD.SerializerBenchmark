# Benchmark Analysis Methodology

This document describes the statistical methods and data processing pipeline used in the serializer benchmark analysis.

## Overview

The benchmark analysis tool processes raw CSV logs from C# and Python benchmark runs, normalizes time units, filters outliers, and generates comparative reports. The goal is to provide accurate, comparable performance metrics across different serializers and languages.

## Data Pipeline

### 1. Raw Data Ingestion

Benchmark logs are CSV files with the following columns:

- `StringOrStream`: Mode of operation (Stream/string/bytes)
- `TestDataName`: Type of test data (Integer, Person, SimpleObject, etc.)
- `Repetitions`: Number of repetitions in the batch
- `RepetitionIndex`: Index within the repetition batch
- `SerializerName`: Name of the serializer being tested
- `TimeSer`: Time for serialization (ticks for C#, nanoseconds for Python)
- `TimeDeser`: Time for deserialization (ticks for C#, nanoseconds for Python)
- `Size`: Size of serialized output in bytes
- `TimeSerAndDeser`: Combined time for serialization + deserialization
- `OpPerSecSer`, `OpPerSecDeser`, `OpPerSecSerAndDeser`: Operations per second (as reported by benchmark)

### 2. Time Unit Normalization

C# and Python benchmarks use different time units:

- **C#**: Uses ticks (100 nanoseconds per tick)
- **Python**: Uses nanoseconds directly

The `_detect_time_unit()` function auto-detects the unit based on magnitude:

- Values > 1,000,000 are assumed to be C# ticks → multiplied by 100 to get nanoseconds
- Values ≤ 1,000,000 are assumed to be Python nanoseconds → used as-is

This ensures all timing comparisons are done in consistent nanosecond units.

### 3. Outlier Filtering

Raw benchmark data often contains extreme outliers due to:

- GC pauses
- Thread scheduling delays
- JIT compilation overhead (first-run effects)
- System load spikes

These outliers can severely skew mean calculations. For example, a single 90-second measurement among 99 sub-millisecond measurements would make the mean useless.

#### Tukey's IQR Method

We use Tukey's Interquartile Range (IQR) fences for outlier detection:

```
Q1 = 25th percentile
Q3 = 75th percentile
IQR = Q3 - Q1

Lower fence = Q1 - 1.5 × IQR
Upper fence = Q3 + 1.5 × IQR

Values outside [lower, upper] are considered outliers and removed.
```

#### Filtering Rules

- Applied per group: (SerializerName, TestDataName, StringOrStream)
- Only applied when group has ≥ 10 measurements
- If IQR is 0 (all identical values), no filtering is done
- If filtering would remove all values, original data is preserved

#### Warmup Exclusion

Before IQR filtering, the first repetition (RepetitionIndex 0) of each test group is excluded from analysis. This warmup run typically contains:

- **JIT compilation overhead**: First-time code compilation (especially in C#)
- **Static initialization**: Type constructors and static field initialization
- **Cache cold starts**: Cold CPU caches, branch predictors, and TLB

These warmup effects can be 10-100× slower than steady-state performance and often blend into the Q3 tail, reducing IQR filter effectiveness. By excluding RepetitionIndex 0 before filtering, we ensure:

1. More accurate baseline for IQR calculation (Q1, Q3, IQR)
2. Better detection of true runtime outliers (GC pauses, thread delays)
3. Representative performance metrics for production scenarios

| Metric | Tracking |
|--------|----------|
| `runs_raw` | Original count before warmup exclusion |
| `warmup_skipped` | Count of RepetitionIndex 0 excluded |
| `outliers_removed` | Count of IQR-filtered outliers |
| `runs` | Final count after all filtering |

#### Example Impact

| Serializer | Data Type | Mode | Before Outliers (ns) | After Filtering (ns) | Improvement |
|------------|-----------|------|---------------------|---------------------|-------------|
| FlatSharp | Integer | string | 911,721,849 | 9,686 | ~94,000× |
| Ceras | Integer | string | ~6,870,000 | 69,524 | ~99× |
| Jil | Person | string | ~1,370,000 | 62,582 | ~22× |

### 4. Statistics Computation

After filtering, the following metrics are computed per group:

| Metric | Description |
|--------|-------------|
| `avg_time_ser_ns` | Mean serialization time (nanoseconds) |
| `avg_time_deser_ns` | Mean deserialization time (nanoseconds) |
| `avg_time_total_ns` | Mean total time (nanoseconds) |
| `avg_ops_per_sec` | Operations per second (1e9 / avg_time_total_ns) |
| `min_ops_per_sec` | Min ops/sec (from max time) |
| `max_ops_per_sec` | Max ops/sec (from min time) |
| `median_size_bytes` | Median serialized size |
| `runs` | Count of measurements after all filtering |
| `runs_raw` | Original count before warmup exclusion |
| `warmup_skipped` | Count of warmup (RepetitionIndex 0) excluded |
| `outliers_removed` | Count of IQR-filtered outliers |

Ops/Sec is recalculated consistently using `1e9 / nanoseconds` for both languages, ensuring comparability.

### Pivot Tables
Tabular views of performance metrics organized by:

- Rows: Serializers
- Columns: Modes or Data Types
- Values: Avg time or Ops/Sec

## Visualization

### Violin Plots

The HTML dashboard includes violin plots showing the distribution of serialization vs deserialization times per data type. These use seaborn's `catplot(kind='violin', split=True)` to show:
- Top side: Serialize operation distribution
- Bottom side: Deserialize operation distribution

This reveals performance characteristics that averages hide, such as:
- Bimodal distributions (suggesting different code paths)
- Variance within serializers
- Outliers that passed the IQR filter

## Report Generation

### Markdown Summary
- Pivot tables in GitHub-flavored markdown

## Validation

To verify the analysis is working correctly:

1. Check outlier counts: Look for the console output showing how many outliers were removed
2. Cross-check pivot tables: Serializer × Mode tables should show reasonable consistency
3. Compare with notebook: Results should align with the Jupyter notebook analysis
4. Sanity check extreme values: No serializer should show >1 second average times for simple objects

## References

- Tukey, J.W. (1977). *Exploratory Data Analysis*
- [Seaborn.catplot](https://seaborn.pydata.org/generated/seaborn.catplot.html)


## 5. Multi-language & scientific extensions (v2)

As of the v2 harness refactor (`config/benchmark_config.yaml`):

### Languages

Analysis accepts logs from any language directory under `logs/<lang>/benchmark-log.csv` with an optional `Language` column. New runners (**Rust**, **C**, **JavaScript**) emit **nanoseconds** directly. C# still emits **ticks** (×100 → ns), detected via `Language=csharp` or magnitude heuristic.

### Extended metrics (per group)

| Metric | Description |
|--------|-------------|
| `total_mean_ns` / `total_median_ns` | Central tendency |
| `total_std_ns` / `total_mad_ns` / `total_cv` | Dispersion (MAD = median absolute deviation; CV = std/mean) |
| `total_p5_ns` … `total_p99_ns` | Percentiles |
| `total_ci_low_ns` / `total_ci_high_ns` | Percentile bootstrap CI on the **mean** (default 95%, 2000 resamples, seed 42) |
| `effect_vs_fastest_cliffs_delta` | Cliff's δ vs fastest serializer in (language, data, mode) |
| `effect_vs_fastest_hedges_g` | Hedges' g (bias-corrected) vs fastest |
| `fastest_in_group` | Reference serializer name |

### Version comparison (serializer authors)

```bash
analyze-benchmarks --compare-a path/to/old.csv --compare-b path/to/new.csv --output-dir reports
```

Produces `VERSION_COMPARE.md` with Mann–Whitney U, Holm-adjusted p-values, Cliff's δ, Hedges' g, and percent change. This is the recommended path for **old vs new version of the same serializer**.

### Configuration

All thresholds (IQR k, bootstrap iterations, alpha, modes) are centralized in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml) under `statistics:` and `modes:`.

### Limitations (honest assessment)

1. **Cross-language absolute comparisons** are directional only: GC, allocator, and runtime differ. Prefer within-language ranks and effect sizes.
2. **C harness** defaults to portable minimal codecs (library-named wrappers) unless real C libraries are vendored — document this in papers.
3. **Rust rkyv/prost/minicbor** entries may use intermediate payloads for untagged multi-type fixtures; upgrade to generated types for schema-format papers.
4. **Stream mode** is not always a true incremental API (some languages buffer then write); interpret stream columns carefully.
5. **Fidelity** checks are semantic/structural, not bit-identical across formats (datetime/float representations vary).
