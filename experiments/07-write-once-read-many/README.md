# Experiment 7 — Write once, read many times

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 7). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Look at **write time and read time separately**. Do not add them. The whole point is that writing and reading are different jobs.

Python FlatBuffers write uses a slow Python builder. Do not reject the *format* from that row. Repeat in C++. The timed `rkyv` read builds a full value so we can check information — that is not the product win.

## Who we compare

| Language | Libraries |
|----------|-----------|
| C++ | `flatbuffers`, `capnproto`, `flexbuffers`, `protobuf-wire` |
| C# | `FlatSharp`, `ZeroFormatter`, `MemoryPack`, `ProtoBuf` |
| JavaScript | `flatbuffers`, `flexbuffers` |
| Python | `flatbuffers`, `protobuf` |
| Rust | `rkyv`, `prost` |

Official Google `libprotobuf` did not register in C++ on this machine. The C++ protobuf row is the in-tree wire helper.

**Not in this run:** Java (no FlatBuffers / Cap’n Proto client in the suite). C `flatcc` and Swift `FlatBuffers` / `CapnProto` exist but were not on the plan list. Add them to `experiment.yaml` to cover those languages.

## The samples (shared)

Sample A (one order) and Sample C with **512** numbers. Settings: `experiment.yaml`. Exact values: [`sample.json`](sample.json).

## How to run

```bash
./experiments/07-write-once-read-many/run.sh
./experiments/07-write-once-read-many/run.sh cpp
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json).
