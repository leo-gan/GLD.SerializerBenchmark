# Benchmark architecture

**Job of this page:** how the suite is laid out, who it serves, how the harness times work, and where config lives.

| For this instead… | Go here |
|-------------------|---------|
| Statistics (warmup, IQR, bootstrap, effect sizes) | [Analysis methodology](ANALYSIS_METHODOLOGY.md) |
| Fixtures and size knobs | [Test Data](test_data_configuration.md) |
| Paradigms / registered families | [Serialization categories](serialization_categories.md) |
| Extending the matrix | [Adding a language](ADDING_A_LANGUAGE.md) |
| Published numbers | [Benchmark Results](BENCHMARK_SUMMARY.md) · language **Results** |

---

## Goals (four audiences, one pipeline)

Everyone uses the **same harness contract and analysis path**; the question changes.

| Audience | Primary question | Suite hooks |
|----------|------------------|-------------|
| **Researchers** | Are within-language rankings defensible? | Fixed fixtures, modes (`smoke`…`research`), warmup exclusion, IQR, bootstrap CIs, effect sizes — details in [methodology](ANALYSIS_METHODOLOGY.md) |
| **Serializer authors** | Did *this* library get better or worse? | Stable names/fixtures; `analyze-benchmarks --compare-a` / `--compare-b`; optional `--check-regression` |
| **System integrators** | What fits *our* shapes and runtime? | Tunable `test_data_config.json`, dual I/O modes, language inventories, same CSV path for private runs |
| **Maintainers** | Add a language without rewriting analysis? | Registry in `benchmark_config.yaml` + checklist in [Adding a language](ADDING_A_LANGUAGE.md) |

**Typical paths**

- Research / publish snapshot: `./scripts/run-all-benchmarks.sh -m full -b` → `analyze-benchmarks` → commit language **Results** / plots.  
- Author A/B: two CSVs of the same language → `analyze-benchmarks --compare-a lang:stampA --compare-b lang:stampB`.  
- Integrator: adjust fixture sizes → one-language harness → private or committed **Results**.

---

## Repository layout

| Path | Role |
|------|------|
| `config/benchmark_config.yaml` | Modes, stats defaults, language registry, CSV schema |
| `schemas/` | `test_data_config.json`, protos, shared shape knobs |
| `logs/<language>/` | Timestamped result CSVs (`YYYY-MM-DD-HHMMSS.csv`, gitignored) |
| `analysis/` | Python analysis package (CLI: `analyze-benchmarks`) |
| `python/` · `c-sharp/` · `rust/` · `c/` · `javascript/` · `go/` · `java/` · `cpp/` · `swift/` | Language harnesses |
| `docs/` | MkDocs site (inventories, results snapshots, analysis pages) |
| `scripts/run-all-benchmarks.sh` | Multi-language orchestrator |

Published site numbers are regenerated **locally** into `docs/<lang>/results.md` and `docs/analysis/plots/violin/`. CI deploys MkDocs only ([regeneration](BENCHMARK_SUMMARY.md#regenerating-language-snapshots)).

---

## Measurement model

What is timed (and what is not):

1. **Untimed prepare** — codecs, schemas, buffers, serializer-native model build (language-specific; Rust often folds prepare into one step before the loop).  
2. **Timed loop** (each repetition `i`):
   - `serialize(obj)` → `TimeSer`
   - `deserialize(bytes)` → `TimeDeser`
   - fidelity check (failure → errors CSV; not a performance win)
3. **Warmup** — repetition `i = 0` is excluded from aggregates by analysis.

CSV modes are **I/O API paths** (`bytes` / `stream`, or legacy C# `string` / `stream`)—not payload size labels. Results pages show them as **bytes mode** / **stream mode**.

---

## Harness contract (summary)

| Requirement | Detail |
|-------------|--------|
| Output | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` matching `csv_schema` |
| `Language` column | Language id (`csharp`, `python`, `rust`, …) |
| Time unit | **Nanoseconds** for all harnesses (including C#) |
| Modes | `bytes` / `stream` (C# may use `string` / `stream`) |
| Timed section | Serialize + deserialize only |
| Fidelity | Round-trip check; failures → `logs/<lang>/<ts>.errors.csv` |
| Seed | `schemas/test_data_config.json` / config `reproducibility.random_seed` |

Full implementer checklist: [Adding a language](ADDING_A_LANGUAGE.md).

---

## Analysis pipeline (pointer only)

CSV → normalize units → drop warmup → optional IQR → descriptive stats → bootstrap CI on mean → within-group effect sizes → optional A/B tests.

Defaults: `statistics:` / `modes:` in `config/benchmark_config.yaml`. **Authoritative detail:** [Analysis methodology](ANALYSIS_METHODOLOGY.md).

---

## Run modes (repetitions)

From `modes:` in `config/benchmark_config.yaml` (do not hard-code counts in runners—use `bench_mode_reps`):

| Mode | Repetitions | Intent |
|------|-------------|--------|
| `smoke` | 2 | Minimal sanity / CI fast path |
| `all-single` | 10 | Quick full-matrix pass |
| `full` | 100 | Publication-quality run |
| `research` | 500 | High-power statistical study |

Warmup policy: harnesses **always log** every successful rep (including index 0). Analysis drops `RepetitionIndex == 0` when `statistics.exclude_warmup` is true (`reproducibility.warmup_repetitions` = **1**). Outlier filtering is analysis-only as well — raw `logs/<lang>/*.csv` files are never rewritten by the stats pipeline.

## Configuration map

| Concern | File / page |
|---------|-------------|
| Run modes, stats, languages, paths | `config/benchmark_config.yaml` |
| Payload shape and seed | `schemas/data_catalog_v2.yaml` + `config/library/` — [Test Data](test_data_configuration.md) |
| Paradigm inventories | [Serialization categories](serialization_categories.md) + language **Overview** pages |
