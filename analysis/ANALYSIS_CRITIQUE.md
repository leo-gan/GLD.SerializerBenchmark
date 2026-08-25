# Analysis Package — Research, Critique & Improvement Proposals

**Date:** 2026-07-01  
**Branch:** fix/analysis  
**Scope:** `analysis/` Python package + its use in the repo (CLI, reports, stats, integration with harnesses and docs).

This document is the output of a full source + runtime + config + output review of the `benchmark-analysis` package.

---

## What the package does

Small, installable package (`benchmark-analysis`) that consumes language-agnostic CSV logs and produces:

- Scientific per-group statistics (warmup drop, IQR filtering, bootstrap CI, Cliff’s δ, Hedges’ g, Mann–Whitney + Holm)
- Markdown summaries and per-language results pages under `docs/<lang>/results.md`
- Violin plots (seaborn)
- Regression gate vs baseline
- A/B version comparison

Primary entry: `analyze-benchmarks` console script.

It sits between raw harness output (timestamped `logs/<lang>/YYYY-MM-DD-HHMMSS.csv`) and published documentation.

---

## Research performed

- Full source read of `src/benchmark_analysis/{cli,parser,stats,reports,regression,__init__}.py`
- Tests (`tests/test_parser.py`, `tests/test_stats.py`)
- `pyproject.toml`, README, existing `CRITIQUE_AND_IMPROVEMENTS.md`
- Master config `config/benchmark_config.yaml` (statistics:, csv_schema:, regression:, languages:, etc.)
- Generated outputs: `docs/<lang>/results.md`, violin plots (`BENCHMARK_SUMMARY.md` is static)
- Actual log files (tiny current samples) + live execution through the pipeline
- Call sites: `scripts/run-all-benchmarks.sh`, docs, methodology
- Runtime behavior: config loading, time-unit handling, pivot generation, violin preprocessing vs stats preprocessing

---

## Strengths (what is good)

1. **Stats core is appropriate for the problem domain**  
   Non-parametric bootstrap CI, effect sizes (Cliff’s δ + Hedges’ g) vs the fastest in each `(language, test_data, mode)` group, Holm-corrected Mann–Whitney for A/B. This is genuinely better than the mean-only tables common in serializer benchmarks.

2. **Language-agnostic contract + discovery**  
   `Language` column + auto-discovery of latest timestamped CSV under `logs/<lang>/` + `--logs LANG=PATH` means adding Go/Java/etc. does not require analysis changes.

3. **Config-driven with safe fallbacks**  
   `load_stats_config()` walks upward for `benchmark_config.yaml`; works even if PyYAML or the file is absent.

4. **Methodology documentation exists and is mostly honest** (`docs/analysis/ANALYSIS_METHODOLOGY.md`).

5. **A/B compare path and regression skeleton** are first-class (even if the regression implementation is weak).

6. **Published snapshots are intentionally local** — CI does not fabricate numbers. This is the right model.

---

## Critique (categorized, with evidence)

### 1. Rich statistics are computed but barely surfaced (HIGH)

`compute_statistics()` produces:
- per-group bootstrap CIs
- median, MAD, CV, multiple percentiles
- `effect_vs_fastest_cliffs_delta` + label + Hedges’ g + MWU/Holm p (A-1; exploratory multi-way)
- fidelity, memory, warmup/outlier counts
- `_times_total_filtered` for further tests
- multi-session aggregate path (`--multi-session`, claim levels L1–L3) for A-6/B-3

**What actually appears in published docs:**

- Pivot tables: only `avg_time_total_ns` and `avg_ops_per_sec` (means)
- One arbitrary sample under “Scientific metrics” (e.g. “MS Binary / message / string”)
- No table of CIs or effect sizes for all serializers

Result: the package advertises publication-grade methods while the user-visible product is still largely spreadsheet-era means. The expensive stats work has low ROI today.

Evidence: `docs/c-sharp/results.md` (and siblings), `generate_language_results_pages()`, `_pivot_table_md()`.

### 2. Regression detection is statistically naive and dangerous for multi-lang (HIGH)

`regression.py` + CLI usage:

- Only compares `avg_time_total_ns` with a flat percentage threshold (default 10%).
- Baseline key now includes language (`language|serializer|test_data|mode`). (Older versions of the code lacked it.)
- Ignores the CIs, effect sizes, and sample sizes that `stats.py` already computed.
- No persistence of the full statistical context.

Current logs are tiny (2–12 rows). On real runs this will produce both false regressions (noise) and missed real ones.

Config declares `regression:` section; it is not consumed by the analysis package (the shell script passes `--regression-threshold`).

### 3. Time unit handling is fragile and duplicated (HIGH)

Two separate heuristics:

- `stats.py:normalize_to_nanoseconds()` — identity; all harnesses emit nanoseconds.
- `reports.py:_records_to_melted_df()` — median >1e6 → ×100 again.

Config says:
- `csv_schema.time_unit: nanoseconds`
- - `languages.csharp.time_unit: nanoseconds`

None of these are actually read by analysis code for normalization.

If any C# runner starts emitting nanoseconds, or a slow Python row exceeds the heuristic, published numbers will be silently 100× wrong.

Current logs confirm C# and Python rows often lack an explicit `Language` column; path inference is the only thing saving them.

### 4. Outlier filtering & preprocessing divergence (MEDIUM-HIGH)

- Stats: IQR on total (configurable), applied separately to ser/deser/total series.
- Plots: global `q99 * 10` clip + per-serializer p99 winsorization + different log-scale logic.
- Filtering on ser/deser/total is independent → a row can contribute to one mean but not another.

Violin plots therefore do not reflect the exact samples used for the tables/CIs they sit next to.

### 5. Config surface area vs implementation (MEDIUM)

Loaded but unused (or only partially used):

- `report_mean`, `report_median`, `report_std`, `report_mad`, `report_cv`, `report_min_max`
- `bootstrap.method` (only “percentile”; “bca” documented)
- `effect_sizes.methods`
- `hypothesis_tests.method`
- `throughput_from`
- Most of `csv_schema` beyond the columns list
- `regression:` block

`report_percentiles` is the only “report_*” knob that is honored.

This creates a false sense of configurability and makes the methodology doc lie slightly.

### 6. Legacy API and CLI migration debt (MEDIUM) — partially addressed

- **Done:** per-lang `--*-logs` / `--extra-logs` replaced by unified `--logs` + `-l` / `--language`.
- Hub `BENCHMARK_SUMMARY.md` is static; not generated by the CLI.
- Hard-coded language lists remain in multiple places (`_LANG_ORDER`, CLI known langs, orchestrator script).
- Heavy imports (matplotlib, seaborn, pandas) live in `reports` (CLI lazy-imports for generate path).

### 7. Statistical implementation details (MEDIUM)

- `mann_whitney_u` uses normal approximation without full tie correction and without exact test for small n.
- Single fixed bootstrap seed (42) for everything — reproducible but not independent across groups.
- `cliffs_delta` has a fast path and a sampling fallback; sampling size (100k) is arbitrary.
- No validation that ser + deser means relate to total after filtering.

### 8. Testing, packaging, and robustness gaps (MEDIUM-LOW)

- Good unit coverage on core stats primitives; almost zero on:
  - reports generation
  - regression
  - compare_versions
  - CLI behavior
  - end-to-end with real log shapes
- Tests use `sys.path.insert` hacks instead of relying on editable install + `pythonpath`.
- Parser: `int(float(...))` truncation; bad rows only `print` + skip (no structured error count or non-zero exit).
- No JSON export of the full stats dict (very useful for notebooks / dashboards / CI artifacts).
- `docs_root` heuristic (`basename == "analysis"`) is brittle.
- Empty `analysis/scripts/` directory.

### 9. Minor / UX

- Default invocation with no flags just says “No action specified”.
- When using `--output-dir reports`, it can still mutate `docs/<lang>/results.md` depending on heuristics.
- `generate_markdown_summary` removed; hub is hand-maintained.
- No typed record / stats models (pure dicts).

---

## Prioritized improvement proposals

### P0 (do these before serious publication or CI gating)

1. **Surface the science**  
   Add at least one more table (or downloadable `stats.json`) that shows mean + CI + median + Cliff’s δ + n for every (serializer, data, mode) group. Make effect sizes visible in the published pages.

2. **Fix regression** — **done (A-4)**  
   - Language + batch axes in baseline key; default **AND** (practical % + CI support).  
   - Baseline v2 stores median, CI, n, optional samples; Cliff’s δ diagnostic when samples exist.  
   - `reports/regression_report.json` on check; see methodology “Regression gate”.

3. **Make time units explicit and single-source**  
   Either:
   - Add a `TimeUnit` column (or `TimeSerUnit`) to the CSV contract, or
   - Read `languages.<lang>.time_unit` + `csv_schema` and stop using magnitude heuristics + dual code paths.
   Remove the second heuristic from reports.

4. **Single source of truth for filtering**  
   Compute one mask from the primary series (total time) and reuse it for ser/deser, or clearly document+label that plots use different cleaning.

### P1 (architecture & fidelity)

5. Retire the legacy csharp/python-only report paths. Keep thin compatibility shims for one cycle if needed. Drive everything from the multi-lang dicts.

6. Lazy-load plotting libraries (or move plot generation behind an import guard) so pure regression / stats use cases stay lightweight.

7. Align (or explicitly separate) violin preprocessing with the stats pipeline. Add a note in plots and methodology.

8. Either implement the other bootstrap method (BCa) or remove the option from config/docs. Same treatment for the unused `report_*` flags and `effect_sizes.methods`.

9. Add a `--format {md,json,console}` and/or always emit a machine-readable `stats.json` next to markdown.

### P2 (correctness, testing, DX)

10. Add a `BenchmarkRecord` TypedDict / dataclass and a `GroupStats` model. Gradually type the hot path.

11. Expand tests:
    - Golden CSV round-trips with known stats.
    - Regression key includes language; multi-lang baseline test.
    - CLI smoke with temp dirs and `--check-regression`.
    - Report generation string contains expected sections.
    - Time unit: nanoseconds for all languages (including C#).

12. Make parser stricter or at least return `(records, errors)` so callers can decide to fail.

13. Fix docs_root / output-dir policy: `--output-dir reports` should stay scratch-only unless `--publish-docs` or similar is passed.

14. Default action: when no flags, print a short console summary (top 3 fastest per language + note about CIs).

15. Consume `environment.json` (if present) and surface hardware/OS summary in report headers.

### P3 (nice to have)

16. Optional scipy exact tests for small-n Mann–Whitney (behind a soft dependency).
17. Rank stability via bootstrap (probability a serializer is fastest).
18. Remove or populate the empty `analysis/scripts/`.
19. Consider a small `analysis/py.typed` + mypy/pyright in CI for the package.

---

## Concrete discrepancies found (config vs code)

| Declared | Used in analysis? | Notes |
|----------|-------------------|-------|
| `statistics.report_mean` etc. | No (except percentiles) | Flags exist only in defaults |
| `bootstrap.method: bca` | No | Only percentile path |
| `effect_sizes.methods` | No | Hard-coded calls to cliffs + hedges |
| `hypothesis_tests.method` | No | Always mann_whitney_u |
| `throughput_from` | No | Always `1e9 / mean` |
| `csv_schema.time_unit*` + `languages.*.time_unit` | No | Heuristics + hard-coded csharp rule win |
| `regression:` block | Partially (threshold + CI lower-bound) | Language now included; still limited vs full MWU+δ |
| `reproducibility.capture_environment` | Analysis never reads the file | Only mentioned in docs |

---

## Recommended immediate next actions (on this branch or follow-ups)

1. Write the surfaced-science tables + `stats.json` emission (P0).
2. Rewrite regression with language-aware keys + CI/δ awareness (P0).
3. Add explicit time-unit handling from config or column (P0).
4. Update `ANALYSIS_METHODOLOGY.md` + this file with the decisions.
5. Add a couple of high-value tests and a JSON export.
6. Clean the legacy flag paths in CLI + the orchestrator script.

---

## Bottom line

The analysis package has a **strong statistical foundation** and the right high-level architecture for a multi-language, research-grade benchmark. However, it currently **under-delivers** on that foundation:

- Most of the sophisticated numbers are computed and then discarded.
- Critical normalization (time) and filtering policies are heuristic and duplicated.
- The regression gate and published reports are not yet worthy of the stats module.
- Config promises more than the code delivers.

Fixing the P0 items (surfacing, regression, time units, single filtering policy) would make the package match its own ambitions and the claims in the methodology document.

This is a high-leverage, contained Python package — changes here have immediate visible impact on every published result page and any future CI quality gate.

---

*This document can be regenerated or extended as the package evolves. Original research performed via full source review + live execution on 2026-07-01.*
