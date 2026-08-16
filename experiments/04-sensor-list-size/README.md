# Experiment 4 — When is JSON too large for a sensor list?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 4). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

A device sends a list of numbers. A small radio packet has a size limit. JSON is easy to read. When does the list get so long that JSON no longer fits?

This is a **curve**: 8, 32, 128, then 512 numbers in one record (Sample C). We look at **size first**, then write time.

We mark two example packet sizes on the curve: **128 bytes** and **512 bytes**. Your radio may differ. This program does not measure flash size of the library or battery use.

C and Rust are the device-side languages in this suite. Python is not in this run (cloud side, not the device). C `nanopb` and `protobuf-wire` are not a full generated Google pack — read the roles in the table.

## The sample (shared)

Settings and seed are in `experiment.yaml`. Exact values: [`sample.json`](sample.json).

## How to run

```bash
./experiments/04-sensor-list-size/run.sh
./experiments/04-sensor-list-size/run.sh rust
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner; read the similar / close sets at each list length.
