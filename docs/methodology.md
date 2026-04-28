# Benchmark Methodology

Rigorous statistical methods ensure fair cross-language comparison.

## Data Pipeline

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Raw Logs    │ -> │  Normalize   │ -> │   Filter     │ -> │  Statistics  │
│  (CSV)       │    │  Time Units  │    │  Outliers    │    │  Compute     │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

## Time Unit Normalization

C# and Python use different time units. We normalize to nanoseconds:

| Source | Unit | Conversion |
|--------|------|------------|
| C# | Ticks | × 100 → nanoseconds |
| Python | Nanoseconds | Use as-is |

Auto-detection based on magnitude: values > 1,000,000 are treated as C# ticks.

## Outlier Filtering

Raw benchmark data contains noise from:
- GC pauses
- JIT compilation (warmup)
- Thread scheduling delays
- System load spikes

### Tukey's IQR Method

```
Q1 = 25th percentile
Q3 = 75th percentile
IQR = Q3 - Q1

Valid range: [Q1 - 1.5×IQR, Q3 + 1.5×IQR]
```

### Warmup Exclusion

Before IQR filtering, the first repetition (`RepetitionIndex == 0`) of each test group is excluded. This removes:

- JIT compilation overhead (especially in C#)
- Static initialization
- Cold CPU caches and branch predictors

### Impact Examples

| Serializer | Before | After | Improvement |
|------------|--------|-------|-------------|
| FlatSharp | 911,721,849 ns | 9,686 ns | ~94,000× |
| Ceras | 6,870,000 ns | 69,524 ns | ~99× |

## Metrics Computed

| Metric | Description |
|--------|-------------|
| `avg_time_ser_ns` | Mean serialization time (nanoseconds) |
| `avg_time_deser_ns` | Mean deserialization time (nanoseconds) |
| `avg_ops_per_sec` | Operations per second (1e9 / avg_time_total_ns) |
| `median_size_bytes` | Median serialized payload size |
| `runs_raw` | Original measurement count |
| `warmup_skipped` | Warmup runs excluded |
| `outliers_removed` | IQR-filtered measurements |

## Statistical Rigor

- **Grouping**: Per `(SerializerName, TestDataName, Mode)`
- **Minimum sample size**: 10 measurements for IQR filtering
- **Edge cases**: If IQR is 0 (all identical), no filtering applied
- **Safety**: If filtering would remove all values, original data preserved

## Cross-Language Fairness

To enable fair C# vs Python comparison:

1. **Identical test data** — Same conceptual structures (Person, Telemetry, etc.)
2. **Shared schema** — Protobuf definitions in `schemas/benchmark_data.proto`
3. **Normalized time** — Both languages compared in nanoseconds
4. **Consistent ops/sec** — Calculated as `1e9 / nanoseconds` for both

## Validation

Verify analysis correctness:

1. Check outlier counts in console output
2. Cross-check pivot tables for consistency
3. Compare with Jupyter notebook results
4. Sanity check: no serializer should show >1s average for simple objects

## References

- Tukey, J.W. (1977). *Exploratory Data Analysis*
- [seaborn.catplot documentation](https://seaborn.pydata.org/generated/seaborn.catplot.html)

## Full Documentation

For the complete analysis system documentation, see [analysis/docs/README.md](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/main/analysis/docs/README.md).
