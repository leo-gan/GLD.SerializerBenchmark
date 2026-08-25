# Should an internal service leave JSON?

**Question:** On one flat record, how do ordinary named JSON, MessagePack, and Protocol Buffers compare?
**Date:** 2026-08-17
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
| javascript | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [javascript/results.md](javascript/results.md) |
| rust | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [rust/results.md](rust/results.md) |
| c | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [c/results.md](c/results.md) |
| cpp | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [cpp/results.md](cpp/results.md) |
| csharp | ok | `SpanJson` | `Google.Protobuf` | `SpanJson`, `Google.Protobuf` | [csharp/results.md](csharp/results.md) |
| swift | missing | no CSV in this language folder yet | no CSV in this language folder yet | no CSV in this language folder yet | [swift/results.md](swift/results.md) |

## At a glance (100 records per write)

| Language | Status | Not clearly slower | Small gap | Time/size front |
|----------|--------|--------------------|-----------|-----------------|
| python | missing | — | — | — |
| go | missing | — | — | — |
| java | missing | — | — | — |
| javascript | missing | — | — | — |
| rust | missing | — | — | — |
| c | missing | — | — | — |
| cpp | missing | — | — | — |
| csharp | ok | `MessagePack-CSharp`, `Google.Protobuf` | `ProtoBuf`, `SpanJson` | `MessagePack-CSharp`, `Google.Protobuf` |
| swift | missing | — | — | — |

## In memory, by language

Every listed library (JSON, MessagePack, Protocol Buffers). Times are middle values in microseconds. Lower is better **inside that language**.

### python

no CSV in this language folder yet

### go

no CSV in this language folder yet

### java

no CSV in this language folder yet

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

