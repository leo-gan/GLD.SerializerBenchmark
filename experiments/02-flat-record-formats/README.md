# Experiment 2 — Should two services inside the company stop using JSON?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 2). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Two services you control exchange a small, stable record. There are no browsers on this path. You *may* leave JSON. Is the gap large enough to pay for a new shared field description?

## The sample (shared)

Sample B: one flat record (eight fields, no nesting). Settings and seed are in `experiment.yaml`. Exact values: [`sample.json`](sample.json).

We measure **1** record per write and **100** records per write. Groups for those two cases are separate.

Ordinary named JSON on the JSON side (`orjson` / the Experiment 1 fast named library, plus the language’s built-in JSON). Not `msgspec` JSON (that writes a list). C# has no MessagePack row in this suite; that language compares JSON to Protocol Buffers only.

C and C++ need a careful reading. C `protobuf-c` reports a real library version, but the timed path is the suite wire codec, not a generated Google pack. C `protobuf-wire` and C++ `protobuf-wire` are in-tree helpers. Official Google `libprotobuf` did not run in C or C++ on this machine.

## How to run

```bash
./experiments/02-flat-record-formats/run.sh
./experiments/02-flat-record-formats/run.sh python go
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner; read the similar / close sets for each language and each N.
