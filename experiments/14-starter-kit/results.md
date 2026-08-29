# What is a starter kit of serializers for typical jobs?

**Question:** If we do not want to rank every library first, which few serializers cover the usual jobs — public JSON, compact bytes inside the company, and a shared field file — on one shop order?
**Date:** 2026-08-29
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small order. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest library in this starter kit on this sample. **Close** means a small gap. Read the **role** on each row: that is the job, not a ranking.

## At a glance

| Language | Status | Not clearly slower | Small gap | Not both slower and larger | Full table |
|----------|--------|--------------------|-----------|----------------------------|------------|
| python | ok | `msgspec-msgpack`, `orjson` | — | `msgspec-msgpack` | [python/results.md](python/results.md) |
| go | ok | `goccy/go-json`, `protobuf` | — | `goccy/go-json`, `protobuf` | [go/results.md](go/results.md) |
| java | ok | `jsoniter` | — | `jsoniter`, `protobuf` | [java/results.md](java/results.md) |
| kotlin | ok | `moshi-codegen`, `protobuf` | — | `moshi-codegen`, `protobuf` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` | [php/results.md](php/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `msgpackr`, `google-protobuf` | [javascript/results.md](javascript/results.md) |
| rust | ok | `prost` | — | `prost` | [rust/results.md](rust/results.md) |
| c | ok | `protobuf-c` | — | `protobuf-c` | [c/results.md](c/results.md) |
| cpp | ok | `protobuf-wire` | — | `protobuf-wire` | [cpp/results.md](cpp/results.md) |
| csharp | ok | `SpanJson` | — | `SpanJson`, `MessagePack-CSharp` | [csharp/results.md](csharp/results.md) |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf` | [swift/results.md](swift/results.md) |
| zig | ok | `protobuf` | — | `protobuf` | [zig/results.md](zig/results.md) |

## In memory, by language

Every listed library (public JSON, MessagePack, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**. A faster row is not automatically the right public format.

### python

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| msgspec-msgpack | 4.37 | 129 | compact internal bytes — MessagePack | fastest |
| orjson | 5.18 | 448 | public JSON — fastest named JSON from Experiment 1 | similar |
| protobuf | 6.69 | 155 | shared schema — Protocol Buffers | slower |
| json | 26.2 | 448 | public JSON — ships with Python | slower |

### go

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| goccy/go-json | 3.69 | 448 | public JSON — fastest named JSON from Experiment 1 | fastest |
| protobuf | 4.26 | 155 | shared schema — Protocol Buffers | similar |
| vmihailenco/msgpack | 6.30 | 397 | compact internal bytes — MessagePack | slower |
| encoding/json | 10.3 | 448 | public JSON — ships with Go | slower |

### java

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| jsoniter | 52.8 | 440 | public JSON — fastest named JSON from Experiment 1 | fastest |
| jackson | 94.1 | 440 | public JSON — common default in Java services | slower |
| protobuf | 101 | 155 | shared schema — Protocol Buffers | slower |
| msgpack | 118 | 317 | compact internal bytes — MessagePack | slower |

### kotlin

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| moshi-codegen | 57.1 | 440 | public JSON — fastest named JSON from Experiment 1 | fastest |
| protobuf | 66.1 | 155 | shared schema — Protocol Buffers | similar |
| kotlinx-json | 104 | 440 | public JSON — compiler-generated kotlinx.serialization | slower |
| msgpack | 181 | 317 | compact internal bytes — MessagePack | slower |

### php

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 6.14 | 454 | public JSON — ships with PHP (also fastest in Experiment 1) | fastest |
| rybakit-msgpack | 22.0 | 335 | compact internal bytes — MessagePack | slower |
| protobuf | 199 | 160 | shared schema — Protocol Buffers | slower |

### javascript

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 8.70 | 448 | public JSON — ships with JavaScript (also fastest in Experiment 1) | fastest |
| msgpackr | 16.2 | 345 | compact internal bytes — MessagePack | slower |
| google-protobuf | 38.9 | 155 | shared schema — Protocol Buffers | slower |

### rust

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 1.43 | 155 | shared schema — Protocol Buffers | fastest |
| rmp-serde | 1.96 | 333 | compact internal bytes — MessagePack | slower |
| sonic-rs | 2.23 | 460 | public JSON — fastest named JSON from Experiment 1 | slower |
| serde_json | 2.74 | 460 | public JSON — usual Rust library | slower |

### c

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-c | 1.12 | 166 | shared schema — Protocol Buffers (timed path is the suite wire codec) | fastest |
| mpack | 2.73 | 335 | compact internal bytes — MessagePack | slower |
| yyjson | 5.58 | 460 | public JSON — fastest named JSON from Experiment 1 | slower |
| cJSON | 13.5 | 460 | public JSON — small common C library | slower |

### cpp

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 3.19 | 164 | shared schema — Protocol Buffers (in-tree wire helper) | fastest |
| msgpack | 3.55 | 332 | compact internal bytes — MessagePack | slower |
| simdjson | 9.69 | 458 | public JSON — fastest named JSON from Experiment 1 | slower |
| nlohmann_json | 12.4 | 458 | public JSON — common C++ library | slower |

### csharp

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 14.1 | 440 | public JSON — fastest named JSON from Experiment 1 | fastest |
| MessagePack-CSharp | 22.1 | 188 | compact internal bytes — MessagePack | slower |
| Google.Protobuf | 22.3 | 208 | shared schema — Protocol Buffers | slower |
| System.Text.Json | 68.7 | 440 | public JSON — ships with modern .NET | slower |

### swift

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 16.7 | 155 | shared schema — Protocol Buffers | fastest |
| IkigaJSON | 59.7 | 448 | public JSON — fastest named JSON from Experiment 1 | slower |
| Foundation.JSONEncoder | 65.1 | 448 | public JSON — ships with Swift | slower |
| SwiftMsgpack | 91.8 | 329 | compact internal bytes — MessagePack | slower |

### zig

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 1.14 | 155 | shared schema — Protocol Buffers | fastest |
| serde.msgpack | 1.67 | 325 | compact internal bytes — MessagePack | slower |
| serde.json | 2.42 | 448 | public JSON — fastest named JSON from Experiment 1 | slower |
| std.json | 3.42 | 448 | public JSON — ships with Zig | slower |

## What this page is not

- It is not a ranking of languages.
- It is not a ranking of formats. Pick the row that matches the job you have.
- It is not a promise that the same names stay on top if you change the record.

