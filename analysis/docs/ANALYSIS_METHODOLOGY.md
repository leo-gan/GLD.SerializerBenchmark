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

## Multidimensional Analysis

The analysis goes beyond simple serializer rankings to provide:

### By Data Type
Performance comparison across different data types (Integer, Person, SimpleObject, etc.)

### By Mode
Comparison of Stream vs String/Bytes serialization modes

### Cross-Language
Head-to-head comparison of C# vs Python serializers on the same data types

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

- Human-readable tables of top performers
- Multidimensional analysis sections
- Pivot tables in GitHub-flavored markdown

### HTML Dashboard

- Interactive charts using Chart.js
- Violin plots using seaborn/matplotlib
- Tabbed interface for exploring different dimensions
- Responsive design for different screen sizes

## Validation

To verify the analysis is working correctly:

1. Check outlier counts: Look for the console output showing how many outliers were removed
2. Cross-check pivot tables: Serializer × Mode tables should show reasonable consistency
3. Compare with notebook: Results should align with the Jupyter notebook analysis
4. Sanity check extreme values: No serializer should show >1 second average times for simple objects

## References

- Tukey, J.W. (1977). *Exploratory Data Analysis*
- seaborn.catplot documentation: https://seaborn.pydata.org/generated/seaborn.catplot.html
