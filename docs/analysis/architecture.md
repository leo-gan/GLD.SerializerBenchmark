# Benchmark architecture

How this **benchmark suite** is laid out and how measurements flow. Goals, repo layout, harness timing model, and where config/analysis live. For statistics detail see [Analysis Methodology](ANALYSIS_METHODOLOGY.md). To extend the suite see [Adding a Language](ADDING_A_LANGUAGE.md).

## Goals

| Audience | Need |
|----------|------|
| Researchers | Reproducible comparisons (CIs, effect sizes, non-parametrics) |
| Serializer authors | A/B compare versions (`analyze-benchmarks --compare-a` / `--compare-b`) |
| Integrators | Swap payloads/environments; same metrics pipeline |
| Maintainers | Add languages without rewriting analysis |

## Repository layout

```text
config/benchmark_config.yaml   # modes, stats defaults, language registry, CSV schema
schemas/                       # test_data_config.json, protos
logs/<language>/               # benchmark-log.csv (gitignored; harness output)
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
| Output | `logs/<lang>/benchmark-log.csv` (`csv_schema` in master config) |
| `Language` column | Language id (e.g. `csharp`, `python`) |
| Time unit | **Nanoseconds** for new harnesses (legacy C# may use ticks; analysis normalizes) |
| Modes | `bytes` / `stream` (C# may use `string` / `stream`) |
| Timed section | Serialize + deserialize only |
| Fidelity | Round-trip check; failures → `benchmark-errors.csv` |
| Seed | From `schemas/test_data_config.json` / config |

Full checklist: [Adding a Language](ADDING_A_LANGUAGE.md).

## Analysis pipeline (summary)

CSV → drop warmup → optional IQR filter → mean/median/std/MAD/CV/percentiles → bootstrap CI on mean → within-group effect sizes vs fastest → optional A/B tests. Defaults: `config/benchmark_config.yaml` and [Analysis Methodology](ANALYSIS_METHODOLOGY.md).

## Configuration

- **Run modes / stats / languages / paths:** `config/benchmark_config.yaml`
- **Payload shape / seed:** `schemas/test_data_config.json` — see [Test Data Configuration](test_data_configuration.md)
