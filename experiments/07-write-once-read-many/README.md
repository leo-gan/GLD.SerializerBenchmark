# Experiment 7 — Fast to write, or fast to read?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 7). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

Look at **write time and read time separately**. Do not add them. The whole point is that writing and reading are different jobs.

Python FlatBuffers write uses a slow Python builder. Do not reject the *format* from that row. Repeat in C++. The timed `rkyv` read builds a full value so we can check information — that is not the product win.

## Who we compare

| Language | Libraries |
|----------|-----------|
| C++ | `flatbuffers`, `capnproto`, `flexbuffers`, `protobuf-wire`, official `protobuf` |
| Java | `flatbuffers`, `capnproto`, `protobuf` |
| C# | `FlatSharp`, `ZeroFormatter`, `MemoryPack`, `ProtoBuf` |
| JavaScript | `flatbuffers`, `flexbuffers` |
| Python | `flatbuffers`, `protobuf` |
| Rust | `rkyv`, `prost` |
| C | `flatcc`, `protobuf-wire` |
| Swift | `FlatBuffers`, `CapnProto` |

Official Google `libprotobuf` 3.12.4 now registers in C++ after `cpp/scripts/setup-protobuf-sysroot.sh`.

Java now has official `flatbuffers` and `capnproto` rows.

**Not in this run:** Java still has no FlexBuffers client.

## The samples (shared)

Sample A (one order) and Sample C with **512** numbers. Settings: `experiment.yaml`. Exact values: [`sample.json`](sample.json).

## How to run

```bash
./experiments/07-write-once-read-many/run.sh
./experiments/07-write-once-read-many/run.sh cpp
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json).
