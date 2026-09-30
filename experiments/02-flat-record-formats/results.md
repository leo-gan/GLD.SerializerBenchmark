# Should two services inside the company stop using JSON?

**Question:** On one small record, how do JSON, MessagePack, and Protocol Buffers compare?
**Date:** 2026-09-30
**Sample:** `message`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. Groups for 1 record and for 100 records are separate.

## At a glance (1 record per write)

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| python | ok | `msgspec-msgpack` | — | `msgspec-msgpack`, `protobuf` | [python/results.md](python/results.md) |
| go | ok | `shamaton/msgpack`, `protobuf` | — | `shamaton/msgpack`, `protobuf` | [go/results.md](go/results.md) |
| java | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [java/results.md](java/results.md) |
| kotlin | ok | `protobuf` | — | `protobuf` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` | [php/results.md](php/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `msgpackr`, `protobufjs`, `protobuf-es` | [javascript/results.md](javascript/results.md) |
| rust | ok | `prost` | — | `prost` | [rust/results.md](rust/results.md) |
| c | ok | `protobuf-wire`, `protobuf-c` | — | `protobuf-wire` | [c/results.md](c/results.md) |
| cpp | ok | `protobuf-wire` | — | `protobuf-wire` | [cpp/results.md](cpp/results.md) |
| csharp | ok | `Google.Protobuf`, `SpanJson` | — | `Google.Protobuf` | [csharp/results.md](csharp/results.md) |
| swift | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [swift/results.md](swift/results.md) |
| zig | ok | `comptime-bin` | — | `comptime-bin`, `protobuf` | [zig/results.md](zig/results.md) |
| mojo | ok | `mojo-avro`, `mojo-protobuf` | — | `mojo-avro` | [mojo/results.md](mojo/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | ok | `msgspec-msgpack` | — | `msgspec-msgpack` |
| go | ok | `protobuf` | — | `protobuf` |
| java | missing | — | — | — |
| kotlin | ok | `protobuf` | — | `protobuf` |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` |
| javascript | ok | `protobufjs`, `JSON.stringify` | — | `protobufjs`, `protobuf-es` |
| rust | ok | `prost` | — | `prost` |
| c | ok | `protobuf-c`, `protobuf-wire` | — | `protobuf-c` |
| cpp | ok | `protobuf-wire` | — | `protobuf-wire` |
| csharp | ok | `MessagePack-CSharp`, `SpanJson`, `Google.Protobuf` | `ProtoBuf` | `MessagePack-CSharp`, `ProtoBuf` |
| swift | missing | — | — | — |
| zig | ok | `comptime-bin` | — | `comptime-bin`, `protobuf` |
| mojo | ok | `mojo-avro` | — | `mojo-avro` |

## In memory, by language

Every listed library (JSON, MessagePack, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**.

### python

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| msgspec-msgpack | 2.37 | 52 | MessagePack — msgspec | fastest |
| orjson | 3.08 | 168 | JSON — fast writer from Experiment 1 | slower |
| protobuf | 4.85 | 50 | Protocol Buffers | slower |
| msgpack | 5.95 | 124 | MessagePack | slower |
| json | 17.5 | 168 | JSON — ships with Python | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| msgspec-msgpack | 30.8 | 4831 | MessagePack — msgspec | fastest |
| protobuf | 33.8 | 4841 | Protocol Buffers | slower |
| orjson | 62.2 | 16546 | JSON — fast writer from Experiment 1 | slower |
| msgpack | 112 | 12031 | MessagePack | slower |
| json | 244 | 16546 | JSON — ships with Python | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| shamaton/msgpack | 1.22 | 124 | MessagePack — fast Go writer | fastest |
| protobuf | 1.32 | 50 | Protocol Buffers | similar |
| goccy/go-json | 1.66 | 168 | JSON — fast writer from Experiment 1 | slower |
| vmihailenco/msgpack | 1.93 | 128 | MessagePack | slower |
| encoding/json | 3.70 | 168 | JSON — ships with Go | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 39.4 | 4841 | Protocol Buffers | fastest |
| shamaton/msgpack | 47.3 | 12031 | MessagePack — fast Go writer | slower |
| goccy/go-json | 60.4 | 16546 | JSON — fast writer from Experiment 1 | slower |
| vmihailenco/msgpack | 75.7 | 12457 | MessagePack | slower |
| encoding/json | 189 | 16546 | JSON — ships with Go | slower |

### java

no CSV in this language folder yet

### kotlin

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 37.8 | 50 | Protocol Buffers | fastest |
| moshi-codegen | 50.0 | 158 | JSON — fast writer from Experiment 1 | slower |
| kotlinx-json | 102 | 158 | JSON — compiler-generated kotlinx.serialization | slower |
| msgpack | 151 | 114 | MessagePack | slower |
| jackson | 158 | 158 | JSON — common default | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 110 | 4841 | Protocol Buffers | fastest |
| moshi-codegen | 222 | 15546 | JSON — fast writer from Experiment 1 | slower |
| kotlinx-json | 246 | 15546 | JSON — compiler-generated kotlinx.serialization | slower |
| jackson | 356 | 15546 | JSON — common default | slower |
| msgpack | 368 | 11031 | MessagePack | slower |

### php

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 2.83 | 168 | JSON — stdlib | fastest |
| rybakit-msgpack | 8.49 | 126 | MessagePack | slower |
| protobuf | 47.0 | 54 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 157 | 16337 | JSON — stdlib | fastest |
| rybakit-msgpack | 417 | 11818 | MessagePack | slower |
| protobuf | 3623 | 4665 | Protocol Buffers | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 5.81 | 168 | JSON — ships with JavaScript | fastest |
| msgpackr | 14.0 | 126 | MessagePack | slower |
| protobufjs | 16.7 | 52 | Protocol Buffers | slower |
| @msgpack/msgpack | 18.3 | 124 | MessagePack — official package | slower |
| protobuf-es | 22.1 | 50 | Protocol Buffers | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobufjs | 90.7 | 5047 | Protocol Buffers | fastest |
| JSON.stringify | 96.5 | 16546 | JSON — ships with JavaScript | similar |
| msgpackr | 121 | 12231 | MessagePack | slower |
| protobuf-es | 125 | 4841 | Protocol Buffers | slower |
| @msgpack/msgpack | 132 | 12031 | MessagePack — official package | slower |

### rust

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 0.47 | 55 | Protocol Buffers | fastest |
| rmp-serde | 0.86 | 136 | MessagePack | slower |
| sonic-rs | 1.14 | 182 | JSON — fast writer from Experiment 1 | slower |
| serde_json | 1.25 | 182 | JSON — usual Rust library | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| prost | 22.6 | 5102 | Protocol Buffers | fastest |
| rmp-serde | 37.7 | 13364 | MessagePack | slower |
| sonic-rs | 44.6 | 18070 | JSON — fast writer from Experiment 1 | slower |
| serde_json | 66.0 | 18070 | JSON — usual Rust library | slower |

### c

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 0.39 | 51 | Protocol Buffers — in-tree wire helper | fastest |
| protobuf-c | 0.39 | 51 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | similar |
| msgpack-c | 1.32 | 125 | MessagePack — official C library | slower |
| mpack | 1.36 | 125 | MessagePack | slower |
| yyjson | 2.13 | 170 | JSON — fast writer from Experiment 1 | slower |
| cJSON | 5.21 | 170 | JSON — common C library | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-c | 41.6 | 4932 | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest |
| protobuf-wire | 41.7 | 4932 | Protocol Buffers — in-tree wire helper | similar |
| mpack | 71.2 | 12295 | MessagePack | slower |
| msgpack-c | 74.1 | 12295 | MessagePack — official C library | slower |
| yyjson | 119 | 16717 | JSON — fast writer from Experiment 1 | slower |
| cJSON | 314 | 16741 | JSON — common C library | slower |

### cpp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 2.25 | 50 | Protocol Buffers — in-tree wire helper | fastest |
| msgpack | 4.15 | 124 | MessagePack | slower |
| simdjson | 10.2 | 168 | JSON — fast read from Experiment 1 | slower |
| nlohmann_json | 12.9 | 168 | JSON — common C++ library | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf-wire | 53.6 | 4841 | Protocol Buffers — in-tree wire helper | fastest |
| msgpack | 64.6 | 12031 | MessagePack | slower |
| simdjson | 245 | 16546 | JSON — fast read from Experiment 1 | slower |
| nlohmann_json | 357 | 16546 | JSON — common C++ library | slower |

### csharp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| Google.Protobuf | 11.0 | 68 | Protocol Buffers — Google library | fastest |
| SpanJson | 11.3 | 157 | JSON — fast writer from Experiment 1 | similar |
| MessagePack-CSharp | 14.8 | 72 | MessagePack | slower |
| ProtoBuf | 17.1 | 68 | Protocol Buffers — protobuf-net | slower |
| System.Text.Json | 49.6 | 157 | JSON — ships with modern .NET | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| MessagePack-CSharp | 117 | 6580 | MessagePack | fastest |
| SpanJson | 126 | 15456 | JSON — fast writer from Experiment 1 | similar |
| ProtoBuf | 129 | 6456 | Protocol Buffers — protobuf-net | close |
| Google.Protobuf | 151 | 6456 | Protocol Buffers — Google library | similar |
| System.Text.Json | 332 | 15456 | JSON — ships with modern .NET | slower |

### swift

no CSV in this language folder yet

### zig

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| comptime-bin | 0.16 | 57 | comptime byte-packed binary | fastest |
| protobuf | 0.30 | 50 | Protocol Buffers | slower |
| flatbuffers | 0.33 | 108 | FlatBuffers | slower |
| serde.msgpack | 0.54 | 124 | MessagePack — serde.zig | slower |
| zbor | 0.95 | 124 | CBOR — zbor | slower |
| std.json | 1.24 | 168 | JSON — stdlib | slower |
| zig-msgpack | 1.53 | 124 | MessagePack — zigcc | slower |
| capnproto | 2.79 | 96 | Cap’n Proto | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| comptime-bin | 6.98 | 5758 | comptime byte-packed binary | fastest |
| flatbuffers | 15.6 | 10644 | FlatBuffers | slower |
| protobuf | 15.9 | 5045 | Protocol Buffers | slower |
| serde.msgpack | 32.6 | 12432 | MessagePack — serde.zig | slower |
| zbor | 74.0 | 12432 | CBOR — zbor | slower |
| std.json | 96.9 | 16849 | JSON — stdlib | slower |
| zig-msgpack | 126 | 12432 | MessagePack — zigcc | slower |
| capnproto | 181 | 9572 | Cap’n Proto | slower |

### mojo

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mojo-avro | 0.58 | 44 | Avro | fastest |
| mojo-protobuf | 0.60 | 50 | Protocol Buffers | similar |
| mojo-json | 0.66 | 164 | JSON — mojo-json | slower |
| EmberJson | 0.87 | 168 | JSON — EmberJson | slower |
| mojo-flatbuffers | 1.05 | 104 | FlatBuffers | slower |
| mojo-cbor | 1.59 | 124 | CBOR | slower |
| ehsanmok-json | 3.78 | 168 | JSON — ehsanmok/json | slower |
| mojo-toml | 13.7 | 167 | TOML | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mojo-avro | 39.7 | 4051 | Avro | fastest |
| mojo-json | 44.5 | 16114 | JSON — mojo-json | slower |
| mojo-protobuf | 46.9 | 4841 | Protocol Buffers | slower |
| EmberJson | 57.2 | 16556 | JSON — EmberJson | slower |
| mojo-flatbuffers | 84.9 | 8032 | FlatBuffers | slower |
| mojo-cbor | 135 | 12037 | CBOR | slower |
| ehsanmok-json | 314 | 16556 | JSON — ehsanmok/json | slower |
| mojo-toml | 1660 | 17554 | TOML | slower |

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

