# Analysis methodology

**Job of this page:** how the `analysis` package turns harness CSVs into group statistics, effect sizes, published **Results** tables, and violin plots.

| For this instead… | Go here |
|-------------------|---------|
| What the harness times / suite layout | [Benchmark architecture](architecture.md) |
| Fixture meanings | [Test data types](test_data_configuration.md) |
| Paradigms | [Serialization categories](serialization_categories.md) |
| How to regenerate site snapshots | [Benchmark Results](BENCHMARK_SUMMARY.md#regenerating-language-snapshots) |

Defaults: `statistics:` and `modes:` in [`config/benchmark_config.yaml`](../../config/benchmark_config.yaml). Regenerate **locally** (`analyze-benchmarks`); CI does not re-run analysis.

---

## Inputs

| Source | Role |
|--------|------|
| `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` | Per-language harness output under `logs/csharp`, `logs/python`, `logs/rust`, `logs/c`, `logs/javascript`, `logs/go` (gitignored) |
| `Language` column | Language id (`csharp`, `python`, `rust`, `c`, `javascript`, `go`, …) |
| `csv_schema` in master config | Required / optional columns |

Core columns: `StringOrStream`, `TestDataName`, `Repetitions`, `RepetitionIndex`, `SerializerName`, **`SerializerVersion`** (installed package/crate version, immediately after the name), `TimeSer`, `TimeDeser`, `Size`, `TimeSerAndDeser`, ops/sec fields. Optional: `MemoryPeakBytes`, `FidelityScore`, `NativeKind`, `StreamMode`, …

---

## Pipeline

Processing is **per group**: `(Language, SerializerName, TestDataName, StringOrStream)` unless noted.

A single function, `prepare_analysis_records` in `stats.py`, performs steps 1–3 and feeds **both** summary tables and violin plots so they cannot diverge on sample membership or units.

1. Load CSV → normalize times via central config (`csv_schema.time_unit`, optional `languages.<id>.time_unit`)  
2. Drop warmup (`RepetitionIndex == 0` when enabled)  
3. Optional **all-or-nothing** outlier filter (default Tukey IQR on ser ∧ deser ∧ total)  
4. Descriptive statistics  
5. Bootstrap CI on the mean (when enabled)  
6. Effect sizes vs fastest serializer in the group  
7. Optional version A/B tests (`--compare-a` / `--compare-b`)

### Time units

All language harnesses (including **C#**) write `TimeSer` / `TimeDeser` / `TimeSerAndDeser` in **nanoseconds**. The analysis package resolves the scale once from master config (`csv_schema.time_unit`, overridable per language) and applies the same factor everywhere — never a median heuristic or ad-hoc language name match.

Published **latency** pivots on language Results use **microseconds** (µs = ns ÷ 1000). Violin plots use **µs** and show the **top 5 serializers** by mean total time per fixture.


### Warmup exclusion

**Harnesses write full raw CSVs.** Every successful timed repetition is logged with its `RepetitionIndex` (including `0`). Runners must not drop warmup, apply IQR, or otherwise post-process before write.

**Analysis only** applies the policy: if `statistics.exclude_warmup` is true (default), rows with **`RepetitionIndex == 0`** are dropped inside `prepare_analysis_records` before outlier filtering and summaries. That removes typical JIT / static-init / cold-cache spikes. Counts: `warmup_skipped`; `runs_raw` is the pre-warmup size (still reflected from the full log).

Harness guidance lists `reproducibility.warmup_repetitions` in config (currently **1** leading rep treated as warmup by analysis).

### Outlier filtering

Default: **Tukey IQR** (`statistics.outlier_method: iqr`, `iqr_k: 1.5`), applied **all-or-nothing** across the paired metrics of each repetition.

| Rule | Default behavior |
|------|------------------|
| Fences | `[Q1 − k·IQR, Q3 + k·IQR]` computed **separately** on ser, deser, and total |
| Keep rule | A row is kept only if it is **inside all three** fences (union of outlier flags) |
| Group size | Apply only if ≥ `min_samples_for_outlier_filter` (10) |
| IQR = 0 (per metric) | That metric contributes an all-keep mask |
| Would drop entire group | Keep original series |
| Method `none` | Skip filtering |
| Method `winsorize` | Clip each series at p5/p95; never drop rows |

Removed count: `outliers_removed`. Final sample size: `runs` (identical for ser, deser, and total). IQR reduces rare GC/scheduling stalls on the **mean**; still report dispersion and CIs.

### Descriptive statistics (per group)

| Kind | Metrics |
|------|---------|
| Central tendency | Mean and median of ser / deser / total times |
| Dispersion | Std, MAD, CV, min/max, percentiles (default 5, 25, 50, 75, 95, 99) |
| Size | Median serialized `Size` (bytes) |
| Throughput | Ops/s from mean total time |
| Provenance | `runs`, `runs_raw`, `warmup_skipped`, `outliers_removed` |

**Display-only** on language `results.md` (CSV unchanged):

- I/O modes labeled **bytes mode** / **stream mode** (API path, not payload size)  
- Large numbers: single unit per column (K or M) with ~2 significant digits  
- **Bold** = semantic best cell (lowest time; highest ops/s; ties all bolded)  
- **Rust** pages also include within-category mean ops/s rankings (bytes mode)

### Bootstrap CI on the mean

When `statistics.bootstrap.enabled` (default): **percentile** bootstrap on total-time series (`iterations` 2000, `confidence_level` 0.95, `seed` 42) → `total_ci_low_ns` / `total_ci_high_ns`.

Produced only when post-filter `n` ≥ `min_samples_for_inference` (default 5); otherwise CI fields degenerate to the point estimate.

### Effect sizes vs fastest in group

When `statistics.effect_sizes.enabled` (default), within the same language, fixture, and I/O mode, each serializer is compared to the **fastest** (lowest mean total time):

| Method | Role |
|--------|------|
| **Cliff’s δ** | Non-parametric dominance; labels via config thresholds |
| **Hedges’ g** | Bias-corrected standardized mean difference |

For **within-language** interpretation—not cross-runtime rankings.

### Version A/B (same language, two runs)

```bash
./scripts/run-all-benchmarks.sh -m full
analyze-benchmarks --compare-a csharp:190424 --compare-b csharp:191316
# or:
analyze-benchmarks --compare-a rust:185249 --compare-b rust:191316
```

Writes `reports/VERSION_COMPARE.md` (under `paths.reports_root`, default `reports/`) with percent change, Cliff’s δ, Hedges’ g, **Mann–Whitney U**, and **Holm**-adjusted p-values when `statistics.hypothesis_tests` is enabled (`alpha` 0.05). Prefer this for author-facing regressions rather than comparing unrelated libraries.

Regression gates: `analyze-benchmarks --check-regression` against `paths.baseline_filename` (default `reports/baseline.json`); save with `--save-baseline`.

---

## Outputs

| Output | Content |
|--------|---------|
| `docs/<lang>/results.md` | Pivot tables + violin embeds for one language |
| `docs/analysis/plots/violin/*.png` | Split violins: ser vs deser (µs; top 5 by mean total; log scale when medians span ≥5×) |
| `docs/analysis/BENCHMARK_SUMMARY.md` | **Static** hub of links (not regenerated) |
| Console | Load counts, warmup/outlier tallies |

Violins consume the **same** sanitized records as the summary tables (shared `prepare_analysis_records` output). No separate q99 tail clip or independent per-operation IQR. Display may still limit to the top 5 serializers by mean time for readability; that does not change table membership.

How to run the CLI: [Benchmark Results — regenerating](BENCHMARK_SUMMARY.md#regenerating-language-snapshots).

---

## Limitations

- **Cross-language absolute times** are directional at best (GC, allocator, runtime differ). Prefer within-language ranks and effect sizes.  
- **C** default builds may use portable stand-ins under real library names—see [C overview](../c/index.md).  
- **Rust** `prost` / `rkyv` / `minicbor` use concrete native paths; timed `rkyv` deserialize **materializes** owned values for fidelity—see [Rust overview](../rust/index.md).  
- **Stream** mode is not always a true incremental API (some harnesses buffer then write).  
- **Fidelity** is semantic/structural, not bit-identical across formats.  
- Outlier removal and warmup policy affect means; consider `runs`, CIs, and effect sizes.

### Methodological disclosures

- **Bootstrap reproducibility:** each group gets a *derived* seed (base `statistics.bootstrap.seed` mixed with a stable hash of language + serializer + fixture + mode + series prefix) so CIs are independent across groups yet fully reproducible.  
- **Paired series:** `times_ser`, `times_deser`, and `times_total` share one all-or-nothing keep-mask (outlier on any metric drops the whole row).  
- **Mann–Whitney:** `scipy.stats.mannwhitneyu` when available (tie-aware asymptotic method); pure-numpy fallback with tie-corrected variance + continuity correction.  
- **Regression gates:** `--save-baseline` is skipped when `--check-regression` detects a failure, so a degraded run cannot overwrite the gate baseline.  
- **Cliff’s δ for large N:** if the cartesian product exceeds ~2 M pairs, a 100 k-pair random sample (seeded at 0) is used.  
- Some documented config keys (`report_*` toggles, alternate `bootstrap.method`, `effect_sizes.methods`, `throughput_from`, certain `paths.*`) are parsed for documentation but do not yet alter runtime behaviour; the implementation computes the full rich set.

## References

- Tukey, J.W. (1977). *Exploratory Data Analysis* (IQR fences)  
- Cliff’s delta; Hedges’ g; Mann–Whitney U (standard non-parametric toolkit)  
- [Seaborn violin / catplot](https://seaborn.pydata.org/generated/seaborn.catplot.html)
