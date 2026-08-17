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
| csharp | ok | `SpanJson` | — | `SpanJson`, `Google.Protobuf`, `Apache.Avro` | [csharp/results.md](csharp/results.md) |
| rust | ok | `serde_avro_fast`, `sonic-rs` | — | `serde_avro_fast` | [rust/results.md](rust/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `avsc` | [javascript/results.md](javascript/results.md) |
| c | ok | `protobuf-wire` | — | `protobuf-wire` | [c/results.md](c/results.md) |
| cpp | ok | `avro` | — | `avro` | [cpp/results.md](cpp/results.md) |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf`, `SwiftAvroCore` | [swift/results.md](swift/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | ok | `protobuf` | — | `protobuf`, `avro` |
| java | ok | `protobuf` | — | `protobuf`, `avro` |
| go | ok | `hamba/avro` | — | `hamba/avro`, `linkedin/goavro` |
| csharp | ok | `SpanJson` | — | `SpanJson`, `Google.Protobuf`, `Apache.Avro` |
| rust | ok | `sonic-rs` | — | `sonic-rs`, `serde_avro_fast` |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `protobufjs`, `avsc` |
| c | ok | `protobuf-wire` | — | `protobuf-wire` |
| cpp | ok | `avro` | — | `avro` |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf`, `SwiftAvroCore` |

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

### csharp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 12.1 | 254 | JSON — Experiment 1 | fastest |
| Google.Protobuf | 16.9 | 164 | Protocol Buffers | slower |
| Apache.Avro | 37.3 | 140 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 113 | 25456 | JSON — Experiment 1 | fastest |
| Google.Protobuf | 167 | 16636 | Protocol Buffers | slower |
| Apache.Avro | 577 | 13932 | Avro | slower |

### rust

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| serde_avro_fast | 0.83 | 96 | Avro | fastest |
| sonic-rs | 0.83 | 258 | JSON — Experiment 1 | similar |
| prost | 0.87 | 114 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| sonic-rs | 95.2 | 26978 | JSON — Experiment 1 | fastest |
| serde_avro_fast | 105 | 10778 | Avro | slower |
| prost | 112 | 12578 | Protocol Buffers | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 5.89 | 257 | JSON | fastest |
| avsc | 19.3 | 105 | Avro | slower |
| protobufjs | 29.7 | 123 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 225 | 25746 | JSON | fastest |
| protobufjs | 336 | 12477 | Protocol Buffers | slower |
| avsc | 608 | 10448 | Avro | slower |

### c

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 0.62 | 131 | Protocol Buffers — wire helper | fastest |
| avro-c | 1.12 | 132 | Avro | slower |
| yyjson | 2.36 | 265 | JSON — Experiment 1 | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 64.2 | 12525 | Protocol Buffers — wire helper | fastest |
| avro-c | 75.3 | 12625 | Avro | slower |
| yyjson | 223 | 25925 | JSON — Experiment 1 | slower |

### cpp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| avro | 0.92 | 120 | Avro | fastest |
| protobuf-wire | 1.43 | 138 | Protocol Buffers — wire helper | slower |
| avro_c | 3.74 | 120 | Avro — C library from C++ | slower |
| nlohmann_json | 5.64 | 272 | JSON | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| avro | 44.7 | 10165 | Avro | fastest |
| protobuf-wire | 112 | 12183 | Protocol Buffers — wire helper | slower |
| avro_c | 227 | 10165 | Avro — C library from C++ | slower |
| nlohmann_json | 386 | 25463 | JSON | slower |

### swift

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 6.88 | 123 | Protocol Buffers | fastest |
| IkigaJSON | 29.0 | 257 | JSON — Experiment 1 | slower |
| SwiftAvroCore | 77.7 | 105 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 231 | 12477 | Protocol Buffers | fastest |
| IkigaJSON | 1644 | 25746 | JSON — Experiment 1 | slower |
| SwiftAvroCore | 5368 | 10448 | Avro | slower |

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

