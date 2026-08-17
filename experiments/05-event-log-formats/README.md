# Experiment 5 — An event log: size and write time only

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 5). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

A fact such as “order placed” on a durable log. We compare **Avro**, **Protocol Buffers**, and **JSON** on size and write time — enough to plan disks and producer CPU. Speed cannot override a failed compatibility story.

## Who we compare

| Language | Avro | Protocol Buffers | JSON |
|----------|------|------------------|------|
| Java | `avro` | `protobuf` | `jackson` |
| Go | `hamba/avro`, `linkedin/goavro` | `protobuf` | `sonic`, `encoding/json` |
| Python | `avro` | `protobuf` | `orjson` |

Other languages are not in this run. The plan named these three because that is where Avro and a JSON event path both live in the suite.

## The sample (shared)

Sample D: one event (who produced it, when, what kind, four attributes). We write **1** and **100** records per call. Settings: `experiment.yaml`. Exact values: [`sample.json`](sample.json).

## How to run

```bash
./experiments/05-event-log-formats/run.sh
./experiments/05-event-log-formats/run.sh python
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner. Pick Avro vs Protocol Buffers on process grounds first, then use these numbers for the disk and CPU budget.
