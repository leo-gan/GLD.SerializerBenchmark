# Are database formats better for a normal service call?

**Question:** On one order, do BSON, Smile, and Ion beat JSON and MessagePack when we write the whole record and read it all back?
**Date:** 2026-08-29
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. A faster one-language library is not proof that the store is safe.

## At a glance

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| java | ok | `jackson-smile`, `jackson`, `jackson-cbor` | — | `jackson-smile` | [java/results.md](java/results.md) |
| kotlin | ok | `jackson-cbor`, `jackson` | — | `jackson-cbor`, `msgpack`, `kotlinx-ion` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack` | [php/results.md](php/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `msgpackr` | [javascript/results.md](javascript/results.md) |
| go | ok | `goccy/go-json` | — | `goccy/go-json`, `vmihailenco/msgpack` | [go/results.md](go/results.md) |
| rust | ok | `rmp-serde` | — | `rmp-serde` | [rust/results.md](rust/results.md) |
| c | ok | `mpack` | — | `mpack` | [c/results.md](c/results.md) |
| swift | ok | `IkigaJSON` | — | `IkigaJSON`, `SwiftMsgpack` | [swift/results.md](swift/results.md) |
| zig | ok | `flatbuffers` | `protobuf` | `flatbuffers`, `protobuf` | [zig/results.md](zig/results.md) |

## In memory, by language

Every listed library (one-language, and libraries other languages can read). Times are middle values in microseconds. Lower is better **inside that language**.

### java

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| jackson-smile | 95.6 | 233 | Smile — Jackson | fastest |
| jackson | 114 | 440 | JSON — Jackson | similar |
| jackson-cbor | 117 | 334 | CBOR — Jackson | similar |
| msgpack | 150 | 317 | MessagePack — Jackson | slower |
| bson | 171 | 517 | BSON | slower |
| ion | 297 | 380 | Ion — Jackson | slower |

### kotlin

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| jackson-cbor | 140 | 334 | CBOR — Jackson | fastest |
| jackson | 150 | 440 | JSON — Jackson | similar |
| msgpack | 162 | 317 | MessagePack | slower |
| kotlinx-ion | 183 | 234 | Ion | slower |
| kbson | 191 | 1032 | BSON | slower |

### php

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 5.97 | 454 | JSON | fastest |
| rybakit-msgpack | 22.2 | 335 | MessagePack | slower |
| cbor | 243 | 339 | CBOR | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 7.13 | 448 | JSON | fastest |
| msgpackr | 17.6 | 345 | MessagePack | slower |
| bson | 27.2 | 493 | BSON | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| goccy/go-json | 3.72 | 448 | JSON — Experiment 1 | fastest |
| vmihailenco/msgpack | 6.41 | 397 | MessagePack | slower |
| mongo-bson | 13.0 | 525 | BSON | slower |

### rust

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| rmp-serde | 1.41 | 333 | MessagePack | fastest |
| sonic-rs | 1.80 | 460 | JSON — Experiment 1 | slower |
| bson | 3.92 | 540 | BSON | slower |

### c

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mpack | 2.82 | 335 | MessagePack | fastest |
| yyjson | 4.79 | 460 | JSON — Experiment 1 | slower |
| libbson | 6.71 | 577 | BSON | slower |

### swift

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| IkigaJSON | 49.4 | 448 | JSON — Experiment 1 | fastest |
| SwiftMsgpack | 78.2 | 329 | MessagePack | slower |
| SwiftBSON | 102 | 525 | BSON | slower |

### zig

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| flatbuffers | 2.64 | 468 | FlatBuffers | fastest |
| protobuf | 2.78 | 155 | Protocol Buffers | close |
| serde.msgpack | 3.74 | 325 | MessagePack | slower |
| serde.zon | 6.26 | 994 | ZON | slower |
| std.json | 7.92 | 448 | JSON | slower |
| capnproto | 25.9 | 376 | Cap’n Proto | slower |

## What we saw

On a full write-and-read of this order, **BSON loses**. It is larger and slower than MessagePack in every language we ran. Keep BSON for Mongo.

- **Java:** `jackson-smile` is not clearly slower (about 96 µs, 233 bytes). Jackson JSON is similar in time and larger (440 bytes). BSON is 517 bytes and slower. Ion is slowest. Smile is a fair format **inside a Jackson group**, not on a public website.
- **JavaScript, Go, Rust, C:** JSON or MessagePack is fastest. BSON is largest (493–577 bytes) and slowest.

## What this page is not

- It is not a ranking of languages.
- It is not time to skip one field in a large stored record.
- It is not MongoDB disk layout or Elasticsearch index cost.

