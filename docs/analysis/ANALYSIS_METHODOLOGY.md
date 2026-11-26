# Analysis Methodology

This document specifies how the `analyze-benchmarks` package transforms raw per-language CSV logs into cleaned distributions, uncertainty intervals, effect sizes, regression checks, and multi-policy exports for the [Dashboard](../dashboard/index.html). Column definitions live in [Metrics catalog](METRICS.md); runner collection rules live in [Benchmark architecture](architecture.md); claim-level boundaries live in [Claims and replication](CLAIMS_AND_REPLICATION.md).

Statistical defaults are configured under `statistics:` and `modes:` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml). Analysis and Dashboard packing (`dashboard/scripts/sync-data.py`) execute locally; CI does not recompute published benchmark numbers.

## Pipeline Overview

Raw CSV records (`logs/<lang>/YYYY-MM-DD-HHMMSS.csv`; column schema in [Metrics catalog](METRICS.md)) are processed per raw measurement group `(Language, SerializerName, TestDataName, TypeConfigHash, DataTypeInstanceCount, StringOrStream)`. After aggregation, analysis stamps `Standard` and `DataSet` and folds optional I/O levels into the published group identity ([I/O & run modes](modes.md)).

One function (`prepare_analysis_records` in `analysis/src/benchmark_analysis/stats.py`) performs unit normalization, warmup exclusion, and outlier filtering before any summary table or plot is computed, guaranteeing identical sample sets across all outputs.

| Stage | Operation | Purpose |
|---|---|---|
| 1. Unit normalization | Scale raw timings via `csv_schema.time_unit` (all runners emit nanoseconds). | Eliminates unit heuristics; latency tables display µs ($\text{ns} / 1000$). |
| 2. Warmup exclusion | Drop `RepetitionIndex == 0` when `statistics.exclude_warmup` is true. | Removes cold-start JIT compilation, first-touch allocation, and cold-cache bias[^1] without modifying raw logs. |
| 3. Outlier policy | Apply paired Tukey IQR fences or Winsorization across four fixed Dashboard policies. | Stabilizes mean estimates against transient OS/GC stalls while preserving raw `all` distributions. |
| 4. Descriptive statistics | Compute median, mean, SD, MAD, CV, quantiles (P5–P99), median payload size, and throughput. | Summarizes central tendency, scale, and upper tail behavior. |
| 5. Bootstrap inference | Compute 95% percentile bootstrap CI on mean total latency (2,000 resamples). | Quantifies within-session sampling uncertainty without normality assumptions.[^2] |
| 6. Group effect sizes | Compute Cliff's $\delta$, Hedges' $g$, and Holm-adjusted Mann–Whitney $U$ vs. group fastest. | Provides exploratory magnitude and rank-separation diagnostics within one cell. |
| 7. Pairwise A/B & gate | Optional `--compare-a` / `--compare-b` hypothesis test or `--check-regression` gate. | Supports confirmatory version comparisons and regression detection. |

## Warmup and Outlier Policies

Benchmark runners log every successful repetition, including `RepetitionIndex = 0` (`reproducibility.warmup_repetitions = 1`). Analysis records provenance counts `runs_raw`, `warmup_skipped`, `outliers_removed`, and final `runs` for every group.

### Paired Tukey IQR Filtering

The canonical policy (`iqr_1.5`) applies Tukey fences[^3] with $k = 1.5$ independently to the serialize, deserialize, and total latency series of each group (when sample count $\ge$ `min_samples_for_outlier_filter`, default 10):

$$
\left[ Q_1 - k \cdot \text{IQR},\;\; Q_3 + k \cdot \text{IQR} \right], \qquad \text{IQR} = Q_3 - Q_1
$$

Filtering is **all-or-nothing per repetition**: a repetition is retained if and only if all three measurements (`TimeSer`, `TimeDeser`, `TimeSerAndDeser`) fall within their respective fences, preserving exact pairing across series. Edge cases are guarded: a metric with $\text{IQR} = 0$ removes no rows, and if filtering would empty a group, the unfiltered post-warmup series is preserved.

### Multi-Policy Dashboard Export

`reports/stats_<lang>_latest.json` (schema 2.2, gzip-packed to `dashboard/public/data/stats_<lang>_latest.json.gz`) precomputes every group under four policies exposed by the Dashboard **Samples** selector:

| Policy ID | Cleaning Rule |
|---|---|
| `all` | Post-warmup only; no repetitions dropped or clipped. |
| `iqr_1.5` | Paired Tukey fences with $k = 1.5$ (canonical Dashboard default). |
| `iqr_3` | Paired Tukey fences with $k = 3.0$ (retains moderate tail spikes). |
| `winsorize_5_95` | Clips each series independently to $[P_5, P_{95}]$ while preserving sample count $n$ (`values_clipped` records modified entries). |

Pareto non-dominance is recomputed dynamically by the Dashboard for the active policy and filter slice.

## Estimators, Throughput, and Uncertainty

For a cleaned latency sample $\{t_1, \dots, t_n\}$ (nanoseconds) with sample mean $\bar{t}$, median $\tilde{t}$, and sample standard deviation $s$:

$$
\text{ops/s} = \frac{10^9}{\bar{t}_{\text{ns}}}, \qquad
\text{MAD} = \operatorname{median}_i \bigl(|t_i - \tilde{t}|\bigr), \qquad
\text{CV} = \frac{s}{\bar{t}}
$$

By Jensen's inequality for the convex function $f(t) = 1/t$ on $t > 0$, $\text{ops/s} = 10^9 / \bar{t} \le \frac{1}{n}\sum_{i=1}^n (10^9 / t_i)$, and mean-derived throughput can rank two close codecs differently from the default median-latency rank (`total_median_ns`).

**Bootstrap confidence interval:** When $n \ge$ `min_samples_for_inference` (default 5), analysis computes a 95% percentile bootstrap CI (`total_ci_low_ns`, `total_ci_high_ns`) over $B = 2000$ resamples[^2] using a deterministic per-group seed derived from `(base_seed, language, serializer, test_data, mode, series_prefix)`. For $n < 5$, the interval collapses to the point estimate.

## Effect Sizes and Exploratory Multi-Way Ranks {#exploratory-ranks}

Within each peer group `(language × data type × type-config × batch N × I/O mode)`, every serializer is compared against the group's fastest reference (selected by minimum `total_median_ns`, falling back to mean). Note that this peer group spans standards; for controlled implementation comparisons, slice by **standard** on the Dashboard.

| Statistic | Mathematical Definition | Role |
|---|---|---|
| **Cliff's $\delta$**[^4] | $\delta = \dfrac{\#(x_i > y_j) - \#(x_i < y_j)}{n_1 n_2} \in [-1, 1]$ | Nonparametric stochastic dominance (no normality assumption); magnitude thresholds $\lvert \delta \rvert < 0.147$ (negligible), $< 0.33$ (small), $< 0.474$ (medium), $\ge 0.474$ (large).[^5] For $n_1 n_2 > 2 \times 10^6$, estimated via a seeded sample of $10^5$ pairs. |
| **Hedges' $g$**[^6] | $g = J(n_1 + n_2 - 2)\,\dfrac{\bar{x}_1 - \bar{x}_2}{s_{\text{pooled}}}, \quad J(\nu) \approx 1 - \dfrac{3}{4\nu - 1}$ | Small-sample bias-corrected standardized mean difference. |
| **Mann–Whitney $U$ + Holm–Bonferroni**[^7][^8] | $p_{(i)}^{\text{Holm}} = \min\!\Bigl(1,\; \max_{j \le i}\,(m - j + 1)\,p_{(j)}\Bigr)$ | Two-sample rank test (SciPy tie-aware implementation, with tie- and continuity-corrected NumPy fallback) adjusted step-down across the $m$ peers **within one group only** ($\alpha = 0.05$). |

**Exploratory status:** Selecting the fastest codec post-hoc and testing all remaining peers inflates family-wise Type I error across a multi-cell Dashboard. Holm adjustment controls error only inside a single group, not across the entire site. Multi-way Dashboard ranks are therefore labeled **exploratory** (`effect_vs_fastest_exploratory = true`). Confirmatory version comparisons require a dedicated pairwise A/B run:

```bash
analyze-benchmarks --compare-a rust:185249 --compare-b rust:191316
```

which writes `reports/VERSION_COMPARE.md` containing percent change, Cliff's $\delta$, Hedges' $g$, and Holm-adjusted Mann–Whitney $U$ p-values.

## Regression Gate {#regression-gate}

Automated regression checks compare a new run against a saved baseline (`reports/baseline.json`, schema v2, keyed by `(language, serializer, data_type, N, type_config_hash, io_mode)`). To prevent false alarms from single-run noise under an `OR` trigger, the default gate requires **both** a practical slowdown exceeding $\tau = \text{threshold\_percent} / 100$ (default $\tau = 0.10$) **and** statistical support from the lower bound of the bootstrap CI (`regression.combine: and`):

$$
\text{Regression} \iff \Bigl(\hat{t}_{\text{curr}} > t_{\text{base}}(1 + \tau)\Bigr) \;\land\; \Bigl(\text{CI}_{\text{low}}(\bar{t}_{\text{curr}}) > t_{\text{base}}(1 + \tau)\Bigr)
$$

| Practical Check ($\hat{t}_{\text{curr}} > t_{\text{base}}(1+\tau)$) | Statistical Check ($\text{CI}_{\text{low}} > t_{\text{base}}(1+\tau)$) | Classification | Exit Code |
|---|---|---|---|
| Pass (within $\tau$) | — | `equivalent` | 0 |
| Exceeds $\tau$ | Below threshold | `unclear` (investigate) | 0 |
| Exceeds $\tau$ | Exceeds $\tau$ | `regression` | 1 (blocks `--save-baseline`) |

When the baseline retains capped raw samples, Cliff's $\delta$ is also reported as a diagnostic (`require_for_fail: false`).

```bash
analyze-benchmarks --check-regression --regression-threshold 5 --regression-combine and
analyze-benchmarks --save-baseline   # writes baseline only when regression check passes
```

## Multi-Session Aggregation {#multi-session-claims}

Single-session Dashboard snapshots constitute **L1** evidence. Aggregating repeated sessions (`--multi-session`) computes median-of-session-medians, cross-session IQR, rank stability, and heuristic L2/L3 claim classifications from `*.configs.json` host fingerprints (`machine_id`). Full evidence definitions and replication commands live in [Claims and replication](CLAIMS_AND_REPLICATION.md).

## Limitations {#limitations}

- **Cross-language latency:** Absolute timings across languages confound runtimes, garbage collectors, and allocators; use within-language, within-standard comparisons for rankings.
- **Residual execution variance:** Default `block_shuffle` scheduling mitigates monotonic thermal and frequency drift,[^9] but single-session L1 runs still reflect transient host state.
- **Adapter-specific constraints:** C portable proto3 stand-ins, Rust eager `rkyv` materialization, and `adapted` stream rows carry explicit disclosures on their language pages and in [Timing contract](TIMING_HONESTY.md).
- **Fidelity scope:** Fidelity checks verify semantic or structural equivalence (with bit-identical rules on `array` and `tensor`), not cross-format byte equality.
- **Outlier sensitivity:** Dropping outliers stabilizes means at the cost of hiding rare GC or allocator spikes; always inspect `all` alongside `iqr_1.5`, plus `runs`, P95/P99, and CIs.

## References {#references}

[^1]: Georges, A., Buytaert, D., & Eeckhout, L. (2007). "Statistically Rigorous Java Performance Evaluation." *Proceedings of OOPSLA '07*, 57–76. <https://doi.org/10.1145/1297027.1297033>
[^2]: Efron, B., & Tibshirani, R. J. (1993). *An Introduction to the Bootstrap*. Chapman & Hall/CRC.
[^3]: Tukey, J. W. (1977). *Exploratory Data Analysis*. Addison-Wesley.
[^4]: Cliff, N. (1993). "Dominance Statistics: Ordinal Analyses to Answer Ordinal Questions." *Psychological Bulletin*, 114(3), 494–509. <https://doi.org/10.1037/0033-2909.114.3.494>
[^5]: Romano, J., Kromrey, J. D., Coraggio, J., & Skowronek, J. (2006). "Appropriate Statistics for Ordinal Level Data: Should We Really Be Using t-test and Cohen's d for Evaluating Group Differences on the NSSE and Other Surveys?" *Annual Meeting of the Florida Association of Institutional Research*.
[^6]: Hedges, L. V. (1981). "Distribution Theory for Glass's Estimator of Effect Size and Related Estimators." *Journal of Educational Statistics*, 6(2), 107–128. <https://doi.org/10.3102/10769986006002107>
[^7]: Mann, H. B., & Whitney, D. R. (1947). "On a Test of Whether One of Two Random Variables Is Stochastically Larger than the Other." *The Annals of Mathematical Statistics*, 18(1), 50–60. <https://doi.org/10.1214/aoms/1177730491>
[^8]: Holm, S. (1979). "A Simple Sequentially Rejective Multiple Test Procedure." *Scandinavian Journal of Statistics*, 6(2), 65–70.
[^9]: Mytkowicz, T., Diwan, A., Hauswirth, M., & Sweeney, P. F. (2009). "Producing Wrong Data Without Doing Anything Obviously Wrong!" *Proceedings of ASPLOS '09*, 265–276. <https://doi.org/10.1145/1508244.1508275>
