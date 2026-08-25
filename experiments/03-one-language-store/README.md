# Experiment 3 — Is a one-language format worth the lock-in?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 3). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

A cache, a job body, or a store that “only we write today.” A one-language library can be faster. Another program may open those bytes later. Is the gain large enough to accept that?

## The sample (shared)

Sample B: one flat record (eight fields, no nesting). Settings and seed are in `experiment.yaml`. Exact values: [`sample.json`](sample.json).

This file can hold only one sample kind. Sample A (the nested order from Experiment 1) is **not** in this run. The same question on Sample A would need its own settings file.

Python: `pickle`, `cloudpickle`, and `dill` against `orjson`, `msgspec-msgpack`, and `protobuf` (what Experiments 1 and 2 left standing). Java and Go ask the same question with their one-language libraries.

## How to run

```bash
./experiments/03-one-language-store/run.sh
./experiments/03-one-language-store/run.sh python
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner; read the similar / close sets for each language. A faster one-language library is not proof that the store is safe.
