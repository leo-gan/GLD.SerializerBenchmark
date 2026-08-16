# Should an internal service leave JSON?

**Question:** On one flat record, how do ordinary named JSON, MessagePack, and Protocol Buffers compare?
**Date:** 2026-08-16
**Sample:** `message`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. Groups for 1 record and for 100 records are separate.

## At a glance (1 record per write)

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| python | ok | `msgspec-msgpack` | `orjson` | `msgspec-msgpack`, `protobuf` | [python/results.md](python/results.md) |
| go | ok | `protobuf` | — | `protobuf` | [go/results.md](go/results.md) |
| java | ok | `protobuf` | — | `protobuf` | [java/results.md](java/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `msgpackr`, `@msgpack/msgpack`, `protobufjs`, `protobuf-es` | [javascript/results.md](javascript/results.md) |
| rust | ok | `prost` | — | `prost` | [rust/results.md](rust/results.md) |
| c | ok | `protobuf-c` | `protobuf-wire` | `protobuf-c` | [c/results.md](c/results.md) |
| cpp | ok | `protobuf-wire` | — | `protobuf-wire` | [cpp/results.md](cpp/results.md) |
| csharp | ok | `SpanJson` | — | `SpanJson`, `Google.Protobuf` | [csharp/results.md](csharp/results.md) |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf` | [swift/results.md](swift/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | ok | `msgspec-msgpack` | — | `msgspec-msgpack` |
| go | ok | `protobuf` | — | `protobuf` |
| java | ok | `protobuf` | `jsoniter` | `protobuf` |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `msgpackr`, `@msgpack/msgpack`, `protobufjs`, `protobuf-es` |
| rust | ok | `prost` | — | `prost` |
| c | ok | `protobuf-c`, `protobuf-wire` | — | `protobuf-c` |
| cpp | ok | `protobuf-wire`, `msgpack` | — | `protobuf-wire` |
| csharp | ok | `SpanJson` | `ProtoBuf`, `Google.Protobuf` | `SpanJson`, `ProtoBuf` |
| swift | ok | `SwiftProtobuf` | — | `SwiftProtobuf` |

## In memory, by language

Every listed library (JSON, MessagePack, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**.

### python

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| msgspec-msgpack | 1.71 | 52 | MessagePack — msgspec | fastest |
| orjson | 1.79 | 168 | JSON — fast writer from Experiment 1 | close |
| protobuf | 3.29 | 50 | Protocol Buffers | slower |
| msgpack | 4.13 | 124 | MessagePack | slower |
| json | 11.7 | 168 | JSON — ships with Python | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| msgspec-msgpack | 26.8 | 4831 | MessagePack — msgspec | fastest |
| protobuf | 30.7 | 4841 | Protocol Buffers | slower |
| orjson | 52.2 | 16546 | JSON — fast writer from Experiment 1 | slower |
| msgpack | 103 | 12031 | MessagePack | slower |
| json | 213 | 16546 | JSON — ships with Python | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 1.11 | 50 | Protocol Buffers | fastest |
| shamaton/msgpack | 1.38 | 114 | MessagePack — fast Go writer | slower |
| goccy/go-json | 1.69 | 168 | JSON — fast writer from Experiment 1 | slower |
| vmihailenco/msgpack | 1.78 | 118 | MessagePack | slower |
| encoding/json | 3.37 | 168 | JSON — ships with Go | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 37.8 | 4841 | Protocol Buffers | fastest |
| shamaton/msgpack | 48.0 | 11031 | MessagePack — fast Go writer | slower |
| goccy/go-json | 61.3 | 16546 | JSON — fast writer from Experiment 1 | slower |
| vmihailenco/msgpack | 70.1 | 11457 | MessagePack | slower |
| encoding/json | 181 | 16546 | JSON — ships with Go | slower |

### java

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 23.4 | 50 | Protocol Buffers | fastest |
| jsoniter | 30.5 | 150 | JSON — fast writer from Experiment 1 | slower |
| msgpack | 72.1 | 114 | MessagePack | slower |
| jackson | 87.0 | 158 | JSON — common default | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 134 | 4841 | Protocol Buffers | fastest |
| jsoniter | 153 | 14804 | JSON — fast writer from Experiment 1 | close |
| jackson | 251 | 15546 | JSON — common default | slower |
| msgpack | 300 | 11031 | MessagePack | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 4.84 | 168 | JSON — ships with JavaScript | fastest |
| msgpackr | 12.5 | 126 | MessagePack | slower |
| @msgpack/msgpack | 15.9 | 124 | MessagePack — official package | slower |
| protobufjs | 21.2 | 52 | Protocol Buffers | slower |
| protobuf-es | 33.2 | 50 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 90.8 | 16546 | JSON — ships with JavaScript | fastest |
| msgpackr | 116 | 12231 | MessagePack | slower |
| @msgpack/msgpack | 133 | 12031 | MessagePack — official package | slower |
| protobufjs | 134 | 5047 | Protocol Buffers | slower |
| protobuf-es | 405 | 4841 | Protocol Buffers | slower |

### rust

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 0.21 | 55 | Protocol Buffers | fastest |
| rmp-serde | 0.32 | 136 | MessagePack | slower |
| sonic-rs | 0.46 | 182 | JSON — fast writer from Experiment 1 | slower |
| serde_json | 0.53 | 182 | JSON — usual Rust library | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 23.8 | 5102 | Protocol Buffers | fastest |
| rmp-serde | 34.0 | 13364 | MessagePack | slower |
| sonic-rs | 41.9 | 18070 | JSON — fast writer from Experiment 1 | slower |
| serde_json | 59.6 | 18070 | JSON — usual Rust library | slower |

### c

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-c | 0.21 | 51 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest |
| protobuf-wire | 0.22 | 51 | Protocol Buffers — in-tree wire helper | close |
| msgpack-c | 0.90 | 125 | MessagePack — official C library | slower |
| mpack | 0.93 | 125 | MessagePack | slower |
| yyjson | 1.24 | 170 | JSON — fast writer from Experiment 1 | slower |
| cJSON | 3.34 | 170 | JSON — common C library | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-c | 27.2 | 4932 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest |
| protobuf-wire | 27.4 | 4932 | Protocol Buffers — in-tree wire helper | similar |
| mpack | 55.8 | 12295 | MessagePack | slower |
| msgpack-c | 58.0 | 12295 | MessagePack — official C library | slower |
| yyjson | 103 | 16717 | JSON — fast writer from Experiment 1 | slower |
| cJSON | 290 | 16741 | JSON — common C library | slower |

### cpp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 0.54 | 50 | Protocol Buffers — in-tree wire helper | fastest |
| msgpack | 1.09 | 124 | MessagePack | slower |
| simdjson | 3.09 | 168 | JSON — fast read from Experiment 1 | slower |
| nlohmann_json | 3.48 | 168 | JSON — common C++ library | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 37.7 | 4841 | Protocol Buffers — in-tree wire helper | fastest |
| msgpack | 38.1 | 12031 | MessagePack | similar |
| simdjson | 219 | 16546 | JSON — fast read from Experiment 1 | slower |
| nlohmann_json | 229 | 16546 | JSON — common C++ library | slower |

### csharp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 7.50 | 157 | JSON — fast writer from Experiment 1 | fastest |
| Google.Protobuf | 8.77 | 68 | Protocol Buffers — Google library | slower |
| ProtoBuf | 14.0 | 68 | Protocol Buffers — protobuf-net | slower |
| System.Text.Json | 31.6 | 212 | JSON — ships with modern .NET | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 128 | 15456 | JSON — fast writer from Experiment 1 | fastest |
| ProtoBuf | 141 | 6456 | Protocol Buffers — protobuf-net | close |
| Google.Protobuf | 151 | 6456 | Protocol Buffers — Google library | close |
| System.Text.Json | 387 | 20608 | JSON — ships with modern .NET | slower |

### swift

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 3.61 | 50 | Protocol Buffers | fastest |
| IkigaJSON | 19.3 | 168 | JSON — fast writer from Experiment 1 | slower |
| Foundation.JSONEncoder | 20.0 | 168 | JSON — ships with Swift | slower |
| SwiftMsgpack | 25.4 | 124 | MessagePack | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SwiftProtobuf | 51.4 | 4841 | Protocol Buffers | fastest |
| Foundation.JSONEncoder | 668 | 16546 | JSON — ships with Swift | slower |
| IkigaJSON | 752 | 16546 | JSON — fast writer from Experiment 1 | slower |
| SwiftMsgpack | 1132 | 12041 | MessagePack | slower |

## What we saw

Leaving JSON is not one answer. It depends on the language.

- **Python:** `orjson` is close to `msgspec-msgpack` at one record. Protocol Buffers is smaller but slower than `orjson` here. At 100 records, `orjson` is no longer close.
- **JavaScript and C#:** ordinary JSON is still the fastest write-and-read on this sample. C# has no MessagePack row.
- **Go, Java, Rust, C, C++, Swift:** a Protocol Buffers row is clearly fastest and about three times smaller than JSON.

C `protobuf-c` and the C/C++ `protobuf-wire` rows use the suite wire path. Official Google `libprotobuf` did not run in C or C++.

## What this page is not

- It is not a ranking of languages.
- It is not a promise that the same names stay on top if you change the record.
- A small gap on this tiny record is not a reason to change a public contract.

