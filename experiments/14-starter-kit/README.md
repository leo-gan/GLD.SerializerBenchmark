# Experiment 14 — What is a starter kit of serializers for typical jobs?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 14). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

A team often needs to start today, not after ranking every library. This experiment times a short list that covers three usual jobs:

| Job | What we put in the kit |
|-----|------------------------|
| Public JSON | The language’s built-in or common JSON library, and the fastest named JSON from Experiment 1 when that is a different name |
| Compact bytes inside the company | One MessagePack library (no shared field file) |
| Shared field file | One Protocol Buffers library |

This is a place to begin. It is not a prize. We do not name one winner. Later experiments are how you optimize.

## The sample (shared)

Sample A: one shop order (an id, a status, eight line items). Settings and seed are in `experiment.yaml`. Exact values: [`sample.json`](sample.json).

We write **one** record per call. Mixed formats sit in one list (`require_named_fields: false`). Groups compare every listed library. Read the **role** on each row: that is the job, not a ranking.

C and C++ need a careful reading. C `protobuf-c` reports a real library version, but the timed path is the suite wire codec, not a generated Google pack. C++ `protobuf-wire` is an in-tree helper. Official Google `libprotobuf` did not run in C or C++ on this machine in Experiment 2.

## How to run

```bash
./experiments/14-starter-kit/run.sh
./experiments/14-starter-kit/run.sh python go
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner; read the similar / close sets for each language, then pick the row that matches the job you have.
