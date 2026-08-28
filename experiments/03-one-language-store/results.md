# Is a one-language format worth the lock-in?

**Question:** On one small record, is a format only one language can read faster than a format other languages can read?
**Date:** 2026-08-28
**Sample:** `message`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small flat record. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest in the comparison set on this sample. **Close** means a small gap. A faster one-language library is not proof that the store is safe.

## At a glance

| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |
|----------|--------|--------------------|-----------|-----------------|------------|
| python | ok | `orjson` | `msgspec-msgpack` | `orjson`, `msgspec-msgpack`, `protobuf` | [python/results.md](python/results.md) |
| java | ok | `protobuf` | — | `protobuf`, `kryo` | [java/results.md](java/results.md) |
| kotlin | ok | `protobuf` | — | `protobuf`, `kryo` | [kotlin/results.md](kotlin/results.md) |
| go | ok | `protobuf` | — | `protobuf` | [go/results.md](go/results.md) |

## In memory, by language

Every listed library (one-language, and libraries other languages can read). Times are middle values in microseconds. Lower is better **inside that language**.

### python

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| orjson | 1.70 | 168 | other languages can read — JSON | fastest |
| msgspec-msgpack | 1.86 | 52 | other languages can read — MessagePack | close |
| protobuf | 3.12 | 50 | other languages can read — Protocol Buffers | slower |
| pickle | 7.15 | 202 | one language — pickle | slower |
| cloudpickle | 15.5 | 202 | one language — cloudpickle | slower |
| dill | 57.2 | 202 | one language — dill | slower |

### java

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 25.6 | 50 | other languages can read — Protocol Buffers | fastest |
| jsoniter | 31.4 | 150 | other languages can read — JSON | slower |
| fory | 35.1 | 133 | one language — Apache Fory (Java path) | slower |
| kryo | 42.1 | 46 | one language — Kryo | slower |
| hessian | 42.5 | 143 | one language — Hessian2 | slower |
| java-serialization | 119 | 206 | one language — JDK ObjectOutputStream | slower |

### kotlin

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 39.0 | 50 | other languages can read — Protocol Buffers | fastest |
| fory | 51.2 | 133 | one language — Apache Fory | slower |
| kryo | 59.6 | 46 | one language — Kryo | slower |
| kotlinx-json | 108 | 158 | other languages can read — JSON | slower |

### go

**1 record(s) per write**

| Library | Write + read (µs) | Size (bytes) | Role | Group |
|---------|-------------------|--------------|------|-------|
| protobuf | 1.10 | 50 | other languages can read — Protocol Buffers | fastest |
| goccy/go-json | 1.70 | 168 | other languages can read — JSON | slower |
| encoding/gob | 14.6 | 173 | one language — gob | slower |

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

