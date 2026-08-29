# Should two services inside the company stop using JSON?

**Question:** On one small record, how do JSON, MessagePack, and Protocol Buffers compare?
**Date:** 2026-08-29
**Sample:** `message`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. Groups for 1 record and for 100 records are separate.

## At a glance (1 record per write)

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| python | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [python/results.md](python/results.md) |
| go | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [go/results.md](go/results.md) |
| java | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [java/results.md](java/results.md) |
| kotlin | ok | `protobuf` | — | `protobuf` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` | [php/results.md](php/results.md) |
| javascript | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [javascript/results.md](javascript/results.md) |
| rust | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [rust/results.md](rust/results.md) |
| c | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [c/results.md](c/results.md) |
| cpp | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [cpp/results.md](cpp/results.md) |
| csharp | ok | `SpanJson` | `Google.Protobuf` | `SpanJson`, `Google.Protobuf` | [csharp/results.md](csharp/results.md) |
| swift | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [swift/results.md](swift/results.md) |
| zig | ok | `comptime-bin` | — | `comptime-bin`, `protobuf` | [zig/results.md](zig/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | missing | — | — | — |
| go | missing | — | — | — |
| java | missing | — | — | — |
| kotlin | ok | `protobuf` | — | `protobuf` |
| php | ok | `json` | — | `json`, `rybakit-msgpack`, `protobuf` |
| javascript | missing | — | — | — |
| rust | missing | — | — | — |
| c | missing | — | — | — |
| cpp | missing | — | — | — |
| csharp | ok | `MessagePack-CSharp`, `Google.Protobuf` | `ProtoBuf`, `SpanJson` | `MessagePack-CSharp`, `Google.Protobuf` |
| swift | missing | — | — | — |
| zig | ok | `comptime-bin` | — | `comptime-bin`, `protobuf` |

## In memory, by language

Every listed library (JSON, MessagePack, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**.

### python

no CSV in this language folder yet

### go

no CSV in this language folder yet

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

no CSV in this language folder yet

### rust

no CSV in this language folder yet

### c

no CSV in this language folder yet

### cpp

no CSV in this language folder yet

### csharp

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| SpanJson | 10.2 | 157 | JSON — fast writer from Experiment 1 | fastest |
| Google.Protobuf | 10.6 | 68 | Protocol Buffers — Google library | close |
| MessagePack-CSharp | 13.9 | 72 | MessagePack | slower |
| ProtoBuf | 16.6 | 68 | Protocol Buffers — protobuf-net | slower |
| System.Text.Json | 47.2 | 212 | JSON — ships with modern .NET | slower |

**100 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| MessagePack-CSharp | 110 | 6580 | MessagePack | fastest |
| Google.Protobuf | 134 | 6456 | Protocol Buffers — Google library | similar |
| ProtoBuf | 136 | 6456 | Protocol Buffers — protobuf-net | close |
| SpanJson | 149 | 15456 | JSON — fast writer from Experiment 1 | close |
| System.Text.Json | 346 | 20608 | JSON — ships with modern .NET | slower |

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

