# Does writing to a file change the ranking?

**Question:** When we write as if to a file, which libraries really write as they go, and does the ranking change?
**Date:** 2026-09-04
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. A faster one-language library is not proof that the store is safe.

## At a glance

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| go | ok | `goccy/go-json`, `protobuf` | — | `goccy/go-json`, `protobuf` | [go/results.md](go/results.md) |
| java | ok | `jsoniter` | — | `jsoniter`, `protobuf` | [java/results.md](java/results.md) |
| kotlin | ok | `moshi-codegen` | — | `moshi-codegen`, `protobuf` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` | [php/results.md](php/results.md) |
| cpp | ok | `protobuf-wire` | — | `protobuf-wire` | [cpp/results.md](cpp/results.md) |
| zig | ok | `flatbuffers` | `protobuf` | `flatbuffers`, `protobuf` | [zig/results.md](zig/results.md) |

## In memory, by language

Every listed library (one-language, and libraries other languages can read). Times are middle values in microseconds. Lower is better **inside that language**.

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| goccy/go-json | 4.11 | 448 | JSON | fastest |
| protobuf | 4.13 | 155 | Protocol Buffers | similar |
| vmihailenco/msgpack | 6.71 | 397 | MessagePack | slower |
| encoding/json | 11.2 | 448 | JSON — stdlib | slower |

### java

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| jsoniter | 45.0 | 440 | JSON | fastest |
| protobuf | 61.2 | 155 | Protocol Buffers | slower |
| jackson | 105 | 440 | JSON — common default | slower |
| msgpack | 128 | 317 | MessagePack | slower |

### kotlin

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| moshi-codegen | 48.2 | 440 | JSON | fastest |
| protobuf | 62.3 | 155 | Protocol Buffers | slower |
| jackson | 144 | 440 | JSON — common default | slower |
| msgpack | 170 | 317 | MessagePack | slower |

### php

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 6.04 | 454 | JSON | fastest |
| rybakit-msgpack | 22.5 | 335 | MessagePack | slower |
| protobuf | 201 | 160 | Protocol Buffers | slower |

### cpp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 8.22 | 164 | Protocol Buffers — wire helper | fastest |
| msgpack | 9.84 | 332 | MessagePack | slower |
| simdjson | 24.7 | 458 | JSON — fast read | slower |
| nlohmann_json | 28.1 | 458 | JSON | slower |

### zig

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| flatbuffers | 1.09 | 468 | FlatBuffers | fastest |
| protobuf | 1.12 | 155 | Protocol Buffers | close |
| serde.msgpack | 1.76 | 325 | MessagePack | slower |
| std.json | 3.69 | 448 | JSON | slower |
| std.json.scanner | 3.71 | 448 | JSON — streaming parser | slower |
| capnproto | 7.87 | 376 | Cap’n Proto | slower |

## What we saw

On this tiny flat record, the one-language libraries are **slower**, not faster, than a library another language can read.

- **Python:** `orjson` is fastest (about 1.70 µs). `msgspec-msgpack` is close and smaller. `pickle` is about four times slower and larger. `cloudpickle` and `dill` are slower still.
- **Java:** `protobuf` is fastest. `kryo` is smaller but slower. `java-serialization` is about four and a half times slower than `protobuf`.
- **Go:** `protobuf` is fastest. `encoding/gob` is about thirteen times slower.

This sample has only ordinary fields. It does not contain a class, a function, or another value that JSON cannot hold. That is the case people mean by “just pickle the cache.”

## What this page is not

- It is not a ranking of languages.
- It is not a promise that the same names stay on top if you change the record.
- It is not a safety test. This program does not attack the reader.
- A small time gap on this tiny record is not a reason to put one-language bytes in a store another program might open.

