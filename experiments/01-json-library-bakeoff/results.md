# Which JSON library is fastest?

**Question:** We have to send JSON (the usual web text). Each timed call is one shop order — an id, a status, and eight line items, about 450 bytes — not a file of many orders. Which JSON library is fastest?
**Date:** 2026-10-10
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small order. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest named-JSON library on this sample. **Close** means a small gap.

## At a glance

| Language | Status | Not clearly slower | Small gap | Not both slower and larger | Full table |
|----------|--------|--------------------|-----------|----------------------------|------------|
| python | ok | `orjson` | — | `orjson` | [python/results.md](python/results.md) |
| go | ok | `goccy/go-json`, `segmentio/encoding/json`, `sonic` | — | `goccy/go-json` | [go/results.md](go/results.md) |
| java | ok | `jsoniter` | — | `jsoniter` | [java/results.md](java/results.md) |
| kotlin | ok | `moshi-codegen`, `moshi-reflect` | — | `moshi-codegen` | [kotlin/results.md](kotlin/results.md) |
| php | ok | `json` | — | `json` | [php/results.md](php/results.md) |
| javascript | ok | `JSON.stringify` | — | `JSON.stringify` | [javascript/results.md](javascript/results.md) |
| rust | ok | `sonic-rs` | — | `sonic-rs` | [rust/results.md](rust/results.md) |
| c | ok | `yyjson` | — | `yyjson` | [c/results.md](c/results.md) |
| cpp | ok | `yyjson` | — | `yyjson` | [cpp/results.md](cpp/results.md) |
| csharp | ok | `SpanJson` | — | `SpanJson` | [csharp/results.md](csharp/results.md) |
| swift | ok | `IkigaJSON` | — | `IkigaJSON` | [swift/results.md](swift/results.md) |
| zig | ok | `serde.json` | — | `serde.json` | [zig/results.md](zig/results.md) |
| mojo | ok | `mojo-json` | — | `mojo-json` | [mojo/results.md](mojo/results.md) |
| fortran | ok | `json-fortran`, `jonquil` | — | `json-fortran` | [fortran/results.md](fortran/results.md) |

## Named JSON, in memory, by language

Only libraries that write ordinary named fields, in-memory call. Times are middle values in microseconds. Lower is better **inside that language**.

### python

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 5.63 | 448 | fastest |
| serpyco-rs | 11.2 | 448 | slower |
| mashumaro | 14.3 | 448 | slower |
| rapidjson | 17.0 | 448 | slower |
| json | 27.3 | 448 | slower |
| pydantic | 32.2 | 448 | slower |

### go

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 4.26 | 448 | fastest |
| segmentio/encoding/json | 4.45 | 448 | similar |
| sonic | 4.51 | 448 | similar |
| jsoniter | 5.56 | 448 | slower |
| ugorji/json | 7.00 | 448 | slower |
| encoding/json | 11.6 | 448 | slower |

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
| JSON.stringify | 9.27 | 448 | fastest |
| fast-json-stringify | 13.0 | 448 | slower |
| simdjson-parse+JSON.stringify | 28.2 | 448 | slower |

### rust

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 2.66 | 460 | fastest |
| serde_json | 3.22 | 460 | slower |
| simd-json | 3.75 | 460 | slower |

### c

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 5.66 | 460 | fastest |
| cJSON | 13.9 | 460 | slower |
| json-c | 18.8 | 460 | slower |
| jansson | 22.1 | 460 | slower |
| parson | 26.2 | 460 | slower |

### cpp

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 23.5 | 458 | fastest |
| rapidjson | 26.8 | 458 | slower |
| simdjson | 29.3 | 458 | slower |
| arduinojson | 35.2 | 458 | slower |
| nlohmann_json | 35.4 | 458 | slower |

### csharp

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 14.2 | 440 | fastest |
| NetJSON | 22.7 | 440 | slower |
| Utf8Json | 26.7 | 440 | slower |
| MS Bond Json | 37.3 | 440 | slower |
| Jil | 40.8 | 440 | slower |
| System.Text.Json | 62.0 | 440 | slower |
| ServiceStack Json | 73.2 | 440 | slower |
| fastJson | 87.0 | 972 | slower |
| MS DataContract Json | 87.8 | 440 | slower |
| FsPicklerJson | 91.9 | 768 | slower |
| Json.Net | 92.6 | 560 | slower |
| Json.Net (Helper) | 93.9 | 541 | slower |

### swift

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 54.4 | 448 | fastest |
| Foundation.JSONEncoder | 55.7 | 448 | slower |

### zig

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 2.61 | 448 | fastest |
| std.json.scanner | 3.70 | 448 | slower |
| std.json | 3.70 | 448 | slower |

### mojo

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 1.93 | 452 | fastest |
| EmberJson | 2.32 | 452 | slower |
| ehsanmok-json | 8.40 | 452 | slower |

### fortran

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 72.1 | 473 | fastest |
| jonquil | 72.4 | 505 | similar |
| rojff | 96.1 | 473 | slower |

## What this page is not

- It is not a ranking of languages.
- It is not a ranking of formats. Everyone here writes JSON text.
- It is not a promise that the same names stay on top if you change the record.

