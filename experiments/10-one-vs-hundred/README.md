# Experiment 10 — Does one record rank the same as one hundred?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 10). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Does the library that wins at **one** record still win at **one hundred** records in a single write?

Same comparison as Experiment 2 (JSON, MessagePack, Protocol Buffers), on Sample B and Sample D.

C# has no MessagePack. C/C++ protobuf rows are the suite wire path, not official Google packs.

## How to run

```bash
./experiments/10-one-vs-hundred/run.sh
```

Quick look: [`results.md`](results.md).
