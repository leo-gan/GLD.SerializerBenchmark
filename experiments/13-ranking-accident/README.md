# Experiment 13 — Does the ranking stay the same if we change the data?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 13). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

One run on one computer is a single evening’s measurement. This experiment asks whether Experiment 1’s named-JSON ranks **stay put** when we change the sample, the number of records in one write, or the rule for setting aside stalls.

## What we change

| Change | What a flip would mean |
|--------|------------------------|
| Sample A, B, C, D, E | The winner depends on the data. Never quote a rank without naming the sample. |
| 1 record vs 100 | You were measuring the cost of calling the library, not the cost of writing the data. |
| Cleaning rule (keep every trial after warm-up; IQR 1.5; IQR 3.0; keep the first trial) | Close contests are fragile. Distant contests are not. |

We do **not** re-time shuffled vs fixed order, three separate evenings, or two versions of the same library. Those need a different runner schedule or a pinned old package. See the plan.

Stream ranking is Experiment 11. This run is in memory only.

## The samples (shared)

All five catalog kinds, seed 42, **1** and **100** records per write. Settings are in `experiment.yaml`. Exact values: [`sample.json`](sample.json).

Named JSON only (`require_named_fields: true`). `msgspec` is listed but writes a list of values; it is not in the comparison set.

## How to run

```bash
./experiments/13-ranking-accident/run.sh
./experiments/13-ranking-accident/run.sh python go
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner.
