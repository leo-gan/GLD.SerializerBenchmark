# What should we use for an event log?

**Question:** On one “something happened” record, how do Avro, Protocol Buffers, and JSON compare on size and write time?
**Date:** 2026-10-11
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
| kotlin | ok | `protobuf` | — | `protobuf`, `avro` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `avro` | [php/results.md](php/results.md) |
| go | ok | `hamba/avro` | — | `hamba/avro`, `linkedin/goavro` | [go/results.md](go/results.md) |
| csharp | ok | `SpanJson` | — | `SpanJson`, `Google.Protobuf`, `Apache.Avro` | [csharp/results.md](csharp/results.md) |
| rust | ok | `prost` | — | `prost`, `serde_avro_fast` | [rust/results.md](rust/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `avsc` | [javascript/results.md](javascript/results.md) |
| c | ok | `protobuf-wire` | — | `protobuf-wire` | [c/results.md](c/results.md) |
| cpp | ok | `avro` | — | `avro` | [cpp/results.md](cpp/results.md) |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf`, `SwiftAvroCore` | [swift/results.md](swift/results.md) |
| zig | ok | `serde.msgpack` | `flatbuffers` | `serde.msgpack`, `protobuf` | [zig/results.md](zig/results.md) |
| mojo | ok | `mojo-avro`, `mojo-protobuf` | `mojo-json` | `mojo-avro` | [mojo/results.md](mojo/results.md) |
| fortran | ok | `custom-binary` | — | `custom-binary` | [fortran/results.md](fortran/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | ok | `protobuf` | — | `protobuf`, `avro` |
| java | ok | `protobuf` | — | `protobuf`, `avro` |
| kotlin | ok | `protobuf` | `avro4k` | `protobuf`, `avro4k` |
| php | ok | `json` | — | `json`, `avro` |
| go | ok | `hamba/avro` | — | `hamba/avro`, `linkedin/goavro` |
| csharp | ok | `SpanJson` | — | `SpanJson`, `Google.Protobuf`, `Apache.Avro` |
| rust | ok | `prost` | — | `prost`, `serde_avro_fast` |
| javascript | ok | `avsc` | — | `avsc` |
| c | ok | `protobuf-wire` | — | `protobuf-wire` |
| cpp | ok | `avro` | — | `avro` |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf`, `SwiftAvroCore` |
| zig | ok | `flatbuffers` | — | `flatbuffers`, `serde.msgpack`, `protobuf` |
| mojo | ok | `mojo-json` | — | `mojo-json`, `mojo-protobuf`, `mojo-avro` |
| fortran | ok | `custom-binary` | — | `custom-binary` |

## In memory, by language

Every listed library (JSON, Avro, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**.

### python

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| orjson | 4.47 | 257 | JSON — fast writer from Experiment 1 | fastest |
| protobuf | 6.23 | 123 | Protocol Buffers | slower |
| avro | 24.6 | 105 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 70.5 | 12477 | Protocol Buffers | fastest |
| orjson | 128 | 25746 | JSON — fast writer from Experiment 1 | slower |
| avro | 876 | 10445 | Avro | slower |

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

### kotlin

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 64.1 | 123 | Protocol Buffers | fastest |
| avro | 157 | 105 | Avro | slower |
| avro4k | 170 | 105 | Avro — avro4k | slower |
| jackson | 195 | 254 | JSON — common default | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 191 | 12477 | Protocol Buffers | fastest |
| avro4k | 204 | 10448 | Avro — avro4k | close |
| avro | 224 | 10448 | Avro | slower |
| jackson | 310 | 25446 | JSON — common default | slower |

### php

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 3.88 | 267 | JSON — stdlib | fastest |
| avro | 48.2 | 115 | Avro | slower |
| protobuf | 106 | 133 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 213 | 25976 | JSON — stdlib | fastest |
| avro | 3624 | 10678 | Avro | slower |
| protobuf | 9090 | 12717 | Protocol Buffers | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| hamba/avro | 1.91 | 107 | Avro — binds to structs | fastest |
| protobuf | 2.52 | 123 | Protocol Buffers | slower |
| linkedin/goavro | 2.59 | 105 | Avro — maps | slower |
| sonic | 2.81 | 257 | JSON — fast writer | slower |
| encoding/json | 6.28 | 257 | JSON — ships with Go | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| hamba/avro | 62.8 | 10626 | Avro — binds to structs | fastest |
| sonic | 99.4 | 25746 | JSON — fast writer | slower |
| protobuf | 125 | 12477 | Protocol Buffers | slower |
| linkedin/goavro | 170 | 10448 | Avro — maps | slower |
| encoding/json | 356 | 25746 | JSON — ships with Go | slower |

### csharp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 13.5 | 254 | JSON — Experiment 1 | fastest |
| Google.Protobuf | 18.0 | 164 | Protocol Buffers | slower |
| Apache.Avro | 40.5 | 140 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 116 | 25456 | JSON — Experiment 1 | fastest |
| Google.Protobuf | 161 | 16636 | Protocol Buffers | slower |
| Apache.Avro | 577 | 13932 | Avro | slower |

### rust

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 1.07 | 114 | Protocol Buffers | fastest |
| sonic-rs | 1.60 | 258 | JSON — Experiment 1 | slower |
| serde_avro_fast | 1.67 | 96 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 81.9 | 12578 | Protocol Buffers | fastest |
| sonic-rs | 89.6 | 26978 | JSON — Experiment 1 | slower |
| serde_avro_fast | 98.2 | 10778 | Avro | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 7.61 | 257 | JSON | fastest |
| avsc | 12.4 | 105 | Avro | slower |
| protobufjs | 22.0 | 123 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| avsc | 174 | 10448 | Avro | fastest |
| protobufjs | 259 | 12477 | Protocol Buffers | slower |
| JSON.stringify | 262 | 25746 | JSON | slower |

### c

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 0.86 | 131 | Protocol Buffers — wire helper | fastest |
| avro-c | 1.53 | 132 | Avro | slower |
| yyjson | 3.58 | 265 | JSON — Experiment 1 | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 67.3 | 12525 | Protocol Buffers — wire helper | fastest |
| avro-c | 79.6 | 12625 | Avro | slower |
| yyjson | 229 | 25925 | JSON — Experiment 1 | slower |

### cpp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| avro | 2.89 | 120 | Avro | fastest |
| protobuf-wire | 4.22 | 138 | Protocol Buffers — wire helper | slower |
| avro_c | 12.1 | 120 | Avro — C library from C++ | slower |
| nlohmann_json | 14.5 | 272 | JSON | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| avro | 72.9 | 10165 | Avro | fastest |
| protobuf-wire | 171 | 12183 | Protocol Buffers — wire helper | slower |
| avro_c | 365 | 10165 | Avro — C library from C++ | slower |
| nlohmann_json | 631 | 25463 | JSON | slower |

### swift

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 8.67 | 123 | Protocol Buffers | fastest |
| IkigaJSON | 28.5 | 257 | JSON — Experiment 1 | slower |
| SwiftAvroCore | 78.9 | 105 | Avro | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 243 | 12477 | Protocol Buffers | fastest |
| IkigaJSON | 1503 | 25746 | JSON — Experiment 1 | slower |
| SwiftAvroCore | 4846 | 10448 | Avro | slower |

### zig

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| serde.msgpack | 0.69 | 199 | MessagePack | fastest |
| flatbuffers | 0.72 | 296 | FlatBuffers | close |
| protobuf | 0.76 | 123 | Protocol Buffers | slower |
| serde.json | 1.30 | 257 | JSON — serde.zig | slower |
| std.json | 1.65 | 257 | JSON — stdlib | slower |
| capnproto | 8.94 | 256 | Cap’n Proto | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| flatbuffers | 38.2 | 31124 | FlatBuffers | fastest |
| serde.msgpack | 41.1 | 20249 | MessagePack | slower |
| protobuf | 50.4 | 12649 | Protocol Buffers | slower |
| serde.json | 119 | 26049 | JSON — serde.zig | slower |
| std.json | 143 | 26049 | JSON — stdlib | slower |
| capnproto | 636 | 26820 | Cap’n Proto | slower |

### mojo

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mojo-avro | 2.91 | 105 | Avro | fastest |
| mojo-protobuf | 3.03 | 123 | Protocol Buffers | similar |
| mojo-json | 3.32 | 257 | JSON — mojo-json | close |
| mojo-cbor | 4.19 | 199 | CBOR | slower |
| mojo-flatbuffers | 5.00 | 272 | FlatBuffers | slower |
| EmberJson | 6.90 | 257 | JSON — EmberJson | slower |
| ehsanmok-json | 8.01 | 257 | JSON — ehsanmok/json | slower |
| mojo-toml | 45.7 | 271 | TOML | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mojo-json | 101 | 25756 | JSON — mojo-json | fastest |
| mojo-protobuf | 112 | 12477 | Protocol Buffers | slower |
| mojo-avro | 148 | 10448 | Avro | slower |
| EmberJson | 177 | 25756 | JSON — EmberJson | slower |
| mojo-flatbuffers | 193 | 25968 | FlatBuffers | slower |
| mojo-cbor | 207 | 19854 | CBOR | slower |
| ehsanmok-json | 313 | 25756 | JSON — ehsanmok/json | slower |
| mojo-toml | 4736 | 27954 | TOML | slower |

### fortran

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| custom-binary | 1.29 | 113 | length-prefixed binary | fastest |
| json-fortran | 27.8 | 258 | JSON — json-fortran | slower |
| fortran-messagepack | 47.7 | 197 | MessagePack | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| custom-binary | 99.4 | 12029 | length-prefixed binary | fastest |
| json-fortran | 1728 | 26647 | JSON — json-fortran | slower |
| fortran-messagepack | 3311 | 20443 | MessagePack | slower |

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

