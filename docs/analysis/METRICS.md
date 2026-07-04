# Benchmark metrics catalog

**Canonical list** of every metric the suite computes or plans to compute.  
Pipeline (warmup, IQR, shared sanitize for tables/plots): [Analysis methodology](ANALYSIS_METHODOLOGY.md).

| Symbol | Meaning |
|--------|---------|
| **high** | Shown on multi-serializer leaderboards / language Results by default |
| **medium** | Pairwise / version A/B, or multi-way when `metrics.multi_way.include_importance` includes `medium` |
| **low** | Full profile / research only (`--metrics-profile full` or pairwise catalog) |

Configure visibility in `config/benchmark_config.yaml` under `metrics:`.

---

## CSV columns (harness → analysis)

Column order (v1.2+): `SerializerVersion` immediately follows `SerializerName`.

| Column | Unit | Importance | Source | Notes |
|--------|------|------------|--------|--------|
| `Language` | id | high | harness | e.g. `python`, `csharp` |
| `StringOrStream` | enum | high | harness | API mode: `bytes` / `stream` / legacy aliases |
| `TestDataName` | id | high | harness | Fixture name |
| `Repetitions` | count | medium | harness | Configured loop length |
| `RepetitionIndex` | index | medium | harness | `0` = warmup row (kept in raw log) |
| `SerializerName` | id | high | harness | Stable log key |
| `SerializerVersion` | semver / runtime | high | harness | Installed package/crate version |
| `TimeSer` | ns | high | harness | Serialize wall time |
| `TimeDeser` | ns | high | harness | Deserialize wall time |
| `TimeSerAndDeser` | ns | high | harness | Combined (or ser+deser) |
| `Size` | bytes | high | harness | Raw wire size |
| `OpPerSecSer` / `Deser` / `SerAndDeser` | 1/s | medium | harness | Often `1e9/time`; analysis may recompute |
| `MemoryPeakBytes` | bytes | medium | optional | e.g. Python tracemalloc |
| `FidelityScore` | 0–1 | high | optional | 1.0 = round-trip pass |
| `NativeKind` / `StreamMode` | enum | low | optional | Call-path metadata (Rust/Go) |

---

## Analysis group metrics (after sanitize)

Group key: `(Language, SerializerName, TestDataName, StringOrStream)`.

### Speed

| id | Definition | Importance | Higher better? |
|----|------------|------------|----------------|
| `total_median_ns` | Median of filtered total times | **high** (default rank) | no |
| `ser_median_ns` / `deser_median_ns` | Median ser / deser | **high** | no |
| `total_mean_ns` / `ser_mean_ns` / `deser_mean_ns` | Arithmetic means | medium | no |
| `total_std_ns` / `*_mad_ns` / `*_cv` | Dispersion | medium | no (context) |
| `total_p5_ns` … `total_p99_ns` | Percentiles | medium (p95/p99) / low (others) | no |
| `total_ci_low_ns` / `total_ci_high_ns` | Bootstrap CI on **mean** total | medium | — |
| `avg_ops_per_sec` | `1e9 / total_mean_ns` | high (display) | **yes** |
| `runs` / `runs_raw` / `warmup_skipped` / `outliers_removed` | Sample provenance | high | — |

### Size & fidelity

| id | Definition | Importance |
|----|------------|------------|
| `median_size_bytes` | Median raw payload size | **high** |
| `mean_fidelity` | Mean fidelity score | **high** |
| `mean_memory_peak_bytes` | Mean peak alloc (if present) | medium |
| `serializer_version` | From CSV | **high** |

### Effects & inference (within language group)

| id | Definition | Importance | When |
|----|------------|------------|------|
| `effect_vs_fastest_cliffs_delta` | Cliff’s δ vs fastest mean total | medium | multi-way attach |
| `effect_vs_fastest_cliffs_label` | negligible…large / reference | medium | multi-way |
| `effect_vs_fastest_hedges_g` | Hedges’ g | low | multi-way |
| `mann_whitney_u` / `p_value` / `p_value_holm` | A/B only | medium–high for pairwise | `--compare-a/b` |

### Planned (not all implemented)

| id | Axis | Planned importance | Phase |
|----|------|-------------------|--------|
| `size_gzip6` / `size_zstd3` | compression | medium | 1 |
| `compression_ratio_vs_json` | compression | medium | 1 |
| `time_access_ns` | speed (zero-copy) | low–medium | 2 |
| `pareto_non_dominated` | multi-objective | high (flag) | 4 |

---

## Multi-way vs pairwise reporting

| Mode | Trigger | Metrics shown |
|------|---------|----------------|
| **Multi-way** | Default language Results; ≥3 serializers in a group | `metrics.multi_way.include_importance` (default: **`high` only**) |
| **Pairwise** | `--compare-a` / `--compare-b`, or exactly two serializers, or `--metrics-profile pairwise` | high + medium + low (full catalog available for the pair) |
| **Full** | `--metrics-profile full` | Everything computed |

Machine-readable exports (`reports/stats_*_latest.json`) may still contain the full computed set.

---

## Run sidecar: `*.configs.json`

Beside each result CSV (same stem):

```text
logs/<lang>/YYYY-MM-DD-HHMMSS.csv
logs/<lang>/YYYY-MM-DD-HHMMSS.configs.json
```

| Block | Required? | Content |
|-------|-----------|---------|
| `environment` | preferred | OS, CPU, memory, runtimes, git |
| `dataset` | **optional** | seed, fixtures, repetitions, workload labels, config paths |
| `serializers` | **optional** | names + versions from the run |
| `run` | **optional** | mode, metrics profile, timestamp |

Legacy `*.environment.json` is still loaded (treated as the `environment` block).

Important fields from this sidecar are summarized on published Results pages and plot footers when present.

---

## Catalog version

`metrics.catalog_version` in master config should match the version discussed in this file (currently **1**).
