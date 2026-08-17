# Experiment 12 — Is the difference the format, or the library?

The full argument is in [../PLAN.md](../PLAN.md) (Experiment 12). Edit **[`experiment.yaml`](experiment.yaml)** to change this experiment.

People say “we use JSON” or “we switched to binary” as if the name were the whole decision. This run holds **one library still** and only changes what it writes. A second check keeps the **format** still and changes the library.

## Who we compare

| Language | Hold the library still | Same format, different library |
|----------|------------------------|--------------------------------|
| Java | Jackson: JSON, CBOR, Smile, Ion, MessagePack | `gson`, `jsoniter` (JSON) |
| C++ | nlohmann: JSON, CBOR, BSON, MessagePack, UBJSON | — (this language only holds nlohmann still) |
| Go | ugorji: JSON, MessagePack, CBOR | `encoding/json`, `goccy/go-json`; `vmihailenco/msgpack`, `shamaton/msgpack` |
| C# | Bond Compact vs Bond Fast | `Google.Protobuf`, `ProtoBuf` (same format, two writers) |
| JavaScript | — | `protobuf-es`, `protobufjs`, `google-protobuf` |

Python, Rust, C, and Swift are not in this run. They do not have this “one library, several formats” case in the plan.

The result is about **that one library**, not about every MessagePack writer in the world.

## The sample (shared)

Sample A: one order-like record (an id, a status, a region, a version, and eight line items). Settings and seed are in `experiment.yaml`. Exact values: [`sample.json`](sample.json).

We write **one** record per call.

## How to run

```bash
./experiments/12-format-vs-library/run.sh
./experiments/12-format-vs-library/run.sh java go
```

Quick look: [`results.md`](results.md). Dashboard file: [`results.json`](results.json). Run logs stay local and are not in git.

Times in two languages are not one contest. Do not name a single winner; read the similar / close sets for each language. “Move to binary” without picking a library is not a plan.
