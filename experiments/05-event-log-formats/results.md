# An event log: size and write time only

**Question:** On one event, how do Avro, Protocol Buffers, and JSON compare on size and write time?
**Date:** 2026-08-17
**Sample:** `event`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one event. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. Groups for 1 record and for 100 records are separate. Speed cannot override a failed compatibility story.

## At a glance (1 record per write)

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| python | ok | `orjson` | — | `orjson`, `protobuf`, `avro` | [python/results.md](python/results.md) |
| java | ok | `protobuf` | — | `protobuf`, `avro` | [java/results.md](java/results.md) |
| go | ok | `hamba/avro` | — | `hamba/avro`, `linkedin/goavro` | [go/results.md](go/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | ok | `protobuf` | — | `protobuf`, `avro` |
| java | ok | `protobuf` | — | `protobuf`, `avro` |
| go | ok | `hamba/avro` | — | `hamba/avro`, `linkedin/goavro` |

## In memory, by language

Every listed library (JSON, Avro, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**.

### python

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| orjson | 2.78 | 257 | JSON — fast writer from Experiment 1 | fastest |
| protobuf | 4.32 | 123 | Protocol Buffers | slower |
| avro | 19.3 | 105 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 63.1 | 12477 | Protocol Buffers | fastest |
| orjson | 118 | 25746 | JSON — fast writer from Experiment 1 | slower |
| avro | 825 | 10445 | Avro | slower |

### java

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 48.5 | 123 | Protocol Buffers | fastest |
| avro | 74.8 | 105 | Avro | slower |
| jackson | 77.6 | 254 | JSON — common default | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 129 | 12477 | Protocol Buffers | fastest |
| jackson | 219 | 25446 | JSON — common default | slower |
| avro | 223 | 10448 | Avro | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| hamba/avro | 2.08 | 107 | Avro — binds to structs | fastest |
| linkedin/goavro | 3.28 | 105 | Avro — maps | slower |
| protobuf | 3.30 | 123 | Protocol Buffers | slower |
| sonic | 3.31 | 257 | JSON — fast writer | slower |
| encoding/json | 7.14 | 257 | JSON — ships with Go | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| hamba/avro | 55.4 | 10626 | Avro — binds to structs | fastest |
| sonic | 86.0 | 25746 | JSON — fast writer | slower |
| protobuf | 108 | 12477 | Protocol Buffers | slower |
| linkedin/goavro | 145 | 10448 | Avro — maps | slower |
| encoding/json | 328 | 25746 | JSON — ships with Go | slower |

## What we saw

Avro and Protocol Buffers write about half the bytes of JSON (about 105 and 123 versus 257 on one event). Times are not one contest.

- **Python:** `orjson` is fastest at one record (about 2.78 µs, 257 bytes). Protocol Buffers is smaller and next (4.32 µs, 123 bytes). Avro is smallest (105 bytes) and much slower (19 µs write+read; write about 12 µs). At 100 records, Protocol Buffers is fastest; Avro is far slower.
- **Java:** `protobuf` is fastest at 1 and 100. Avro is smaller (105 vs 123) and slower. Jackson JSON is larger (254 bytes).
- **Go:** `hamba/avro` is fastest at 1 and 100 (about 2.08 µs, 107 bytes). `linkedin/goavro` writes the same small file and is slower, especially at 100. If you already chose Avro, pick the faster library inside Avro.

Use the size cut in the disk budget. Still pick Avro vs Protocol Buffers on process grounds (who may add a field, and when).

## What this page is not

- It is not a ranking of languages.
- It is not a compatibility test (an old reader vs a new field).
- It is not an analytics store. Column files such as Parquet are a different job.
- Speed cannot override a failed compatibility story.

