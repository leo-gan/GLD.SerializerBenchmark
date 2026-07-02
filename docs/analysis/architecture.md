# Benchmark architecture

How this **benchmark suite** is laid out and how measurements flow. Goals, repo layout, harness timing model, and where config/analysis live. For statistics detail see [Analysis Methodology](ANALYSIS_METHODOLOGY.md). To extend the suite see [Adding a Language](ADDING_A_LANGUAGE.md).

## Goals

The suite is built for four overlapping audiences. Each uses the **same harness contract and analysis pipeline**, but asks different questions.

### Researchers

**Need:** Reproducible, statistically defensible comparisons—not a single mean from an uncontrolled laptop run.

**What the suite provides:** Fixed conceptual fixtures ([Test data types](test_data_configuration.md)), shared modes (`smoke` … `research` in `config/benchmark_config.yaml`), warmup exclusion, optional IQR outlier filtering, bootstrap CIs on the mean, percentiles, and within-group effect sizes (Cliff’s δ, Hedges’ g). Methods are documented in [Analysis Methodology](ANALYSIS_METHODOLOGY.md).

**Example use cases:**

- Methods section for a paper or internal report: “we used 100 repetitions (`full`), excluded `RepetitionIndex` 0, IQR *k* = 1.5, 95% bootstrap CI on mean total time.”
- Within-language ranking of JSON vs MessagePack-style codecs on **Person** and **Telemetry**, with effect sizes vs the fastest serializer in each group—not cross-runtime “X is faster than Y” claims.
- Sensitivity checks: re-run with `research` (500 reps) on one language when CIs are wide on `all-single` (10 reps).

**Example workflow:** run `./scripts/run-all-benchmarks.sh -m full -b`, then `analyze-benchmarks`, and cite tables/plots on [Rust Results](../rust/results.md). Use `--compare-a rust:185249 --compare-b rust:191316` (or similar) for A/B serializer changes and `--check-regression` for gates.


### Serializer authors

**Need:** Compare **version A vs version B of the same library** (or two builds/flags) under an identical matrix, without rewriting the benchmark harness.

**What the suite provides:** Stable `SerializerName` / fixture / mode groups and `analyze-benchmarks --compare-a` / `--compare-b` (Mann–Whitney U, Holm adjustment, effect sizes, % change → `VERSION_COMPARE.md`). Authors implement or tweak one harness entry and keep everything else fixed.

**Example use cases:**

- After optimizing `orjson` encode path: run Python harness twice (or on two checkouts), run with two different versions, then  
  `analyze-benchmarks --compare-a python:YYYY-MM-DD-first --compare-b python:YYYY-MM-DD-second`.
- Release checklist: fail CI-style gates with `--check-regression` against a committed `baseline.json` when mean total time regresses beyond a threshold (e.g. 10%).
- Feature flags: same package, “with shared refs” vs “without,” as two registered names or two CSV runs, still using the same **Person** / **ObjectGraph** fixtures.

**Example workflow:** change only the library under test in `python/` (or another harness), keep `schemas/test_data_config.json` and modes unchanged, compare CSVs with the analysis CLI.

### System integrators

**Need:** Answer “which serializer fits **our** payloads and environment?” while keeping metrics comparable to a known methodology.

**What the suite provides:** Dual I/O modes (`bytes` / `stream` where applicable), configurable collection sizes and seed in `schemas/test_data_config.json`, language-local inventories (what is actually registered), and the same CSV + analysis path so integrator-specific runs remain interpretable next to published snapshots.

**Example use cases:**

- Tune **Telemetry** measurement counts or **StringArray** length toward production message sizes, re-run one language’s harness, regenerate **Results** for an internal doc—not for claiming global rankings.
- Choose between `msgspec` and `orjson` for a Python service: same fixtures and modes, read pivot ops/s and violin spread on [Python Results](../python/results.md) (or a private regen).
- Validate that “stream” mode in a candidate library behaves acceptably vs buffer APIs for large **EDI_835**-shaped documents before adopting it in a pipeline.
- Pin `reproducibility.random_seed` / config so two teams in different regions reproduce the same conceptual payload sizes.

**Example workflow:** edit only `test_data_config.json` (or a fork of fixtures), run `./python/scripts/run-benchmarks.sh full`, analyze into `reports/` or a private docs branch.

### Maintainers (suite / multi-language)

**Need:** Add or fix languages and docs **without rewriting analysis** every time.

**What the suite provides:** Language registry and CSV contract in `config/benchmark_config.yaml`, auto-discovery of timestamped CSVs under `logs/<lang>/`, shared modes, and a checklist in [Adding a Language](ADDING_A_LANGUAGE.md). Analysis stays language-agnostic given the contract.

**Example use cases:**

- Add **Go**: implement harness + `run-benchmarks.sh`, register under `languages.go`, emit nanosecond CSV with `Language=go`, wire `scripts/run-all-benchmarks.sh`, add `docs/go/index.md` and MkDocs entries—analysis picks up the log without a new stats implementation.
- Port a bugfix in C# timing only inside `c-sharp/`; Rust/Python logs and analysis code stay untouched.
- Refresh GitHub Pages snapshots after a full matrix: local `analyze-benchmarks`, commit `docs/<lang>/results.md` and `docs/analysis/plots/violin/`.

**Example workflow:** follow [Adding a Language](ADDING_A_LANGUAGE.md); smoke with `--mode smoke`, then `full` before publishing results.

## Repository layout


```text
config/benchmark_config.yaml   # modes, stats defaults, language registry, CSV schema
schemas/                       # test_data_config.json, protos
logs/<language>/               # YYYY-MM-DD-HHMMSS.csv (timestamped results)
analysis/                      # Python analysis package (local reports)
python/ | c-sharp/ | rust/ | c/ | javascript/   # language harnesses
docs/                          # MkDocs site (inventories, results snapshots, this page)
scripts/run-all-benchmarks.sh  # multi-language orchestrator
```

Published site numbers: regenerate **locally** into `docs/<lang>/results.md` and `docs/analysis/plots/violin/` (see [Benchmarks overview](index.md)). CI deploys MkDocs only.

## Measurement model

```text
prepare(type)          # untimed: codecs, schemas, buffers
prepare_data(fixture)  # untimed: serializer-native model
for i in 0..N-1:
    t0 = now()
    bytes = serialize(obj)
    t1 = now()
    obj2 = deserialize(bytes)
    t2 = now()
    assert fidelity(fixture, obj2)
    log(ser=t1-t0, deser=t2-t1, size=len(bytes), i)
```

Repetition `i = 0` is warmup and is excluded from aggregates by analysis.

## Harness contract (summary)

| Requirement | Detail |
|-------------|--------|
| Output | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` (`csv_schema` in master config) |
| `Language` column | Language id (e.g. `csharp`, `python`) |
| Time unit | **Nanoseconds** for new harnesses (legacy C# may use ticks; analysis normalizes) |
| Modes | `bytes` / `stream` (C# may use `string` / `stream`) |
| Timed section | Serialize + deserialize only |
| Fidelity | Round-trip check; failures → `logs/<lang>/<ts>.errors.csv` (per run) |
| Seed | From `schemas/test_data_config.json` / config |

Full checklist: [Adding a Language](ADDING_A_LANGUAGE.md).

## Analysis pipeline (summary)

CSV → drop warmup → optional IQR filter → mean/median/std/MAD/CV/percentiles → bootstrap CI on mean → within-group effect sizes vs fastest → optional A/B tests. Defaults: `config/benchmark_config.yaml` and [Analysis Methodology](ANALYSIS_METHODOLOGY.md).

## Configuration

- **Run modes / stats / languages / paths:** `config/benchmark_config.yaml`
- **Payload shape / seed:** `schemas/test_data_config.json` — see [Test Data Configuration](test_data_configuration.md)
