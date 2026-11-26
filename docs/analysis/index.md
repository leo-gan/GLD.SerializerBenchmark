# Benchmarks

This section specifies the experimental protocol used to evaluate serialization libraries across all fourteen language runners: vocabulary, payload shapes, runner architecture, timing contracts, statistical cleaning, and claim-strength boundaries. Conceptual wire-format foundations live under **[Learn](../theory/index.md)**; live interactive results live on the **[Dashboard](../dashboard/index.html)**; per-language runtime details and rosters live under **[Languages](../languages/index.md)**.

## Measurement Pipeline

Each language directory contains a standalone **benchmark runner** that generates deterministic payloads, executes timed serialize/deserialize cycles under a block-shuffled trial schedule, verifies round-trip semantic fidelity, and emits raw CSV records. A shared Python analysis package (`analyze-benchmarks`) then excludes warmup, applies configurable outlier filters, computes bootstrap intervals and effect sizes, and exports multi-policy summaries consumed by the Dashboard.

```text
  benchmark runner (14 languages)
       │  untimed prepare → block-shuffled timed serialize + deserialize → untimed fidelity
       ▼
  logs/<language>/YYYY-MM-DD-HHMMSS.csv  (+ *.configs.json sidecar)
       │
       ▼
  analyze-benchmarks  (warmup drop, outlier policies, bootstrap CI, effect sizes)
       │
       └──► reports/stats_<lang>_latest.json  ──► sync-data.py ──► Dashboard (L1)
```

## Protocol Roadmap

| Section | Pages | Purpose |
|---|---|---|
| **Experimental Design** | [Terminology](terminology.md) · [Architecture & schedule](architecture.md) · [Timing contract](TIMING_HONESTY.md) · [I/O & run modes](modes.md) · [Format families](families.md) | Canonical vocabulary, repository layout, trial randomization, prepare vs. timed boundary, API/run modes, and teaching taxonomy. |
| **Data Sets** | [Data sets overview](test_data_configuration.md) · [Suite](suite.md) · [Columnar](columnar.md) · [Graph](graph.md) · [Array](array.md) · [Tensor](tensor.md) | Shared generator contract (`make_one`), batching ($W \times C$), wall-clock budget, and schemas for all 17 data types across 5 sets. |
| **Statistical Protocol** | [Methodology](ANALYSIS_METHODOLOGY.md) · [Metrics catalog](METRICS.md) · [Claims & replication](CLAIMS_AND_REPLICATION.md) | Warmup exclusion, Tukey IQR / Winsorization, percentile bootstrap CIs, Cliff's $\delta$, Hedges' $g$, Holm-adjusted Mann–Whitney $U$, regression gates, and L1/L2/L3 evidence tiers. |
| **Call-Site Notes** | [Call-site catalog](call-sites/index.md) (17 per-language notes) | Source-level walkthroughs of paired timed adapters on `document` ($n = 1$, `bytes`), complementing the five canonical labs in [Serialization 401](../theory/401/index.md). |
| **Extending the Suite** | [Adding a serializer](ADDING_A_SERIALIZER.md) · [Adding a language](ADDING_A_LANGUAGE.md) | Contributor checklists for registering a new codec or onboarding a new language runner. |

## Fair Comparison Rule

Controlled implementation comparisons hold four experimental axes fixed:

> **Same language + same standard + same data set + same data type (and batch size $N$)**

Comparing libraries across different standards conflates wire-format semantics with codec engineering; treat cross-standard tables as trade-off analyses rather than implementation rankings. Absolute latencies across languages additionally conflate compilers, garbage collectors, and allocators, and serve as rough orientation only ([Methodology limitations](ANALYSIS_METHODOLOGY.md#limitations)). For per-language rosters and runtime caveats, see **[Languages](../languages/index.md)**.
