# Benchmark metrics catalog

This page is a **dictionary of measurements**. Every number the suite computes (or plans to compute) has a name, a unit, and an importance tier for display.

How those numbers are produced (warmup, outlier filter, shared sanitize for tables and plots): [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Learning goals

After this page you should be able to:

1. Distinguish **CSV columns** written by benchmark runners from **group metrics** computed by analysis.
2. Read the **importance** tags (high / medium / low) and know which appear on Dashboard Details / Compare by default.
3. Explain multi-way versus pairwise reporting in one sentence.

---

## Importance tiers

| Tier | Meaning |
|------|---------|
| **high** | Shown on multi-serializer leaderboards and Dashboard Details / Compare by default |
| **medium** | Used in pairwise / version A/B reports, or in multi-way views when config includes medium |
| **low** | Full profile / research only (`--metrics-profile full` or pairwise catalog) |

Configure visibility under `metrics:` in `config/benchmark_config.yaml`.

---

## CSV columns (benchmark runner → analysis)

These fields are written by each language benchmark runner. Column order (v1.2+): `SerializerVersion` immediately follows `SerializerName`.

| Column | Unit | Importance | Source | Everyday meaning |
|--------|------|------------|--------|------------------|
| `Language` | id | high | runner | Which language ran (`python`, `csharp`, …) |
| `StringOrStream` | enum | high | runner | I/O mode: `bytes` / `stream` (C# often `string`); see [Modes](modes.md) |
| `TestDataName` | id | high | runner | Data type id (`message`, `document`, …) |
| `Repetitions` | count | medium | runner | How many times the loop was configured to run |
| `RepetitionIndex` | index | medium | runner | Which trial this row is; `0` is the warmup row in raw logs |
| `SerializerName` | id | high | runner | Stable log key for the library |
| `SerializerVersion` | semver / runtime | high | runner | Installed package or crate version |
| `TimeSer` | ns | high | runner | Wall time to serialize |
| `TimeDeser` | ns | high | runner | Wall time to deserialize |
| `TimeSerAndDeser` | ns | high | runner | Combined time (or serialize + deserialize) |
| `Size` | bytes | high | runner | Raw wire size of the payload |
| `OpPerSecSer` / `Deser` / `SerAndDeser` | 1/s | medium | runner | Often `1e9/time`; analysis may recompute |
| `MemoryPeakBytes` | bytes | medium | optional | Peak allocation if the benchmark runner records it |
| `FidelityScore` | 0–1 | high | optional | `1.0` means the round-trip check passed |
| `NativeKind` | enum | low | optional | Codec shape family (serde, message, codable, …) when the runner records it |
| `StreamMode` | enum | **high** on stream rows | optional on old CSVs; **required on new stream rows** | Honesty label: `native` \| `text_on_stream` \| `adapted` — see [Modes — stream honesty](modes.md#three-levels-of-stream-honesty) |
| `RunOrder` | index | low | optional | Monotonic 0-based index of written timed rows in process order (schedule audit) |
| `SchedulePosition` | index | low | optional | 0-based position of this serializer within its `(cell, mode, rep)` after shuffle |

---

## Analysis group metrics (after cleaning)

After warmup drop and optional outlier filter, analysis groups rows by:

```text
(Language, SerializerName, TestDataName, StringOrStream)
```

### Speed

| id | Definition | Importance | Higher better? |
|----|------------|------------|----------------|
| `total_median_ns` | Median of filtered total times | **high** (default rank) | no |
| `ser_median_ns` / `deser_median_ns` | Median serialize / deserialize | **high** | no |
| `total_mean_ns` / `ser_mean_ns` / `deser_mean_ns` | Arithmetic means | medium | no |
| `total_std_ns` / `*_mad_ns` / `*_cv` | Dispersion (spread) | medium | no (context) |
| `total_p5_ns` … `total_p99_ns` | Percentiles | medium (p95/p99) / low (others) | no |
| `total_ci_low_ns` / `total_ci_high_ns` | [Bootstrap](https://en.wikipedia.org/wiki/Bootstrapping_%28statistics%29 "Bootstrapping (statistics)") [confidence interval](https://en.wikipedia.org/wiki/Confidence_interval "Confidence interval") on **mean** total | medium | — |
| `avg_ops_per_sec` | `1e9 / total_mean_ns` | high (display) | **yes** |
| `runs` / `runs_raw` / `warmup_skipped` / `outliers_removed` | Sample provenance | high | — |
| `values_clipped` | Rows touched by winsorize (0 for drop filters) | medium | — |
| `filter` | Policy provenance block (`policy`, `method`, `iqr_k`, fences, counts) | high (dashboard) | — |

**Tip:** lower time is better; higher ops/s is better. Medians resist wild spikes better than means; means still matter for throughput.

### Size and fidelity

| id | Definition | Importance |
|----|------------|------------|
| `median_size_bytes` | Median raw payload size | **high** |
| `mean_fidelity` | Mean fidelity score | **high** |
| `mean_memory_peak_bytes` | Mean peak allocation (if present) | medium |
| `serializer_version` | From CSV | **high** |

### Effects and inference (within a language group)

| id | Definition | Importance | When |
|----|------------|------------|------|
| `effect_vs_fastest_cliffs_delta` | [Cliff’s δ](https://en.wikipedia.org/wiki/Effect_size#Effect_size_for_ordinal_data "Cliff’s delta") vs fastest (reference = lowest **[median](https://en.wikipedia.org/wiki/Median "Median")** total, else mean) | medium | multi-way attach |
| `effect_vs_fastest_cliffs_label` | negligible…large / `reference` | medium | multi-way tables |
| `effect_vs_fastest_hedges_g` | [Hedges’ g](https://en.wikipedia.org/wiki/Effect_size#Hedges'_g "Hedges’ g") vs reference | low | multi-way attach / pairwise profile |
| `effect_vs_fastest_p_value` | [Mann–Whitney U](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test "Mann–Whitney U test") [p](https://en.wikipedia.org/wiki/P-value "P-value") vs reference (raw) | low | machine-readable / full profile |
| `effect_vs_fastest_p_value_holm` | [Holm](https://en.wikipedia.org/wiki/Holm%E2%80%93Bonferroni_method "Holm–Bonferroni method")-adjusted p **within the same group only** | medium | JSON / pairwise-capable profiles |
| `effect_vs_fastest_significant_holm` | `p_holm < alpha` (default 0.05) | medium | JSON; not a multi-page [family-wise](https://en.wikipedia.org/wiki/Family-wise_error_rate "Family-wise error rate") claim |
| `effect_vs_fastest_exploratory` | Always true for multi-way attach (exploratory labeling) | — | JSON |
| `mann_whitney_u` / `p_value` / `p_value_holm` | Two-sample [nonparametric](https://en.wikipedia.org/wiki/Nonparametric_statistics "Nonparametric statistics") test between version A and B | medium–high for pairwise | `--compare-a` / `--compare-b` |

**Reading tip:** multi-way Dashboard ranks are **exploratory**. Prefer [Claims and replication](CLAIMS_AND_REPLICATION.md) for L1/L2/L3 language, and pairwise A/B for confirmatory library comparisons.

Full URL list: [Analysis methodology — References](ANALYSIS_METHODOLOGY.md#references).

### Planned (not all implemented)

| id | Axis | Planned importance | Phase |
|----|------|-------------------|--------|
| `size_gzip6` / `size_zstd3` | compression | medium | 1 |
| `compression_ratio_vs_json` | compression | medium | 1 |
| `time_access_ns` | speed (zero-copy) | low–medium | 2 |
| `pareto_non_dominated` | multi-objective | high (flag) | 4 |

---

## Multi-way versus pairwise reporting

| Mode | When it runs | Metrics shown |
|------|--------------|---------------|
| **Multi-way** | Default Dashboard Details / Compare; three or more serializers in a group | Importance tiers listed under `metrics.multi_way.include_importance` (default: **high only**) |
| **Pairwise** | `--compare-a` / `--compare-b`, exactly two serializers, or `--metrics-profile pairwise` | high + medium + low (full catalog for the pair) |
| **Full** | `--metrics-profile full` | Everything computed |

Machine-readable exports (`reports/stats_*_latest.json`) may still contain the full computed set even when the markdown tables show only high-importance columns.

---

## Run sidecar: `*.configs.json`

Beside each result CSV (same file stem):

```text
logs/<lang>/YYYY-MM-DD-HHMMSS.csv
logs/<lang>/YYYY-MM-DD-HHMMSS.configs.json
```

| Block | Required? | Content |
|-------|-----------|---------|
| `environment` | preferred | Operating system, CPU, memory, runtimes, git revision |
| `dataset` | optional | Seed, data types, repetitions, workload labels, config paths |
| `serializers` | optional | Names and versions from the run |
| `run` | optional | Mode, metrics profile, timestamp |

Legacy `*.environment.json` files are still loaded and treated as the `environment` block.

Important fields from this sidecar are summarized in Dashboard run chrome (one-line identity plus the Run configuration panel) when present.

---

## Catalog version

`metrics.catalog_version` in master config should match the version discussed here (currently **1**).
