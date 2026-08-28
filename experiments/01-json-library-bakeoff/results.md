# Which JSON library is fastest?

**Question:** We have to send JSON (the usual web text). Each timed call is one shop order — an id, a status, and eight line items, about 450 bytes — not a file of many orders. Which JSON library is fastest?
**Date:** 2026-08-28
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small order. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest named-JSON library on this sample. **Close** means a small gap.

## At a glance

| Language | Status | Not clearly slower | Small gap | Not both slower and larger | Full table |
|----------|--------|--------------------|-----------|----------------------------|------------|
| python | ok | `orjson` | — | `orjson` | [python/results.md](python/results.md) |
| go | ok | `goccy/go-json` | `segmentio/encoding/json`, `sonic` | `goccy/go-json` | [go/results.md](go/results.md) |
| java | ok | `jsoniter` | — | `jsoniter` | [java/results.md](java/results.md) |
| kotlin | ok | `moshi-codegen`, `moshi-reflect` | — | `moshi-codegen` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json` | [php/results.md](php/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify` | [javascript/results.md](javascript/results.md) |
| rust | ok | `sonic-rs` | — | `sonic-rs` | [rust/results.md](rust/results.md) |
| c | ok | `yyjson` | — | `yyjson` | [c/results.md](c/results.md) |
| cpp | ok | `simdjson` | — | `simdjson` | [cpp/results.md](cpp/results.md) |
| csharp | ok | `SpanJson` | — | `SpanJson` | [csharp/results.md](csharp/results.md) |
| swift | ok | `IkigaJSON` | — | `IkigaJSON` | [swift/results.md](swift/results.md) |

## Named JSON, in memory, by language

Only libraries that write ordinary named fields, in-memory call. Times are middle values in microseconds. Lower is better **inside that language**.

### python

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 3.89 | 448 | fastest |
| serpyco-rs | 7.86 | 448 | slower |
| mashumaro | 11.8 | 448 | slower |
| rapidjson | 13.2 | 448 | slower |
| json | 21.6 | 448 | slower |
| pydantic | 26.2 | 448 | slower |

### go

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 3.12 | 448 | fastest |
| segmentio/encoding/json | 3.36 | 448 | close |
| sonic | 3.49 | 448 | close |
| jsoniter | 4.29 | 448 | slower |
| ugorji/json | 4.97 | 448 | slower |
| encoding/json | 9.00 | 448 | slower |

### java

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 42.7 | 440 | fastest |
| fastjson2 | 69.0 | 440 | slower |
| gson | 70.9 | 440 | slower |
| moshi | 84.2 | 440 | slower |
| jackson | 92.8 | 440 | slower |
| dsl-json | 92.9 | 440 | slower |

### kotlin

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 51.0 | 440 | fastest |
| moshi-reflect | 52.2 | 440 | similar |
| kotlinx-json | 105 | 440 | slower |
| gson | 110 | 440 | slower |
| jackson | 161 | 440 | slower |

### php

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 6.07 | 454 | fastest |
| symfony-json | 7.59 | 454 | slower |
| jms-json | 34.6 | 454 | slower |

### javascript

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 7.06 | 448 | fastest |
| fast-json-stringify | 10.8 | 448 | slower |
| simdjson-parse+JSON.stringify | 20.3 | 448 | slower |

### rust

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 1.30 | 460 | fastest |
| serde_json | 1.63 | 460 | slower |
| simd-json | 1.97 | 460 | slower |

### c

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 4.67 | 460 | fastest |
| cJSON | 9.50 | 460 | slower |
| json-c | 16.6 | 460 | slower |
| jansson | 17.8 | 460 | slower |
| parson | 20.3 | 460 | slower |

### cpp

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 9.11 | 458 | fastest |
| nlohmann_json | 9.71 | 458 | slower |
| yyjson | 10.1 | 458 | slower |
| rapidjson | 13.4 | 458 | slower |
| arduinojson | 15.6 | 458 | slower |

### csharp

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 12.9 | 440 | fastest |
| NetJSON | 23.0 | 440 | slower |
| Utf8Json | 26.3 | 440 | slower |
| MS Bond Json | 36.2 | 440 | slower |
| Jil | 38.4 | 440 | slower |
| System.Text.Json | 63.9 | 588 | slower |
| ServiceStack Json | 72.4 | 440 | slower |
| fastJson | 85.7 | 972 | slower |
| Json.Net (Helper) | 86.9 | 541 | slower |
| Json.Net | 87.3 | 560 | slower |
| FsPicklerJson | 92.6 | 1024 | slower |
| MS DataContract Json | 93.2 | 588 | slower |

### swift

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 54.4 | 448 | fastest |
| Foundation.JSONEncoder | 55.7 | 448 | slower |

## What this page is not

- It is not a ranking of languages.
- It is not a ranking of formats. Everyone here writes JSON text.
- It is not a promise that the same names stay on top if you change the record.

