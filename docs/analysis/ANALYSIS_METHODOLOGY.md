# Analysis methodology

This page explains how the **analysis package** turns raw benchmark-runner CSVs into group statistics, effect sizes, language **Results** tables, and latency charts.

If architecture is the lab setup, methodology is the **lab notebook**: what we keep, what we drop, and how we summarize.

**Metric names and importance tiers:** [Metrics catalog](METRICS.md).

| If you need… | Go here |
|--------------|---------|
| What the benchmark runner times / suite layout | [Benchmark architecture](architecture.md) |
| I/O modes and run modes | [Modes](modes.md) |
| Data-type meanings | [Test data](test_data_configuration.md) |
| Paradigms | [Serialization categories](serialization_categories.md) |
| How to regenerate site snapshots | [Results summary](BENCHMARK_SUMMARY.md#regenerating-language-snapshots) |

Defaults live under `statistics:` and `modes:` in [`config/benchmark_config.yaml`](../../config/benchmark_config.yaml). Regeneration is **local** (`analyze-benchmarks`); continuous integration does not re-run analysis for publication.

---

## Learning goals

By the end of this page you should be able to:

1. Trace a CSV row from load → warmup drop → outlier filter → summary statistics.
2. Explain why warmup and outlier rules exist (and that they run only in analysis).
3. Read a confidence interval and an effect size in plain language.
4. Know what the published outputs are and where they are written.

---

## Inputs

| Source | Role |
|--------|------|
| `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` | Per-language benchmark runner output (gitignored) |
| `Language` column | Language id (`csharp`, `python`, `rust`, `c`, `javascript`, `go`, `java`, `cpp`, `swift`, …) |
| `csv_schema` in master config | Required and optional columns |

**Core columns** you will see often:

| Column | Everyday meaning |
|--------|------------------|
| `SerializerName` | Which library |
| `SerializerVersion` | Installed package or crate version (right after the name) |
| `TestDataName` | Which sample data type (`message`, `document`, …) |
| `StringOrStream` | API mode (`bytes` / `stream`, or legacy aliases) |
| `RepetitionIndex` | Which trial in the loop (`0` is warmup for analysis) |
| `TimeSer`, `TimeDeser`, `TimeSerAndDeser` | Times in **nanoseconds** |
| `Size` | Encoded size in **bytes** |
| Ops/sec fields | Throughput estimates (analysis may recompute from means) |

Optional columns include peak memory, fidelity score, and call-path metadata.

---

## The pipeline

Processing is **per group**. A group is one combination of:

```text
(Language, SerializerName, TestDataName, StringOrStream)
```

One function, `prepare_analysis_records` in `stats.py`, performs steps 1–3. **Tables and charts both consume that output**, so they cannot disagree about which trials were kept or which units were used.

| Step | What happens | Why |
|------|--------------|-----|
| 1 | Load CSV; normalize time units from config | Every language reports nanoseconds; analysis applies one consistent scale |
| 2 | Drop warmup (`RepetitionIndex == 0` when enabled) | Removes cold-start spikes (JIT, first allocations, cold caches) |
| 3 | Optional **all-or-nothing** outlier filter (default Tukey IQR) | Softens rare stalls (GC, OS noise) without rewriting raw logs |
| 4 | Descriptive statistics | Means, medians, spread, percentiles |
| 5 | Bootstrap confidence interval on the mean | How stable is the average? |
| 6 | Effect sizes vs the fastest serializer in the group | Is the gap large, or just noise? |
| 7 | Optional version A/B tests | Did *this library* change between two runs? |

### Time units

All benchmark runners write times in **nanoseconds** (including C#). Analysis reads the scale once from master config (`csv_schema.time_unit`, optionally overridden per language) and uses the same factor everywhere. It does **not** guess units from medians or language names.

Published **latency** tables use **microseconds** (µs = ns ÷ 1000). Latency charts also use µs and usually show the **top five** serializers by mean total time per data type so plots stay readable.

### Warmup exclusion

**Benchmark runners write full raw CSVs.** Every successful timed repetition is logged, including index `0`. Runners must not drop warmup, apply IQR, or otherwise “clean” data before writing.

**Analysis only** applies the policy: if `statistics.exclude_warmup` is true (default), rows with **`RepetitionIndex == 0`** are dropped inside `prepare_analysis_records` before outlier filtering and summaries.

Useful provenance fields:

| Field | Meaning |
|-------|---------|
| `warmup_skipped` | How many warmup rows were dropped |
| `runs_raw` | Sample size before warmup drop (still reflects the full log) |
| `runs` | Final sample size after warmup and outlier steps |

Configured warmup length: `reproducibility.warmup_repetitions` = **1**.

### Outlier filtering

Default method: **Tukey interquartile range (IQR)** (`statistics.outlier_method: iqr`, `iqr_k: 1.5`), applied **all-or-nothing** across the three times of each repetition (serialize, deserialize, total).

**Idea in plain language:** look at the middle half of the data (from the 25th to the 75th percentile). Anything far outside fences built from that middle half is treated as an outlier. If *any* of the three times is an outlier, the **whole repetition** is dropped so the three series stay paired.

| Rule | Default behavior |
|------|------------------|
| Fences | `[Q1 − k·IQR, Q3 + k·IQR]` computed **separately** on serialize, deserialize, and total |
| Keep rule | A row is kept only if it sits **inside all three** fences |
| Group size | Apply only if there are at least `min_samples_for_outlier_filter` samples (10) |
| IQR = 0 for a metric | That metric does not remove anyone |
| Would drop the entire group | Keep the original series |
| Method `none` | Skip filtering |
| Method `winsorize` | Clip each series at the 5th and 95th percentiles; never drop rows |

Removed count: `outliers_removed`. Final `runs` is the same for serialize, deserialize, and total. IQR mainly stabilizes the **mean** against rare stalls; always look at dispersion and confidence intervals too.

### Descriptive statistics (per group)

| Kind | What we report |
|------|----------------|
| Central tendency | Mean and median of serialize / deserialize / total times |
| Dispersion | Standard deviation, median absolute deviation (MAD), coefficient of variation, min/max, percentiles (default 5, 25, 50, 75, 95, 99) |
| Size | Median serialized `Size` (bytes) |
| Throughput | Operations per second from mean total time |
| Provenance | `runs`, `runs_raw`, `warmup_skipped`, `outliers_removed` |

**Display-only** rules on language `results.md` (the CSV on disk is unchanged):

- I/O modes labeled **bytes mode** / **stream mode**
- Large numbers: one unit per column (K or M) with about two significant digits
- **Bold** cells mark the semantic best value (lowest time; highest ops/s; ties all bolded)
- **Rust** pages also include within-category mean ops/s rankings in bytes mode

### Bootstrap confidence interval on the mean

When bootstrap is enabled (default), analysis resamples the total-time series many times (**percentile** bootstrap: 2000 iterations, 95% confidence, seed 42) and reports:

- `total_ci_low_ns`
- `total_ci_high_ns`

**Plain language:** “If we repeated this experiment many times, the true mean would usually fall between these two numbers.”

Produced only when the post-filter sample size is at least `min_samples_for_inference` (default 5); otherwise the interval collapses to the point estimate.

### Effect sizes versus the fastest in the group

When effect sizes are enabled (default), each serializer is compared—inside the same language, data type, and I/O mode—to the **fastest** peer (lowest mean total time):

| Method | Role in plain language |
|--------|------------------------|
| **Cliff’s δ (delta)** | How often this library is slower or faster than the reference, without assuming a normal distribution |
| **Hedges’ g** | Standardized mean difference with a small-sample correction |

Use these for **within-language** interpretation. Do not treat them as cross-runtime rankings.

### Version A/B (same language, two runs)

Library authors often care about *their* change, not a global leaderboard:

```bash
./scripts/run-all-benchmarks.sh -m full
analyze-benchmarks --compare-a csharp:190424 --compare-b csharp:191316
# or:
analyze-benchmarks --compare-a rust:185249 --compare-b rust:191316
```

This writes `reports/VERSION_COMPARE.md` (under `paths.reports_root`, default `reports/`) with percent change, Cliff’s δ, Hedges’ g, **Mann–Whitney U**, and **Holm**-adjusted p-values when hypothesis tests are enabled (`alpha` 0.05).

Regression gates: `analyze-benchmarks --check-regression` against `paths.baseline_filename` (default `reports/baseline.json`); save a baseline with `--save-baseline`.

---

## Outputs

| Output | Content |
|--------|---------|
| `docs/<lang>/results.md` | Pivot tables and latency-chart embeds for one language |
| `docs/analysis/plots/violin/*.png` | Combined mean bars (serialize/deserialize) plus split violin shapes (µs, linear from 0; top five by mean total) |
| `docs/analysis/BENCHMARK_SUMMARY.md` | **Static** index of links (not regenerated by the CLI) |
| `logs/<lang>/*.configs.json` | Run sidecar: environment and optional dataset / serializer metadata (legacy `*.environment.json` still works) |
| Console | Load counts, warmup and outlier tallies |

Latency charts use the **same** sanitized records as the summary tables. There is no separate hidden filter for plots. Display may still limit charts to the top five serializers by mean time; that does not change table membership.

How to run the CLI: [Results summary — regenerating](BENCHMARK_SUMMARY.md#regenerating-language-snapshots).

---

## Limitations {#limitations}

Honest methodology includes what the suite **cannot** claim.

- **Cross-language absolute times** are directional at best. Garbage collection, allocators, and runtimes differ. Prefer within-language ranks and effect sizes.
- **Run order:** default benchmark-runner schedule is **block_shuffle** (serializers reshuffled each rep within a cell×mode). This reduces thermal/order confounds vs serializer-outer fixed order. Escape hatch: `BENCHMARK_SCHEDULE=none`. See [architecture — schedule](architecture.md#timed-trial-schedule).
- **C** default builds may use portable stand-ins under real library names—see the [C overview](../c/index.md).
- **Rust** paths such as `prost`, `rkyv`, and `minicbor` use concrete native codecs; timed `rkyv` deserialize **materializes** owned values for fidelity—see the [Rust overview](../rust/index.md).
- **Stream** mode is not always a true incremental API (some benchmark runners buffer, then write). See [Modes — stream honesty](modes.md#three-levels-of-stream-honesty).
- **Fidelity** is semantic or structural, not bit-identical across formats.
- Outlier removal and warmup policy affect means; always read `runs`, confidence intervals, and effect sizes together.

### Methodological disclosures (for careful readers)

- **Bootstrap reproducibility:** each group gets a *derived* seed (base bootstrap seed mixed with a stable hash of language + serializer + data type + mode + series prefix) so intervals are independent across groups yet fully reproducible.
- **Paired series:** serialize, deserialize, and total times share one all-or-nothing keep-mask.
- **Mann–Whitney:** uses SciPy when available (tie-aware); otherwise a pure-NumPy fallback with tie-corrected variance and continuity correction.
- **Regression gates:** `--save-baseline` is skipped when `--check-regression` fails, so a degraded run cannot overwrite the gate baseline.
- **Cliff’s δ for large N:** if the full pair count exceeds about two million, a seeded 100 000-pair random sample is used.
- Some documented config keys are parsed for documentation but do not yet change runtime behaviour; the implementation still computes the full rich metric set.

## References

- Tukey, J.W. (1977). *Exploratory Data Analysis* (IQR fences).
- Cliff’s delta; Hedges’ g; Mann–Whitney U (standard non-parametric toolkit).
- [Seaborn violin / catplot](https://seaborn.pydata.org/generated/seaborn.catplot.html).
