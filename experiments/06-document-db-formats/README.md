# Experiment 6 — Are database formats better for a normal service call?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 6). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Do BSON, Smile, and Ion win a full write-and-read against JSON and MessagePack — or do they **lose**, because they spend bytes on the ability to skip fields?

This benchmark always writes and reads the **whole** sample. The product win of BSON (skip a large field on disk) is only partly visible.

## Who we compare

Java is the natural home (Smile and Ion live there). BSON is also run in JavaScript, Go, Rust, and C.

**Not in this run**
- **Python:** the suite has no BSON library. Add a `bson` / `pymongo` client to the Python harness to fix that.
- **C#:** no BSON row is registered. Add a BSON writer (for example MongoDB.Bson) to fix that.
- **Swift:** `SwiftBSON` exists in the suite but was not on the plan’s BSON list. Add it here if you want Apple-side Mongo bytes.

## The sample (shared)

Sample A: one order-like record. Settings: `experiment.yaml`. Exact values: [`sample.json`](sample.json).

## How to run

```bash
./experiments/06-document-db-formats/run.sh
./experiments/06-document-db-formats/run.sh java
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not pick BSON for an ordinary service call if it is larger or slower than MessagePack on a full write-and-read.
