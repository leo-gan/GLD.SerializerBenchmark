# Are database formats better for a normal service call?

**Question:** On one order, do BSON, Smile, and Ion beat JSON and MessagePack when we write the whole record and read it all back?
**Date:** 2026-10-11
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. A faster one-language library is not proof that the store is safe.

## At a glance

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| java | ok | `jackson-smile`, `jackson`, `jackson-cbor` | — | `jackson-smile` | [java/results.md](java/results.md) |
| kotlin | ok | `jackson`, `jackson-cbor` | `kotlinx-ion`, `msgpack` | `jackson`, `jackson-cbor`, `kotlinx-ion` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json`, `rybakit-msgpack` | [php/results.md](php/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify`, `msgpackr` | [javascript/results.md](javascript/results.md) |
| go | ok | `goccy/go-json` | — | `goccy/go-json`, `vmihailenco/msgpack` | [go/results.md](go/results.md) |
| rust | ok | `rmp-serde` | `sonic-rs` | `rmp-serde` | [rust/results.md](rust/results.md) |
| c | ok | `mpack` | — | `mpack` | [c/results.md](c/results.md) |
| swift | ok | `IkigaJSON` | — | `IkigaJSON`, `SwiftMsgpack` | [swift/results.md](swift/results.md) |
| zig | ok | `flatbuffers`, `serde.msgpack` | — | `flatbuffers`, `serde.msgpack`, `protobuf` | [zig/results.md](zig/results.md) |
| mojo | ok | `mojo-json` | — | `mojo-json`, `mojo-cbor` | [mojo/results.md](mojo/results.md) |
| fortran | ok | `jonquil` | — | `jonquil`, `json-fortran` | [fortran/results.md](fortran/results.md) |

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
| jackson | 171 | 440 | JSON — Jackson | fastest |
| jackson-cbor | 172 | 334 | CBOR — Jackson | similar |
| kotlinx-ion | 219 | 234 | Ion | close |
| msgpack | 222 | 317 | MessagePack | close |
| kbson | 234 | 1000 | BSON | slower |

### php

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| json | 6.42 | 454 | JSON | fastest |
| rybakit-msgpack | 21.8 | 335 | MessagePack | slower |
| cbor | 143 | 339 | CBOR | slower |

### javascript

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| JSON.stringify | 10.3 | 448 | JSON | fastest |
| msgpackr | 19.7 | 345 | MessagePack | slower |
| bson | 32.6 | 493 | BSON | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| goccy/go-json | 4.58 | 448 | JSON — Experiment 1 | fastest |
| vmihailenco/msgpack | 7.26 | 405 | MessagePack | slower |
| mongo-bson | 13.7 | 525 | BSON | slower |

### rust

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| rmp-serde | 3.01 | 333 | MessagePack | fastest |
| sonic-rs | 3.44 | 460 | JSON — Experiment 1 | close |
| bson | 7.11 | 540 | BSON | slower |

### c

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mpack | 3.12 | 335 | MessagePack | fastest |
| yyjson | 6.15 | 460 | JSON — Experiment 1 | slower |
| libbson | 8.62 | 577 | BSON | slower |

### swift

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| IkigaJSON | 51.8 | 448 | JSON — Experiment 1 | fastest |
| SwiftMsgpack | 82.4 | 329 | MessagePack | slower |
| SwiftBSON | 106 | 525 | BSON | slower |

### zig

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| flatbuffers | 1.08 | 468 | FlatBuffers | fastest |
| serde.msgpack | 1.08 | 325 | MessagePack | similar |
| protobuf | 1.26 | 155 | Protocol Buffers | slower |
| std.json | 3.00 | 448 | JSON | slower |
| serde.zon | 3.00 | 994 | ZON | slower |
| capnproto | 10.5 | 376 | Cap’n Proto | slower |

### mojo

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| mojo-json | 4.63 | 448 | JSON — mojo-json | fastest |
| mojo-cbor | 7.18 | 332 | CBOR | slower |
| EmberJson | 10.7 | 448 | JSON | slower |
| ehsanmok-json | 14.8 | 448 | JSON — ehsanmok/json | slower |

### fortran

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| jonquil | 62.8 | 505 | JSON — jonquil | fastest |
| json-fortran | 69.0 | 473 | JSON — json-fortran | slower |
| rojff | 84.4 | 473 | JSON — rojff | slower |

## What we saw

On a full write-and-read of this order, **BSON loses**. It is larger and slower than MessagePack in every language we ran. Keep BSON for Mongo.

- **Java:** `jackson-smile` is not clearly slower (about 96 µs, 233 bytes). Jackson JSON is similar in time and larger (440 bytes). BSON is 517 bytes and slower. Ion is slowest. Smile is a fair format **inside a Jackson group**, not on a public website.
- **JavaScript, Go, Rust, C:** JSON or MessagePack is fastest. BSON is largest (493–577 bytes) and slowest.

## What this page is not

- It is not a ranking of languages.
- It is not time to skip one field in a large stored record.
- It is not MongoDB disk layout or Elasticsearch index cost.

