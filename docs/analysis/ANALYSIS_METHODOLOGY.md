# Analysis methodology

This page explains how the **analysis package** turns raw benchmark-runner CSVs into group statistics, effect sizes, Dashboard numbers, and unpublished language reports.

If architecture is the lab setup, methodology is the **lab notebook**: what we keep, what we drop, and how we summarize.

**Metric names and importance tiers:** [Metrics catalog](METRICS.md).

| If you need… | Go here |
|--------------|---------|
| What the benchmark runner times / suite layout | [Benchmark architecture](architecture.md) |
| I/O modes and run modes | [Modes](modes.md) |
| Data-type meanings | [Test data](test_data_configuration.md) |
| Paradigms | [Serialization categories](serialization_categories.md) |
| How to regenerate published numbers | [Dashboard](../dashboard/) via `sync-data.py` · [Claims and replication](CLAIMS_AND_REPLICATION.md) |

Defaults live under `statistics:` and `modes:` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml). Regeneration is **local** (`analyze-benchmarks`); continuous integration does not re-run analysis for publication.

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

Default method: **[John Tukey](https://en.wikipedia.org/wiki/John_Tukey "John Tukey — invented exploratory data analysis and popularized boxplot/IQR fences")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> [interquartile range (IQR)](https://en.wikipedia.org/wiki/Interquartile_range "Interquartile range — spread of the middle 50% of values")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** fences (`statistics.outlier_method: iqr`, `iqr_k: 1.5`), applied **all-or-nothing** across the three times of each repetition (serialize, deserialize, total).

**Idea in plain language:** look at the middle half of the data (from the 25th to the 75th [percentile](https://en.wikipedia.org/wiki/Percentile "Percentile — value below which a given percentage of observations fall")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />). Anything far outside fences built from that middle half is treated as an [outlier](https://en.wikipedia.org/wiki/Outlier "Outlier — observation far from the bulk of the data")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />. If *any* of the three times is an outlier, the **whole repetition** is dropped so the three series stay paired.

| Rule | Default behavior |
|------|------------------|
| Fences | `[Q1 − k·IQR, Q3 + k·IQR]` computed **separately** on serialize, deserialize, and total |
| Keep rule | A row is kept only if it sits **inside all three** fences |
| Group size | Apply only if there are at least `min_samples_for_outlier_filter` samples (10) |
| IQR = 0 for a metric | That metric does not remove anyone |
| Would drop the entire group | Keep the original series |
| Method `none` | Skip filtering |
| Method `winsorize` | [Winsorize](https://en.wikipedia.org/wiki/Winsorizing "Winsorizing — replace extreme values with less extreme ones")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />: clip each series at the 5th and 95th percentiles; never drop rows |

Removed count: `outliers_removed`. Final `runs` is the same for serialize, deserialize, and total. IQR mainly stabilizes the **mean** against rare stalls; always look at dispersion and [confidence intervals](https://en.wikipedia.org/wiki/Confidence_interval "Confidence interval — range of plausible values for a parameter")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> too.

### Dashboard filter policies (multi-aggregation export)

Machine-readable `stats_<lang>_latest.json` (schema **2.2**, published as **`.json.gz`**) recomputes every group under **four fixed sample policies** so the dashboard can research outliers without re-running filters in the browser:

| Policy id | Behavior |
|-----------|----------|
| `all` | Post-warmup only; no drop, no winsorize |
| `iqr_1.5` | Paired IQR with **k = 1.5** (canonical / default rankings) |
| `iqr_3` | Paired IQR with **k = 3** (looser fences) |
| `winsorize_5_95` | Clip each series at the 5th/95th percentile; **n** unchanged (`values_clipped` counts affected rows) |

Export fields (compact):

- `default_filter_policy` — usually `iqr_1.5`
- `filter_policies` — catalog once (label, description, method, k, …)
- `groups[]` — identity fields once + `variants.<policy>` metrics (no duplicated flat lists)
- per-variant `filter` — counts / fences / method only (labels live in the catalog)
- Pareto is **not** precomputed; the dashboard recalculates from the active policy metrics

Published dashboard path: `dashboard/public/data/stats_<lang>_latest.json.gz` (gzip of the same JSON).

Markdown language pages still use the configured single `statistics.outlier_method` path (default IQR 1.5). The multi-policy pack is for the interactive dashboard **Samples** control.

### Descriptive statistics (per group)

| Kind | What we report |
|------|----------------|
| Central tendency | [Mean](https://en.wikipedia.org/wiki/Arithmetic_mean "Arithmetic mean — average") and [median](https://en.wikipedia.org/wiki/Median "Median — middle value when sorted") of serialize / deserialize / total times |
| Dispersion | [Standard deviation](https://en.wikipedia.org/wiki/Standard_deviation "Standard deviation — typical distance from the mean"), [median absolute deviation (MAD)](https://en.wikipedia.org/wiki/Median_absolute_deviation "Median absolute deviation — robust scale measure"), [coefficient of variation](https://en.wikipedia.org/wiki/Coefficient_of_variation "Coefficient of variation — std / mean"), min/max, percentiles (default 5, 25, 50, 75, 95, 99) |
| Size | Median serialized `Size` (bytes) |
| Throughput | Operations per second from mean total time |
| Provenance | `runs`, `runs_raw`, `warmup_skipped`, `outliers_removed` |

**Display-only** rules on unpublished `reports/<docs_dir>/results.md` (the CSV on disk is unchanged):

- I/O modes labeled **bytes mode** / **stream mode**
- Large numbers: one unit per column (K or M) with about two significant digits
- **Bold** cells mark the semantic best value (lowest time; highest ops/s; ties all bolded)
- **Rust** reports also include within-category mean ops/s rankings in bytes mode

Published numbers live on the [Dashboard](../dashboard/). Those reports are PR-diff blobs, not site pages.

### Bootstrap confidence interval on the mean

When bootstrap is enabled (default), analysis resamples the total-time series many times using the **[bootstrap](https://en.wikipedia.org/wiki/Bootstrapping_%28statistics%29 "Bootstrapping (statistics) — resampling to estimate uncertainty")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** (**percentile** method: 2000 iterations, 95% [confidence interval](https://en.wikipedia.org/wiki/Confidence_interval "Confidence interval — range of plausible values for a parameter")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />, seed 42) and reports:

- `total_ci_low_ns`
- `total_ci_high_ns`

**Plain language:** “If we repeated this experiment many times, the true mean would usually fall between these two numbers.”

Produced only when the post-filter sample size is at least `min_samples_for_inference` (default 5); otherwise the interval collapses to the point estimate.

### Effect sizes versus the fastest in the group

When [effect sizes](https://en.wikipedia.org/wiki/Effect_size "Effect size — how large a difference is, not only whether it is significant")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> are enabled (default), each serializer is compared—inside the same language, data type, batch size, and I/O mode—to the **fastest** peer. The reference is chosen by **lowest median total time** when available (falls back to mean). That matches the [nonparametric](https://en.wikipedia.org/wiki/Nonparametric_statistics "Nonparametric statistics — methods that avoid strong distribution assumptions")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> story of the suite.

| Method | Role in plain language |
|--------|------------------------|
| **[Cliff’s δ (delta)](https://en.wikipedia.org/wiki/Effect_size#Effect_size_for_ordinal_data "Cliff’s delta — probability one sample is larger than another")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** | How often this library is slower or faster than the reference, without assuming a normal distribution |
| **[Hedges’ g](https://en.wikipedia.org/wiki/Effect_size#Hedges'_g "Hedges’ g — standardized mean difference with small-sample correction")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** | Standardized mean difference with a small-sample correction |
| **[Mann–Whitney U](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test "Mann–Whitney U test — nonparametric two-sample rank test")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" /> + [Holm](https://en.wikipedia.org/wiki/Holm%E2%80%93Bonferroni_method "Holm–Bonferroni method — stepwise p-value adjustment for multiple tests")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** | Optional [p-values](https://en.wikipedia.org/wiki/P-value "P-value — probability of data as extreme as observed under the null") vs the reference; Holm adjusts for **many serializers in that one group only** |

Use these for **within-language** interpretation. Do not treat them as cross-runtime rankings. Multi-way tables treat ranks as **exploratory** — see [Exploratory ranks](#exploratory-ranks).

### Exploratory ranks {#exploratory-ranks}

This section is written for a **first-year university student**.

#### What problem are we solving?

A Dashboard slice often shows **many** libraries side by side. Picking a “winner” and then testing every other library against that winner is like running **many quizzes at once** — the [multiple comparisons problem](https://en.wikipedia.org/wiki/Multiple_comparisons_problem "Multiple comparisons problem — more tests raise the chance of false positives")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />. If you celebrate every small “significant” mark without adjusting for how many quizzes you ran, you overstate confidence.

#### What we do

1. **Show effect sizes** ([Cliff’s δ](https://en.wikipedia.org/wiki/Effect_size#Effect_size_for_ordinal_data "Cliff’s delta") label, and in machine-readable JSON also [Hedges’ g](https://en.wikipedia.org/wiki/Effect_size#Hedges'_g "Hedges’ g")) so you can see *how large* a gap looks.
2. **Attach [Mann–Whitney](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test "Mann–Whitney U test") [p-values](https://en.wikipedia.org/wiki/P-value "P-value")** vs the group’s fastest codec when samples allow.
3. **[Holm](https://en.wikipedia.org/wiki/Holm%E2%80%93Bonferroni_method "Holm–Bonferroni method")-adjust those p-values inside the group** `(language × data type × type-config × batch N × I/O mode)` only — not across every cell on the page.
4. **Label multi-way Dashboard ranks as exploratory.** Prefer **pairwise A/B** (`--compare-a` / `--compare-b`) when you need a confirmatory “did *this* change beat *that* baseline?” answer.

#### Plain-language takeaway

> Scores (effect sizes) help you browse. Adjusted p-values inside one group reduce “many quizzes” mistakes. They are **not** a global [family-wise](https://en.wikipedia.org/wiki/Family-wise_error_rate "Family-wise error rate — chance of any false positive in a family of tests") guarantee for the whole Dashboard roster, and default published ranks are still **L1 single-session** evidence ([Claims and replication](CLAIMS_AND_REPLICATION.md)).

Config knobs live under `statistics.effect_sizes.vs_fastest` (defaults in code if YAML omits them): `reference: median`, `test: mann_whitney_u`, `multiple_comparison: holm`.

### Version A/B (same language, two runs)

Library authors often care about *their* change, not a global leaderboard:

```bash
./scripts/run-all-benchmarks.sh -m full
analyze-benchmarks --compare-a csharp:190424 --compare-b csharp:191316
# or:
analyze-benchmarks --compare-a rust:185249 --compare-b rust:191316
```

This writes `reports/VERSION_COMPARE.md` (under `paths.reports_root`, default `reports/`) with percent change, [Cliff’s δ](https://en.wikipedia.org/wiki/Effect_size#Effect_size_for_ordinal_data "Cliff’s delta"), [Hedges’ g](https://en.wikipedia.org/wiki/Effect_size#Hedges'_g "Hedges’ g"), **[Mann–Whitney U](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test "Mann–Whitney U test")**, and **[Holm](https://en.wikipedia.org/wiki/Holm%E2%80%93Bonferroni_method "Holm–Bonferroni method")**-adjusted p-values when hypothesis tests are enabled (`alpha` 0.05).

Regression gates: `analyze-benchmarks --check-regression` against `paths.baseline_filename` (default `reports/baseline.json`); save a baseline with `--save-baseline`. Details: [Regression gate](#regression-gate).

---

## Regression gate {#regression-gate}

This section is written for a **first-year university student**. No advanced stats course required.

### What problem are we solving?

Imagine you measured how long a library takes to serialize data **yesterday** (the **baseline**), and you measure again **today** (the **current** run).

- Some days the computer is a bit busier (other programs, heat, random noise).
- So today’s *average* can look 12% slower even when the library did **not** really get worse.

If our quality gate shouted “REGRESSION!” every time the average wiggled, we would get **false alarms** and stop trusting the gate.

### What went wrong with the old rule (OR)

The old gate used two checks and failed if **either** was true (logical **OR**):

1. **Practical check:** “Is the point estimate more than 10% slower than baseline?”
2. **Statistical check:** “Is even the *optimistic* end of our confidence interval still more than 10% slower?”

With **OR**, a noisy average alone could fail the gate even when the confidence interval still said “this might still be about the same.” That is like failing a student for one shaky quiz question while the rest of the exam looks fine.

### What we do now (AND)

By default the gate uses logical **AND**:

> Fail only if the run looks **practically** slower **and** the data still look slower even if we give the new run the benefit of the doubt (CI lower bound).

| Check | Plain meaning |
|-------|----------------|
| **Practical** | Median (preferred) or mean total time is more than `threshold_percent` (default 10%) worse than baseline |
| **Statistical** | The lower end of the bootstrap CI on the **mean** is still above `baseline × (1 + threshold/100)` |

So:

- **Practical yes + statistical no** → classified **unclear** (investigate; do not hard-fail by default).
- **Both yes** → **regression** (exit code 1; baseline is not overwritten).
- **Within threshold** (and Cliff’s δ negligible when samples exist) → **equivalent**.

You can restore the old noisier behavior with `regression.combine: or` or `--regression-combine or`.

### Cliff’s δ (optional, when we saved samples)

If the baseline file stores a sample of old timings, we also compute **[Cliff’s δ](https://en.wikipedia.org/wiki/Effect_size#Effect_size_for_ordinal_data "Cliff’s delta — nonparametric effect size")<img src="https://en.wikipedia.org/static/images/icons/wikipedia.png" alt="" width="14" height="14" style="vertical-align: text-bottom; margin-left: 0.15em;" />** between current and baseline samples (positive ≈ current slower). By default δ is **diagnostic** only (`require_for_fail: false`). That keeps the gate simple while still reporting a nonparametric effect size.

### Baseline file (what we store)

`reports/baseline.json` (schema v2) stores, per group:

- median and mean total time, CI, ops/s, size, run count  
- optional capped list of sample times (for δ)  
- keys that include **language, serializer, data type, batch N, type-config hash, I/O mode** so N=1 and N=100 do not collide  

Legacy flat baselines (older keys without N/hash) are still **read** for one migration cycle; re-save with `--save-baseline` after a clean run.

### Commands

```bash
analyze-benchmarks --check-regression
analyze-benchmarks --check-regression --regression-threshold 5 --regression-combine and
analyze-benchmarks --save-baseline   # only if check passes (or check not requested)
```

A machine-readable summary is written to `reports/regression_report.json` when you check.

Config lives under `regression:` in [`config/benchmark_config.yaml`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/config/benchmark_config.yaml).

---

## Multi-session and multi-machine claims {#multi-session-claims}

This section is written for a **first-year university student**. Full ladder: [Claims and replication](CLAIMS_AND_REPLICATION.md).

### Why one run is not enough for strong claims

One full matrix on one laptop is a **snapshot**. Noise (other programs, thermal state, cloud neighbors) can move ranks a little. Stronger language needs **more races**:

| Level | Evidence | Example claim |
|-------|----------|---------------|
| **L1** | One session, one host | “On this machine, this session, ….” |
| **L2** | ≥3 sessions, same known `machine_id` | “Stable across repeated sessions on this host….” |
| **L2 (host unknown)** | ≥3 sessions, missing sidecars | “Repeated sessions, but host fingerprint missing….” |
| **L3** | ≥2 distinct `machine_id`s | “Consistent across machines in this set….” |

Default Dashboard packed latest is **L1**. Sidecars store `environment.machine_id` so analysis can tell hosts apart.

### Aggregate several CSVs

```bash
analyze-benchmarks --list -l python
analyze-benchmarks \
  --multi-session python:STEM1 \
  --multi-session python:STEM2 \
  --multi-session python:STEM3
```

Writes `reports/multi_session_<lang>.json` and `.md` with:

- median-of-session-medians and IQR across sessions  
- how often each serializer is fastest (rank stability)  
- heuristic `claim_level` (`L2_…` / `L3_…`)

For research-oriented L2/L3 collection tips and soft host checks, see [Claims and replication](CLAIMS_AND_REPLICATION.md).

---

## Outputs

| Output | Content |
|--------|---------|
| `reports/stats_<lang>_latest.json` | Multi-policy stats export (Dashboard sync input; **always** written) |
| `reports/<docs_dir>/results.md` | Unpublished language report (pivot tables + exploratory-rank banner). Default on; `--no-markdown-report` skips. `csharp` → `reports/c-sharp/results.md`. Do not commit to the site. |
| `reports/plots/violin/*.png` | Combined mean bars (serialize/deserialize) plus split violin shapes (µs, linear from 0; top five by mean total). **Opt-in** via `--violins`. |
| [Dashboard](../dashboard/) | Published L1 numbers (packed via `sync-data.py`; not written by the CLI) |
| `logs/<lang>/*.configs.json` | Run sidecar: environment (`machine_id`, optional governor), dataset / serializer metadata (legacy `*.environment.json` still works) |
| `reports/multi_session_<lang>.json` / `.md` | Optional L2/L3 aggregate from `--multi-session` |
| Console | Load counts, warmup and outlier tallies |

Latency charts use the **same** sanitized records as the summary tables. There is no separate hidden filter for plots. Display may still limit charts to the top five serializers by mean time; that does not change table membership.

How to run the CLI: `analyze-benchmarks` writes `reports/`; pack the Dashboard with `python3 dashboard/scripts/sync-data.py`. Claim levels: [Claims and replication](CLAIMS_AND_REPLICATION.md).

---

## Limitations {#limitations}

Honest methodology includes what the suite **cannot** claim.

- **Cross-language absolute times** are directional at best. Garbage collection, allocators, and runtimes differ. Prefer within-language ranks and effect sizes.
- **Run order:** default benchmark-runner schedule is **block_shuffle** (serializers reshuffled each rep within a cell×mode). This reduces thermal/order confounds vs serializer-outer fixed order. Escape hatch: `BENCHMARK_SCHEDULE=none`. See [architecture — schedule](architecture.md#timed-trial-schedule).
- **C** default builds may use portable stand-ins under real library names—see the [C overview](../c/index.md).
- **Rust** paths such as `prost`, `rkyv`, and `minicbor` use concrete native codecs; timed `rkyv` deserialize **materializes** owned values for fidelity—see the [Rust overview](../rust/index.md).
- **Stream** mode is not always a true incremental API. New runs must label stream rows with CSV `StreamMode` (`native` / `text_on_stream` / `adapted`). Languages that only alias bytes must **not** emit stream rows. See [Modes — stream honesty](modes.md#three-levels-of-stream-honesty).
- **Fidelity** is semantic or structural, not bit-identical across formats.
- Outlier removal and warmup policy affect means; always read `runs`, confidence intervals, and effect sizes together.

### Methodological disclosures (for careful readers)

- **Bootstrap reproducibility:** each group gets a *derived* seed (base bootstrap seed mixed with a stable hash of language + serializer + data type + mode + series prefix) so intervals are independent across groups yet fully reproducible.
- **Paired series:** serialize, deserialize, and total times share one all-or-nothing keep-mask.
- **Mann–Whitney:** uses SciPy when available (tie-aware); otherwise a pure-NumPy fallback with tie-corrected variance and continuity correction.
- **Regression gates:** default combine is **and** (practical % and CI support). `--save-baseline` is skipped when `--check-regression` fails, so a degraded run cannot overwrite the gate baseline. See [Regression gate](#regression-gate).
- **Effect vs fastest:** reference is **median** total by default; Mann–Whitney + **within-group Holm** when hypothesis tests are enabled. Multi-way ranks are **exploratory** ([Exploratory ranks](#exploratory-ranks)).
- **Claim scope:** default Dashboard packed latest is **L1** single-session / single-host. Multi-session tooling does not rewrite the Dashboard automatically ([Claims and replication](CLAIMS_AND_REPLICATION.md)).
- **Cliff’s δ for large N:** if the full pair count exceeds about two million, a seeded 100 000-pair random sample is used.
- Some documented config keys are parsed for documentation but do not yet change runtime behaviour; the implementation still computes the full rich metric set.

## References

### Wikipedia (statistical terms used on this page)

| Term | Link |
|------|------|
| Interquartile range (IQR) | [en.wikipedia.org/wiki/Interquartile_range](https://en.wikipedia.org/wiki/Interquartile_range) |
| John Tukey | [en.wikipedia.org/wiki/John_Tukey](https://en.wikipedia.org/wiki/John_Tukey) |
| Confidence interval | [en.wikipedia.org/wiki/Confidence_interval](https://en.wikipedia.org/wiki/Confidence_interval) |
| Bootstrapping | [en.wikipedia.org/wiki/Bootstrapping_(statistics)](https://en.wikipedia.org/wiki/Bootstrapping_%28statistics%29) |
| Effect size | [en.wikipedia.org/wiki/Effect_size](https://en.wikipedia.org/wiki/Effect_size) |
| Cliff’s delta | [Effect size § ordinal data](https://en.wikipedia.org/wiki/Effect_size#Effect_size_for_ordinal_data) |
| Hedges’ g | [Effect size § Hedges' g](https://en.wikipedia.org/wiki/Effect_size#Hedges'_g) |
| Mann–Whitney U test | [en.wikipedia.org/wiki/Mann–Whitney_U_test](https://en.wikipedia.org/wiki/Mann%E2%80%93Whitney_U_test) |
| Holm–Bonferroni method | [en.wikipedia.org/wiki/Holm–Bonferroni_method](https://en.wikipedia.org/wiki/Holm%E2%80%93Bonferroni_method) |
| P-value | [en.wikipedia.org/wiki/P-value](https://en.wikipedia.org/wiki/P-value) |
| Multiple comparisons problem | [en.wikipedia.org/wiki/Multiple_comparisons_problem](https://en.wikipedia.org/wiki/Multiple_comparisons_problem) |
| Family-wise error rate | [en.wikipedia.org/wiki/Family-wise_error_rate](https://en.wikipedia.org/wiki/Family-wise_error_rate) |
| Nonparametric statistics | [en.wikipedia.org/wiki/Nonparametric_statistics](https://en.wikipedia.org/wiki/Nonparametric_statistics) |
| Median | [en.wikipedia.org/wiki/Median](https://en.wikipedia.org/wiki/Median) |
| Median absolute deviation | [en.wikipedia.org/wiki/Median_absolute_deviation](https://en.wikipedia.org/wiki/Median_absolute_deviation) |
| Winsorizing | [en.wikipedia.org/wiki/Winsorizing](https://en.wikipedia.org/wiki/Winsorizing) |

### Other

- Tukey, J.W. (1977). *Exploratory Data Analysis* (IQR fences).
- [Seaborn violin / catplot](https://seaborn.pydata.org/generated/seaborn.catplot.html).
