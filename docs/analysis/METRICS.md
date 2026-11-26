# Metrics Catalog

This catalog defines every raw CSV field emitted by language benchmark runners and every summary statistic produced by `analyze-benchmarks` (`metrics.catalog_version: 1` in `config/benchmark_config.yaml`). Cleaning and inference procedures are specified in [Analysis methodology](ANALYSIS_METHODOLOGY.md); canonical vocabulary lives in [Terminology](terminology.md).

## Display Importance Tiers

Visibility tiers are configured under `metrics:` in `config/benchmark_config.yaml`. Machine-readable exports (`reports/stats_<lang>_latest.json`) always carry the complete computed metric set regardless of table tier filters.

| Tier | Reporting Surface |
|---|---|
| **high** | Default multi-serializer Dashboard Overview, Details, and Compare tables |
| **medium** | Pairwise version A/B reports (`--compare-a` / `--compare-b`) and extended profiles |
| **low** | Full diagnostic/research profiles (`--metrics-profile full`) |

## Raw CSV Schema (Runner → Analysis)

Every benchmark runner writes `logs/<lang>/YYYY-MM-DD-HHMMSS.csv`. From schema v1.2 onward, `SerializerVersion` immediately follows `SerializerName`.

| Column | Unit / Type | Tier | Requirement | Semantics |
|---|---|---|---|---|
| `Language` | id | high | required | Short language id (`python`, `csharp`, `rust`, …) |
| `StringOrStream` | enum | high | required | I/O mode (`bytes` or `stream`; legacy C# `string`) |
| `TestDataName` | id | high | required | Data type id (`message`, `document`, `table`, …) |
| `DataTypeInstanceCount` | int | high | batch runs | Batch size $N$ encoded in one timed call |
| `TypeConfigHash` | hex(12) | medium | batch runs | First 12 lowercase hex chars of SHA-256 of canonical `type_config` |
| `Repetitions` | count | medium | required | Configured repetition count for the run mode |
| `RepetitionIndex` | index | medium | required | 0-based trial index (`0` = warmup row dropped by analysis) |
| `SerializerName` | id | high | required | Stable serializer key |
| `SerializerVersion` | string | high | required | Runtime-queried installed library/package version |
| `TimeSer` | ns | high | required | Timed serialize latency |
| `TimeDeser` | ns | high | required | Timed deserialize latency |
| `TimeSerAndDeser` | ns | high | required | Combined serialize + deserialize latency |
| `Size` | bytes | high | required | Encoded wire payload length |
| `OpPerSecSer` / `Deser` / `SerAndDeser` | $\text{s}^{-1}$ | medium | optional | Runner-reported throughput (recomputed by analysis from means) |
| `MemoryPeakBytes` | bytes | medium | optional | Peak allocator high-water mark when instrumented |
| `FidelityScore` | $[0, 1]$ | high | optional | Semantic round-trip check (`1.0` = pass; failures logged to `*.errors.csv`) |
| `NativeKind` | enum | low | optional | Adapter representation family (`serde`, `message`, `dom`, `codable`, …) |
| `StreamMode` | enum | **high** (streams) | required on new stream rows | Stream honesty: `native`, `text_on_stream`, or `adapted` ([Modes](modes.md#three-levels-of-stream-honesty)) |
| `RunOrder` | index | low | optional | Monotonic 0-based process write index (schedule audit) |
| `SchedulePosition` | index | low | optional | 0-based shuffled position within `(cell, mode, rep)` |

## Published Group Metrics (Post-Cleaning)

After warmup exclusion, outlier filtering, and optional I/O parent folding ([Modes](modes.md)), analysis publishes one parent record per `(Language, SerializerName, Standard, DataSet, TestDataName, DataTypeInstanceCount)` with per-policy blocks under `variants.<policy>`.

### Latency, Throughput, and Sample Provenance

| Field | Mathematical Definition / Content | Tier | Optimization Direction |
|---|---|---|---|
| `total_median_ns` | Median filtered combined latency $\tilde{t}_{\text{total}}$ (default speed rank) | **high** | Lower |
| `ser_median_ns` / `deser_median_ns` | Median filtered serialize / deserialize latency | **high** | Lower |
| `total_mean_ns` / `ser_mean_ns` / `deser_mean_ns` | Arithmetic mean filtered latencies $\bar{t}$ | medium | Lower |
| `total_std_ns` / `*_mad_ns` / `*_cv` | Dispersion: sample SD $s$, $\text{MAD} = \operatorname{median}(\lvert t_i - \tilde{t}\rvert)$, $\text{CV} = s/\bar{t}$ | medium | Context |
| `total_p5_ns` … `total_p99_ns` | Empirical quantiles (P5, P25, P50, P75, P95, P99) | medium (P95/P99) / low | Lower |
| `total_ci_low_ns` / `total_ci_high_ns` | 95% percentile bootstrap CI on mean total latency | medium | Context |
| `avg_ops_per_sec` | Throughput from mean total latency: $10^9 / \bar{t}_{\text{ns}}$ | **high** (display) | **Higher** |
| `runs`, `runs_raw`, `warmup_skipped`, `outliers_removed` | Sample retention provenance counts | **high** | Context |
| `values_clipped` | Entries modified by Winsorization (`0` for drop policies) | medium | Context |
| `filter` | Active policy metadata (`policy`, `method`, `iqr_k`, fences, counts) | **high** | Context |

### Payload Size, Fidelity, and Version

| Field | Definition | Tier |
|---|---|---|
| `median_size_bytes` | Median raw wire payload length in bytes | **high** |
| `mean_fidelity` | Mean semantic fidelity score across kept trials | **high** |
| `mean_memory_peak_bytes` | Mean reported peak memory allocation (when available) | medium |
| `serializer_version` | Library version propagated from raw CSV | **high** |

### Effect Sizes and Hypothesis Tests

All formulas and references are defined in [Analysis methodology](ANALYSIS_METHODOLOGY.md#exploratory-ranks).

| Field | Definition | Tier | Scope |
|---|---|---|---|
| `effect_vs_fastest_cliffs_delta` | Cliff's $\delta \in [-1, 1]$ vs. lowest-median peer in group | medium | Exploratory multi-way |
| `effect_vs_fastest_cliffs_label` | Ordinal label (`reference`, `negligible`, `small`, `medium`, `large`) | medium | Exploratory multi-way |
| `effect_vs_fastest_hedges_g` | Bias-corrected standardized mean difference $g$ vs. reference | low | Full / pairwise profile |
| `effect_vs_fastest_p_value` | Unadjusted Mann–Whitney $U$ two-sided $p$-value vs. reference | low | Full / JSON export |
| `effect_vs_fastest_p_value_holm` | Holm–Bonferroni adjusted $p$-value within the single group | medium | JSON / pairwise |
| `effect_vs_fastest_significant_holm` | Boolean indicator $p_{\text{Holm}} < \alpha$ (default $\alpha = 0.05$) | medium | Single-group only |
| `effect_vs_fastest_exploratory` | Always `true` on multi-way Dashboard attachments | — | JSON provenance |
| `mann_whitney_u`, `p_value`, `p_value_holm` | Two-sample test between version A and version B | medium–high | Confirmatory `--compare-a` / `--compare-b` |

*Note on derived and reserved metrics:* Pareto non-dominance (`(speed, median_size_bytes)`) is computed dynamically in the Dashboard for the active filter slice. Compression ratios (`size_gzip6`, `size_zstd3`) and zero-copy field-access latency (`time_access_ns`) are reserved identifiers not yet populated in default suite runs (post-compression trade-offs are measured in [Experiment 2](../experiments/index.md)).

## Run Sidecar Schema (`*.configs.json`)

Each CSV log may be accompanied by a same-stem sidecar (`logs/<lang>/YYYY-MM-DD-HHMMSS.configs.json`; legacy `*.environment.json` is mapped to `environment`):

| Top-Level Block | Requirement | Contents |
|---|---|---|
| `environment` | recommended | OS, CPU model, architecture, core count, memory, runtime versions, git SHA, `machine_id`, optional Linux `cpu_governor` |
| `dataset` | optional | Seed, data types, repetition counts, run-config path |
| `serializers` | optional | Registered names and runtime versions |
| `run` | optional | Run mode, metrics profile, schedule strategy, UTC timestamp |
