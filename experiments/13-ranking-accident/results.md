# Does the ranking stay the same if we change the data?

**Question:** Do the ranks stay the same if we change the record, how many we write at once, or how we set aside odd trials?
**Date:** 2026-08-29
**Sample:** `['document', 'message', 'telemetry', 'event', 'strings']`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | orjson | orjson | orjson | orjson | orjson | yes | [python/results.md](python/results.md) |
| go | goccy/go-json | segmentio/encoding/json | sonic | goccy/go-json | sonic | no | [go/results.md](go/results.md) |
| java | jsoniter | jsoniter | jsoniter | dsl-json | dsl-json | no | [java/results.md](java/results.md) |
| kotlin | moshi-reflect | moshi-reflect | moshi-reflect | moshi-reflect | moshi-reflect | yes | [kotlin/results.md](kotlin/results.md) |
| php | json | json | json | json | json | yes | [php/results.md](php/results.md) |
| javascript | JSON.stringify | JSON.stringify | JSON.stringify | JSON.stringify | JSON.stringify | yes | [javascript/results.md](javascript/results.md) |
| rust | sonic-rs | sonic-rs | sonic-rs | sonic-rs | sonic-rs | yes | [rust/results.md](rust/results.md) |
| c | yyjson | yyjson | yyjson | yyjson | yyjson | yes | [c/results.md](c/results.md) |
| cpp | simdjson | yyjson | nlohmann_json | yyjson | simdjson | no | [cpp/results.md](cpp/results.md) |
| csharp | SpanJson | SpanJson | NetJSON | SpanJson | SpanJson | no | [csharp/results.md](csharp/results.md) |
| swift | IkigaJSON | IkigaJSON | IkigaJSON | IkigaJSON | IkigaJSON | yes | [swift/results.md](swift/results.md) |
| zig | serde.json | serde.json | serde.json | serde.json | serde.json | yes | [zig/results.md](zig/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | A (order) | orjson | orjson | yes |
| python | B (flat) | orjson | orjson | yes |
| python | C (sensor) | orjson | orjson | yes |
| python | D (event) | orjson | orjson | yes |
| python | E (words) | orjson | orjson | yes |
| go | A (order) | goccy/go-json | sonic | no |
| go | B (flat) | segmentio/encoding/json | sonic | no |
| go | C (sensor) | sonic | sonic | yes |
| go | D (event) | goccy/go-json | sonic | no |
| go | E (words) | sonic | sonic | yes |
| java | A (order) | jsoniter | jsoniter | yes |
| java | B (flat) | jsoniter | jsoniter | yes |
| java | C (sensor) | jsoniter | jsoniter | yes |
| java | D (event) | dsl-json | jsoniter | no |
| java | E (words) | dsl-json | jsoniter | no |
| kotlin | A (order) | moshi-reflect | moshi-codegen | no |
| kotlin | B (flat) | moshi-reflect | moshi-reflect | yes |
| kotlin | C (sensor) | moshi-reflect | jackson | no |
| kotlin | D (event) | moshi-reflect | moshi-codegen | no |
| kotlin | E (words) | moshi-reflect | jackson | no |
| php | A (order) | json | json | yes |
| php | B (flat) | json | json | yes |
| php | C (sensor) | json | json | yes |
| php | D (event) | json | json | yes |
| php | E (words) | json | json | yes |
| javascript | A (order) | JSON.stringify | JSON.stringify | yes |
| javascript | B (flat) | JSON.stringify | JSON.stringify | yes |
| javascript | C (sensor) | JSON.stringify | JSON.stringify | yes |
| javascript | D (event) | JSON.stringify | JSON.stringify | yes |
| javascript | E (words) | JSON.stringify | JSON.stringify | yes |
| rust | A (order) | sonic-rs | sonic-rs | yes |
| rust | B (flat) | sonic-rs | sonic-rs | yes |
| rust | C (sensor) | sonic-rs | serde_json | no |
| rust | D (event) | sonic-rs | sonic-rs | yes |
| rust | E (words) | sonic-rs | sonic-rs | yes |
| c | A (order) | yyjson | yyjson | yes |
| c | B (flat) | yyjson | yyjson | yes |
| c | C (sensor) | yyjson | yyjson | yes |
| c | D (event) | yyjson | yyjson | yes |
| c | E (words) | yyjson | yyjson | yes |
| cpp | A (order) | simdjson | simdjson | yes |
| cpp | B (flat) | yyjson | simdjson | no |
| cpp | C (sensor) | nlohmann_json | nlohmann_json | yes |
| cpp | D (event) | yyjson | simdjson | no |
| cpp | E (words) | simdjson | simdjson | yes |
| csharp | A (order) | SpanJson | SpanJson | yes |
| csharp | B (flat) | SpanJson | SpanJson | yes |
| csharp | C (sensor) | NetJSON | SpanJson | no |
| csharp | D (event) | SpanJson | SpanJson | yes |
| csharp | E (words) | SpanJson | SpanJson | yes |
| swift | A (order) | IkigaJSON | Foundation.JSONEncoder | no |
| swift | B (flat) | IkigaJSON | Foundation.JSONEncoder | no |
| swift | C (sensor) | IkigaJSON | IkigaJSON | yes |
| swift | D (event) | IkigaJSON | Foundation.JSONEncoder | no |
| swift | E (words) | IkigaJSON | IkigaJSON | yes |
| zig | A (order) | serde.json | serde.json | yes |
| zig | B (flat) | serde.json | serde.json | yes |
| zig | C (sensor) | serde.json | serde.json | yes |
| zig | D (event) | serde.json | serde.json | yes |
| zig | E (words) | serde.json | serde.json | yes |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | `orjson` | — |
| go | ok | `goccy/go-json`, `segmentio/encoding/json` | `sonic` |
| java | ok | `jsoniter` | — |
| kotlin | ok | `moshi-reflect`, `moshi-codegen` | — |
| php | ok | `json` | — |
| javascript | ok | `JSON.stringify` | — |
| rust | ok | `sonic-rs` | — |
| c | ok | `yyjson` | — |
| cpp | ok | `simdjson`, `nlohmann_json` | — |
| csharp | ok | `SpanJson` | — |
| swift | ok | `IkigaJSON` | — |
| zig | ok | `serde.json` | — |

## In memory, by language and sample

### python

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 3.94 | 448 | fastest |
| serpyco-rs | 7.79 | 448 | slower |
| mashumaro | 11.4 | 448 | slower |
| rapidjson | 13.0 | 448 | slower |
| json | 20.8 | 448 | slower |
| pydantic | 25.8 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 184 | 45404 | fastest |
| serpyco-rs | 402 | 45404 | slower |
| rapidjson | 475 | 45404 | slower |
| mashumaro | 545 | 45404 | slower |
| json | 599 | 45404 | slower |
| pydantic | 1378 | 51203 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 3.02 | 257 | fastest |
| serpyco-rs | 5.48 | 257 | slower |
| mashumaro | 6.96 | 257 | slower |
| rapidjson | 9.23 | 257 | slower |
| json | 15.9 | 257 | slower |
| pydantic | 19.0 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 140 | 25746 | fastest |
| serpyco-rs | 216 | 25746 | slower |
| rapidjson | 259 | 25746 | slower |
| mashumaro | 270 | 25746 | slower |
| json | 360 | 25746 | slower |
| pydantic | 789 | 28245 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 1.83 | 168 | fastest |
| serpyco-rs | 3.96 | 168 | slower |
| mashumaro | 4.25 | 168 | slower |
| rapidjson | 7.59 | 168 | slower |
| json | 12.0 | 168 | slower |
| pydantic | 13.5 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 55.6 | 16546 | fastest |
| serpyco-rs | 92.3 | 16546 | slower |
| mashumaro | 114 | 16546 | slower |
| rapidjson | 194 | 16546 | slower |
| json | 218 | 16546 | slower |
| pydantic | 408 | 18145 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 2.25 | 410 | fastest |
| serpyco-rs | 3.86 | 410 | slower |
| mashumaro | 4.42 | 410 | slower |
| rapidjson | 7.65 | 410 | slower |
| pydantic | 13.2 | 410 | slower |
| json | 13.8 | 410 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 179 | 41564 | fastest |
| serpyco-rs | 219 | 41564 | slower |
| mashumaro | 246 | 41564 | slower |
| rapidjson | 279 | 41564 | slower |
| json | 362 | 41564 | slower |
| pydantic | 578 | 44863 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 3.42 | 663 | fastest |
| serpyco-rs | 5.71 | 663 | slower |
| mashumaro | 6.51 | 663 | slower |
| pydantic | 23.5 | 663 | slower |
| rapidjson | 25.4 | 663 | slower |
| json | 30.2 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 197 | 65958 | fastest |
| serpyco-rs | 265 | 65958 | slower |
| mashumaro | 296 | 65958 | slower |
| json | 1644 | 65958 | slower |
| rapidjson | 1682 | 65958 | slower |
| pydantic | 1906 | 69957 | slower |

### go

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 3.66 | 448 | fastest |
| segmentio/encoding/json | 3.97 | 448 | similar |
| sonic | 4.26 | 448 | close |
| jsoniter | 5.20 | 448 | slower |
| ugorji/json | 5.90 | 448 | slower |
| encoding/json | 10.2 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 158 | 45404 | fastest |
| goccy/go-json | 173 | 45404 | close |
| segmentio/encoding/json | 181 | 45404 | slower |
| jsoniter | 239 | 45404 | slower |
| ugorji/json | 254 | 45404 | slower |
| encoding/json | 646 | 45404 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 2.02 | 257 | fastest |
| sonic | 2.06 | 257 | similar |
| segmentio/encoding/json | 2.25 | 257 | close |
| jsoniter | 2.40 | 257 | slower |
| ugorji/json | 3.10 | 257 | slower |
| encoding/json | 4.98 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 93.1 | 25746 | fastest |
| goccy/go-json | 105 | 25746 | slower |
| segmentio/encoding/json | 119 | 25746 | slower |
| jsoniter | 137 | 25746 | slower |
| ugorji/json | 154 | 25746 | slower |
| encoding/json | 349 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| segmentio/encoding/json | 1.88 | 168 | fastest |
| sonic | 2.04 | 168 | similar |
| goccy/go-json | 2.08 | 168 | similar |
| jsoniter | 2.27 | 168 | slower |
| ugorji/json | 2.67 | 168 | slower |
| encoding/json | 3.59 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 40.2 | 16546 | fastest |
| goccy/go-json | 56.4 | 16546 | slower |
| segmentio/encoding/json | 60.5 | 16546 | slower |
| jsoniter | 87.6 | 16546 | slower |
| ugorji/json | 88.8 | 16546 | slower |
| encoding/json | 180 | 16546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 2.32 | 411 | fastest |
| goccy/go-json | 3.22 | 411 | slower |
| jsoniter | 3.25 | 411 | slower |
| segmentio/encoding/json | 3.43 | 411 | slower |
| ugorji/json | 3.94 | 411 | slower |
| encoding/json | 7.58 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 148 | 41431 | fastest |
| ugorji/json | 214 | 41431 | slower |
| goccy/go-json | 221 | 41431 | slower |
| jsoniter | 233 | 41431 | slower |
| segmentio/encoding/json | 235 | 41431 | slower |
| encoding/json | 545 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 4.32 | 663 | fastest |
| segmentio/encoding/json | 7.16 | 663 | slower |
| goccy/go-json | 7.44 | 663 | slower |
| ugorji/json | 9.01 | 663 | slower |
| jsoniter | 10.1 | 663 | slower |
| encoding/json | 12.2 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 267 | 65958 | fastest |
| segmentio/encoding/json | 553 | 65958 | slower |
| goccy/go-json | 574 | 65958 | slower |
| ugorji/json | 620 | 65958 | slower |
| jsoniter | 775 | 65958 | slower |
| encoding/json | 946 | 65958 | slower |

### java

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 51.1 | 440 | fastest |
| fastjson2 | 87.9 | 440 | slower |
| moshi | 93.9 | 440 | slower |
| gson | 96.2 | 440 | slower |
| jackson | 97.0 | 440 | slower |
| dsl-json | 109 | 440 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 168 | 44604 | fastest |
| fastjson2 | 248 | 44604 | slower |
| dsl-json | 257 | 44604 | slower |
| jackson | 325 | 44604 | slower |
| moshi | 443 | 44604 | slower |
| gson | 727 | 44604 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| dsl-json | 11.3 | 254 | fastest |
| jsoniter | 11.8 | 254 | similar |
| gson | 12.4 | 254 | close |
| moshi | 12.5 | 254 | similar |
| jackson | 15.1 | 254 | slower |
| fastjson2 | 20.9 | 254 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 123 | 25446 | fastest |
| fastjson2 | 131 | 25446 | close |
| dsl-json | 167 | 25446 | slower |
| jackson | 185 | 25446 | slower |
| moshi | 251 | 25446 | slower |
| gson | 372 | 25446 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 28.2 | 150 | fastest |
| moshi | 43.5 | 158 | slower |
| fastjson2 | 47.5 | 158 | slower |
| gson | 52.9 | 158 | slower |
| dsl-json | 56.9 | 158 | slower |
| jackson | 61.5 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 102 | 14804 | fastest |
| fastjson2 | 125 | 15547 | close |
| jackson | 167 | 15546 | slower |
| dsl-json | 169 | 15546 | slower |
| moshi | 221 | 15546 | slower |
| gson | 277 | 15546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| dsl-json | 4.90 | 411 | fastest |
| moshi | 6.19 | 411 | slower |
| jsoniter | 6.33 | 411 | slower |
| gson | 7.47 | 411 | slower |
| jackson | 8.12 | 411 | slower |
| fastjson2 | 9.64 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 220 | 41431 | fastest |
| dsl-json | 223 | 41431 | similar |
| fastjson2 | 226 | 41431 | close |
| jackson | 230 | 41431 | slower |
| moshi | 321 | 41431 | slower |
| gson | 422 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 36.4 | 387 | fastest |
| dsl-json | 50.4 | 663 | slower |
| fastjson2 | 65.4 | 663 | slower |
| moshi | 75.8 | 663 | slower |
| gson | 77.1 | 663 | slower |
| jackson | 87.0 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 193 | 39143 | fastest |
| fastjson2 | 373 | 65960 | slower |
| dsl-json | 637 | 65958 | slower |
| jackson | 978 | 65958 | slower |
| gson | 1470 | 65958 | slower |
| moshi | 1521 | 65958 | slower |

### kotlin

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-reflect | 50.4 | 440 | fastest |
| moshi-codegen | 51.5 | 440 | similar |
| kotlinx-json | 103 | 440 | slower |
| gson | 103 | 440 | slower |
| jackson | 153 | 440 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 403 | 44604 | fastest |
| moshi-reflect | 412 | 44604 | similar |
| kotlinx-json | 443 | 44604 | slower |
| jackson | 545 | 44604 | slower |
| gson | 743 | 44604 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-reflect | 10.9 | 254 | fastest |
| moshi-codegen | 11.0 | 254 | similar |
| kotlinx-json | 12.5 | 254 | slower |
| gson | 16.9 | 254 | slower |
| jackson | 21.1 | 254 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 215 | 25446 | fastest |
| moshi-reflect | 216 | 25446 | similar |
| kotlinx-json | 231 | 25446 | slower |
| jackson | 269 | 25446 | slower |
| gson | 361 | 25446 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-reflect | 18.4 | 158 | fastest |
| moshi-codegen | 19.1 | 158 | similar |
| kotlinx-json | 35.7 | 158 | slower |
| gson | 45.5 | 158 | slower |
| jackson | 55.3 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-reflect | 191 | 15546 | fastest |
| moshi-codegen | 195 | 15546 | similar |
| kotlinx-json | 209 | 15546 | slower |
| jackson | 265 | 15546 | slower |
| gson | 351 | 15546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-reflect | 7.95 | 411 | fastest |
| moshi-codegen | 8.10 | 411 | similar |
| gson | 11.0 | 411 | slower |
| kotlinx-json | 12.3 | 411 | slower |
| jackson | 16.6 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jackson | 263 | 41431 | fastest |
| moshi-codegen | 334 | 41431 | slower |
| moshi-reflect | 336 | 41431 | slower |
| kotlinx-json | 349 | 41431 | slower |
| gson | 436 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-reflect | 39.5 | 663 | fastest |
| moshi-codegen | 40.0 | 663 | similar |
| gson | 46.7 | 663 | slower |
| kotlinx-json | 51.8 | 663 | slower |
| jackson | 65.8 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jackson | 1025 | 65958 | fastest |
| kotlinx-json | 1038 | 65958 | similar |
| gson | 1202 | 65958 | slower |
| moshi-reflect | 1253 | 65958 | slower |
| moshi-codegen | 1265 | 65958 | slower |

### php

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 6.18 | 454 | fastest |
| symfony-json | 8.26 | 454 | slower |
| jms-json | 35.9 | 454 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 430 | 45480 | fastest |
| symfony-json | 436 | 45480 | similar |
| jms-json | 1338 | 45480 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.84 | 267 | fastest |
| symfony-json | 5.76 | 267 | slower |
| jms-json | 26.5 | 267 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 221 | 25976 | fastest |
| symfony-json | 230 | 25976 | close |
| jms-json | 678 | 25976 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.00 | 168 | fastest |
| symfony-json | 4.96 | 168 | slower |
| jms-json | 23.7 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 164 | 16337 | fastest |
| symfony-json | 166 | 16337 | close |
| jms-json | 381 | 16337 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.23 | 326 | fastest |
| symfony-json | 4.93 | 326 | slower |
| jms-json | 25.7 | 326 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 251 | 34941 | fastest |
| symfony-json | 260 | 34941 | slower |
| jms-json | 907 | 34941 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 23.8 | 654 | fastest |
| symfony-json | 26.2 | 654 | slower |
| jms-json | 53.3 | 654 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 2098 | 65984 | fastest |
| symfony-json | 2106 | 65984 | similar |
| jms-json | 3012 | 65984 | slower |

### javascript

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 7.01 | 448 | fastest |
| fast-json-stringify | 11.8 | 448 | slower |
| simdjson-parse+JSON.stringify | 22.6 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 377 | 45404 | fastest |
| fast-json-stringify | 503 | 45404 | slower |
| simdjson-parse+JSON.stringify | 731 | 45404 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 3.54 | 257 | fastest |
| fast-json-stringify | 5.72 | 257 | slower |
| simdjson-parse+JSON.stringify | 12.7 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 223 | 25746 | fastest |
| fast-json-stringify | 278 | 25746 | slower |
| simdjson-parse+JSON.stringify | 438 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 3.45 | 168 | fastest |
| fast-json-stringify | 4.95 | 168 | slower |
| simdjson-parse+JSON.stringify | 11.8 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 93.1 | 16546 | fastest |
| fast-json-stringify | 121 | 16546 | slower |
| simdjson-parse+JSON.stringify | 223 | 16546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 3.55 | 411 | fastest |
| fast-json-stringify | 6.81 | 411 | slower |
| simdjson-parse+JSON.stringify | 11.8 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 359 | 41431 | fastest |
| fast-json-stringify | 520 | 41431 | slower |
| simdjson-parse+JSON.stringify | 542 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 7.81 | 663 | fastest |
| fast-json-stringify | 8.81 | 663 | close |
| simdjson-parse+JSON.stringify | 20.4 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 540 | 65958 | fastest |
| fast-json-stringify | 582 | 65958 | close |
| simdjson-parse+JSON.stringify | 863 | 65958 | slower |

### rust

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 1.50 | 460 | fastest |
| serde_json | 1.86 | 460 | slower |
| simd-json | 2.22 | 460 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 149 | 47101 | fastest |
| serde_json | 217 | 47101 | slower |
| simd-json | 237 | 47101 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 0.89 | 258 | fastest |
| serde_json | 1.18 | 258 | slower |
| simd-json | 1.72 | 258 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 102 | 26978 | fastest |
| serde_json | 149 | 26978 | slower |
| simd-json | 182 | 26978 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 0.56 | 182 | fastest |
| serde_json | 0.65 | 182 | slower |
| simd-json | 0.86 | 182 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 47.1 | 18070 | fastest |
| serde_json | 67.8 | 18070 | slower |
| simd-json | 87.1 | 18070 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 1.47 | 390 | fastest |
| serde_json | 1.77 | 390 | slower |
| simd-json | 2.54 | 390 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 188 | 42750 | fastest |
| simd-json | 260 | 42750 | slower |
| serde_json | 297 | 42750 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 1.95 | 672 | fastest |
| serde_json | 2.03 | 672 | slower |
| simd-json | 2.27 | 672 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde_json | 216 | 67763 | fastest |
| sonic-rs | 230 | 67763 | slower |
| simd-json | 235 | 67763 | slower |

### c

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 5.75 | 460 | fastest |
| cJSON | 11.1 | 460 | slower |
| json-c | 19.3 | 460 | slower |
| jansson | 20.7 | 460 | slower |
| parson | 24.5 | 460 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 345 | 45951 | fastest |
| cJSON | 805 | 45951 | slower |
| json-c | 1496 | 45951 | slower |
| jansson | 1647 | 45951 | slower |
| parson | 1998 | 45951 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 2.40 | 264 | fastest |
| cJSON | 5.59 | 264 | slower |
| json-c | 8.27 | 264 | slower |
| parson | 9.41 | 264 | slower |
| jansson | 10.3 | 264 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 207 | 25937 | fastest |
| cJSON | 436 | 25937 | slower |
| json-c | 632 | 25937 | slower |
| parson | 704 | 25937 | slower |
| jansson | 811 | 25937 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 1.52 | 171 | fastest |
| cJSON | 3.84 | 172 | slower |
| json-c | 5.17 | 172 | slower |
| jansson | 6.34 | 172 | slower |
| parson | 6.61 | 172 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 104 | 16878 | fastest |
| cJSON | 297 | 16910 | slower |
| json-c | 400 | 16962 | slower |
| jansson | 495 | 16962 | slower |
| parson | 566 | 16962 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 4.28 | 391 | fastest |
| cJSON | 8.70 | 391 | slower |
| parson | 10.6 | 391 | slower |
| json-c | 11.3 | 391 | slower |
| jansson | 16.4 | 391 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 326 | 41352 | fastest |
| cJSON | 630 | 41352 | slower |
| parson | 762 | 41352 | slower |
| json-c | 777 | 41352 | slower |
| jansson | 1145 | 41352 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 3.77 | 657 | fastest |
| json-c | 26.5 | 688 | slower |
| jansson | 30.9 | 688 | slower |
| cJSON | 34.5 | 666 | slower |
| parson | 43.2 | 688 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 275 | 66315 | fastest |
| json-c | 2273 | 68605 | slower |
| jansson | 2623 | 68605 | slower |
| cJSON | 3158 | 66887 | slower |
| parson | 3933 | 68605 | slower |

### cpp

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 9.20 | 458 | fastest |
| nlohmann_json | 9.42 | 458 | similar |
| yyjson | 9.91 | 458 | slower |
| rapidjson | 12.9 | 458 | slower |
| arduinojson | 14.2 | 458 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 688 | 45507 | fastest |
| yyjson | 699 | 45507 | close |
| nlohmann_json | 728 | 45507 | slower |
| rapidjson | 908 | 45507 | slower |
| arduinojson | 5011 | 45507 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 5.44 | 272 | fastest |
| simdjson | 5.75 | 272 | slower |
| nlohmann_json | 6.04 | 272 | slower |
| rapidjson | 8.15 | 272 | slower |
| arduinojson | 9.23 | 272 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 368 | 25463 | fastest |
| yyjson | 403 | 25463 | slower |
| nlohmann_json | 429 | 25463 | slower |
| rapidjson | 510 | 25463 | slower |
| arduinojson | 3472 | 25463 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 3.65 | 168 | fastest |
| nlohmann_json | 3.87 | 168 | slower |
| simdjson | 3.94 | 168 | slower |
| rapidjson | 5.12 | 168 | slower |
| arduinojson | 5.30 | 162 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 236 | 16546 | fastest |
| nlohmann_json | 242 | 16546 | slower |
| yyjson | 245 | 16546 | slower |
| rapidjson | 329 | 16543 | slower |
| arduinojson | 510 | 15916 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 6.81 | 411 | fastest |
| yyjson | 7.28 | 411 | close |
| nlohmann_json | 7.51 | 411 | slower |
| rapidjson | 10.2 | 411 | slower |
| arduinojson | 12.1 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| simdjson | 484 | 41431 | fastest |
| nlohmann_json | 544 | 41431 | slower |
| yyjson | 571 | 41431 | slower |
| rapidjson | 692 | 41431 | slower |
| arduinojson | 10857 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nlohmann_json | 11.3 | 658 | fastest |
| arduinojson | 12.1 | 455 | slower |
| yyjson | 12.1 | 658 | slower |
| simdjson | 12.2 | 658 | slower |
| rapidjson | 15.2 | 658 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nlohmann_json | 904 | 65970 | fastest |
| simdjson | 959 | 65970 | slower |
| yyjson | 1016 | 65966 | slower |
| arduinojson | 1102 | 45907 | slower |
| rapidjson | 1282 | 65833 | slower |

### csharp

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 14.1 | 440 | fastest |
| NetJSON | 22.8 | 440 | slower |
| Utf8Json | 27.4 | 440 | slower |
| MS Bond Json | 38.1 | 440 | slower |
| Jil | 41.1 | 440 | slower |
| System.Text.Json | 68.3 | 588 | slower |
| ServiceStack Json | 76.4 | 440 | slower |
| Json.Net | 90.5 | 560 | slower |
| fastJson | 91.3 | 972 | slower |
| Json.Net (Helper) | 93.1 | 541 | slower |
| MS DataContract Json | 97.1 | 588 | slower |
| FsPicklerJson | 97.7 | 1024 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 171 | 44614 | fastest |
| Utf8Json | 210 | 44614 | slower |
| NetJSON | 340 | 44383 | slower |
| Jil | 422 | 44614 | slower |
| MS Bond Json | 433 | 44383 | slower |
| System.Text.Json | 489 | 59488 | slower |
| FsPicklerJson | 788 | 66872 | slower |
| ServiceStack Json | 797 | 44614 | slower |
| Json.Net | 1008 | 58628 | slower |
| Json.Net (Helper) | 1009 | 56520 | slower |
| fastJson | 1147 | 57174 | slower |
| MS DataContract Json | 1501 | 59488 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 8.04 | 254 | fastest |
| MS Bond Json | 10.8 | 254 | slower |
| NetJSON | 10.8 | 254 | slower |
| Utf8Json | 13.7 | 254 | slower |
| Json.Net (Helper) | 19.7 | 304 | slower |
| Json.Net | 19.9 | 329 | slower |
| System.Text.Json | 20.8 | 340 | slower |
| ServiceStack Json | 21.2 | 254 | slower |
| Jil | 21.6 | 254 | slower |
| fastJson | 24.7 | 585 | slower |
| MS DataContract Json | 33.8 | 340 | slower |
| FsPicklerJson | 39.2 | 772 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 113 | 25456 | fastest |
| Utf8Json | 153 | 25456 | slower |
| NetJSON | 176 | 25456 | slower |
| MS Bond Json | 221 | 25456 | slower |
| Jil | 291 | 25456 | slower |
| System.Text.Json | 297 | 33944 | slower |
| ServiceStack Json | 447 | 25456 | slower |
| FsPicklerJson | 484 | 41324 | slower |
| Json.Net (Helper) | 505 | 31360 | slower |
| Json.Net | 511 | 32971 | slower |
| fastJson | 554 | 31872 | slower |
| MS DataContract Json | 725 | 33944 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 8.42 | 157 | fastest |
| MS Bond Json | 10.3 | 142 | slower |
| NetJSON | 10.7 | 142 | slower |
| Jil | 13.6 | 157 | slower |
| Json.Net (Helper) | 14.1 | 167 | slower |
| Json.Net | 14.9 | 172 | slower |
| ServiceStack Json | 18.0 | 157 | slower |
| Utf8Json | 18.1 | 157 | slower |
| fastJson | 20.7 | 310 | slower |
| System.Text.Json | 27.4 | 212 | slower |
| MS DataContract Json | 30.2 | 212 | slower |
| FsPicklerJson | 33.1 | 576 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 95.3 | 15456 | fastest |
| NetJSON | 144 | 13961 | slower |
| MS Bond Json | 167 | 13961 | slower |
| System.Text.Json | 193 | 20608 | slower |
| Jil | 200 | 15456 | slower |
| ServiceStack Json | 276 | 15456 | slower |
| Json.Net (Helper) | 283 | 16560 | slower |
| Json.Net | 287 | 16971 | slower |
| FsPicklerJson | 289 | 21060 | slower |
| fastJson | 292 | 16944 | slower |
| Utf8Json | 295 | 15456 | slower |
| MS DataContract Json | 482 | 20608 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 6.44 | 410 | fastest |
| NetJSON | 8.27 | 410 | slower |
| MS Bond Json | 9.04 | 410 | slower |
| Utf8Json | 13.2 | 410 | slower |
| Json.Net | 13.5 | 425 | slower |
| Json.Net (Helper) | 14.1 | 420 | slower |
| ServiceStack Json | 14.3 | 410 | slower |
| System.Text.Json | 15.6 | 548 | slower |
| Jil | 15.9 | 410 | slower |
| fastJson | 17.9 | 563 | slower |
| MS DataContract Json | 28.4 | 548 | slower |
| FsPicklerJson | 34.1 | 960 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 209 | 41574 | fastest |
| NetJSON | 260 | 41574 | slower |
| Utf8Json | 289 | 41574 | slower |
| MS Bond Json | 317 | 41574 | slower |
| System.Text.Json | 395 | 55432 | slower |
| fastJson | 405 | 43062 | slower |
| Jil | 414 | 41574 | slower |
| Json.Net | 467 | 43089 | slower |
| Json.Net (Helper) | 467 | 42678 | slower |
| ServiceStack Json | 492 | 41574 | slower |
| FsPicklerJson | 565 | 60284 | slower |
| MS DataContract Json | 977 | 55432 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| NetJSON | 18.0 | 663 | fastest |
| MS Bond Json | 21.7 | 663 | slower |
| SpanJson | 24.0 | 663 | slower |
| Utf8Json | 27.1 | 663 | slower |
| Json.Net (Helper) | 27.2 | 673 | slower |
| Json.Net | 28.6 | 678 | slower |
| Jil | 31.4 | 663 | slower |
| System.Text.Json | 35.3 | 884 | slower |
| ServiceStack Json | 35.3 | 663 | slower |
| fastJson | 36.8 | 818 | slower |
| MS DataContract Json | 48.7 | 884 | slower |
| FsPicklerJson | 59.3 | 1340 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 718 | 65968 | fastest |
| Utf8Json | 809 | 65974 | slower |
| NetJSON | 847 | 65968 | slower |
| System.Text.Json | 851 | 87960 | slower |
| Jil | 1036 | 65968 | slower |
| MS Bond Json | 1110 | 65968 | slower |
| ServiceStack Json | 1169 | 65968 | slower |
| Json.Net | 1286 | 67483 | slower |
| fastJson | 1289 | 67460 | slower |
| Json.Net (Helper) | 1304 | 67072 | slower |
| FsPicklerJson | 1491 | 96944 | slower |
| MS DataContract Json | 1981 | 87960 | slower |

### swift

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 54.7 | 448 | fastest |
| Foundation.JSONEncoder | 56.7 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| Foundation.JSONEncoder | 3387 | 45404 | fastest |
| IkigaJSON | 3472 | 45404 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 30.7 | 257 | fastest |
| Foundation.JSONEncoder | 31.9 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| Foundation.JSONEncoder | 1450 | 25746 | fastest |
| IkigaJSON | 1574 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 19.7 | 168 | fastest |
| Foundation.JSONEncoder | 20.5 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| Foundation.JSONEncoder | 707 | 16546 | fastest |
| IkigaJSON | 794 | 16546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 33.1 | 411 | fastest |
| Foundation.JSONEncoder | 36.0 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 2218 | 41431 | fastest |
| Foundation.JSONEncoder | 2391 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 49.1 | 663 | fastest |
| Foundation.JSONEncoder | 52.8 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 3294 | 65958 | fastest |
| Foundation.JSONEncoder | 3439 | 65958 | slower |

### zig

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 2.38 | 448 | fastest |
| std.json.scanner | 3.40 | 448 | slower |
| std.json | 3.41 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 233 | 45707 | fastest |
| std.json.scanner | 332 | 45707 | slower |
| std.json | 332 | 45707 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 1.40 | 257 | fastest |
| std.json | 2.07 | 257 | slower |
| std.json.scanner | 2.08 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 134 | 26049 | fastest |
| std.json.scanner | 188 | 26049 | slower |
| std.json | 188 | 26049 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 1.02 | 168 | fastest |
| std.json.scanner | 1.22 | 168 | slower |
| std.json | 1.23 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 80.9 | 16849 | fastest |
| std.json.scanner | 95.2 | 16849 | slower |
| std.json | 95.4 | 16849 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 1.95 | 411 | fastest |
| std.json.scanner | 3.05 | 411 | slower |
| std.json | 3.14 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 217 | 41734 | fastest |
| std.json.scanner | 358 | 41734 | slower |
| std.json | 359 | 41734 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 2.90 | 663 | fastest |
| std.json | 3.81 | 663 | slower |
| std.json.scanner | 3.82 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde.json | 291 | 66261 | fastest |
| std.json.scanner | 364 | 66261 | slower |
| std.json | 364 | 66261 | slower |

## What we saw

On named JSON, some languages keep one first place; others flip.

- **Python:** `orjson` is first on every sample and at both 1 and 100 records. On Sample A it is about **5.3 times** faster than `json`. That ratio stays put if we keep every trial after warm-up, drop more stalls (IQR 3.0), or keep the first trial. Experiment 1 is a stable fact for named JSON in Python.
- **JavaScript, C, Rust, Swift (N = 1):** the Experiment 1 name stays first on every sample (`JSON.stringify`, `yyjson`, `sonic-rs`, `IkigaJSON`).
- **Go, Java, C++, C#:** the first place **depends on the sample**. Go moves among `goccy/go-json`, `segmentio/encoding/json`, and `sonic`. Java is `jsoniter` on A–C and `dsl-json` on D–E. C++ moves among `simdjson`, `yyjson`, and `nlohmann_json`. C# is `SpanJson` except `NetJSON` on the sensor list.
- **1 vs 100:** Python, JavaScript, and C keep the same name. Go, Swift, and some Java / Rust / C++ / C# cells flip. Quote the number of records that matches the product.

Never quote a rank without naming the sample and N. A close contest (Go on Sample A) is not the same kind of fact as `orjson` versus `json`.

## What this page is not

- It is not a ranking of languages.
- It is not three separate evenings on this machine.
- It is not shuffled-order vs fixed-order (the runner always shuffles blocks).
- It is not two versions of the same library.

