# Architecture

## Goals

1. **Researchers** — reproducible, statistically defensible comparisons (CIs, effect sizes, non-parametric tests).
2. **Serializer authors** — A/B compare versions of the *same* serializer (`--compare-a` / `--compare-b`).
3. **System integrators** — swap payloads and environments; keep the same metrics pipeline.
4. **Extensibility** — add languages without rewriting analysis.

## Layout

```
config/benchmark_config.yaml   # master parameters
schemas/                       # shared test data config + protos
logs/<language>/               # per-language CSV outputs
analysis/                      # scientific stats + reports
python/ | c-sharp/ | rust/ | c/ | javascript/   # language harnesses
docs/                          # theory + per-language serializer docs
scripts/run-all-benchmarks.sh  # orchestrator
```

## Measurement model

```
prepare(type)          # untimed: codecs, schemas, buffers
prepare_data(fixture)  # untimed: convert to serializer-native model
for i in 0..N-1:
    t0 = now()
    bytes = serialize(obj)
    t1 = now()
    obj2 = deserialize(bytes)
    t2 = now()
    assert fidelity(fixture, obj2)
    log(ser=t1-t0, deser=t2-t1, size=len(bytes), i)
```

Repetition `i=0` is warmup (excluded from aggregates).

## Statistics pipeline

1. Parse CSV (normalize ticks → ns for C#)
2. Drop warmup
3. IQR outlier filter (configurable)
4. Mean/median/std/MAD/CV/percentiles
5. Bootstrap CI on mean (default 95%, 2000 resamples)
6. Within-group effect sizes vs fastest (Cliff's δ, Hedges' g)
7. Optional Mann–Whitney + Holm for version A/B

See [Analysis Methodology](../analysis/ANALYSIS_METHODOLOGY.md).

## Configuration

Most constants live in `config/benchmark_config.yaml`. Test-data shape lives in `schemas/test_data_config.json` (shared with existing generators).

## Adding languages

See [Adding a Language](ADDING_A_LANGUAGE.md).
