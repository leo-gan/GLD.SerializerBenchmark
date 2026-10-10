# Does the ranking stay the same if we change the data?

**Question:** Do the ranks stay the same if we change the record, how many we write at once, or how we set aside odd trials?
**Date:** 2026-10-10
**Sample:** `['document', 'message', 'telemetry', 'event', 'strings']`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | orjson | orjson | orjson | orjson | orjson | yes | [python/results.md](python/results.md) |
| go | goccy/go-json | goccy/go-json | sonic | goccy/go-json | sonic | no | [go/results.md](go/results.md) |
| java | jsoniter | jsoniter | jsoniter | dsl-json | dsl-json | no | [java/results.md](java/results.md) |
| kotlin | moshi-reflect | moshi-reflect | moshi-reflect | moshi-reflect | moshi-reflect | yes | [kotlin/results.md](kotlin/results.md) |
| php | json | json | json | json | json | yes | [php/results.md](php/results.md) |
| javascript | JSON.stringify | JSON.stringify | JSON.stringify | JSON.stringify | JSON.stringify | yes | [javascript/results.md](javascript/results.md) |
| rust | sonic-rs | sonic-rs | serde_json | sonic-rs | sonic-rs | no | [rust/results.md](rust/results.md) |
| c | yyjson | yyjson | yyjson | yyjson | yyjson | yes | [c/results.md](c/results.md) |
| cpp | yyjson | yyjson | yyjson | yyjson | yyjson | yes | [cpp/results.md](cpp/results.md) |
| csharp | SpanJson | SpanJson | NetJSON | SpanJson | SpanJson | no | [csharp/results.md](csharp/results.md) |
| swift | IkigaJSON | IkigaJSON | IkigaJSON | IkigaJSON | IkigaJSON | yes | [swift/results.md](swift/results.md) |
| zig | serde.json | serde.json | serde.json | serde.json | serde.json | yes | [zig/results.md](zig/results.md) |
| mojo | mojo-json | mojo-json | mojo-json | EmberJson | EmberJson | no | [mojo/results.md](mojo/results.md) |
| fortran | jonquil | jonquil | jonquil | json-fortran | json-fortran | no | [fortran/results.md](fortran/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | A (order) | orjson | orjson | yes |
| python | B (flat) | orjson | orjson | yes |
| python | C (sensor) | orjson | orjson | yes |
| python | D (event) | orjson | orjson | yes |
| python | E (words) | orjson | orjson | yes |
| go | A (order) | goccy/go-json | sonic | no |
| go | B (flat) | goccy/go-json | sonic | no |
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
| rust | C (sensor) | serde_json | serde_json | yes |
| rust | D (event) | sonic-rs | sonic-rs | yes |
| rust | E (words) | sonic-rs | sonic-rs | yes |
| c | A (order) | yyjson | yyjson | yes |
| c | B (flat) | yyjson | yyjson | yes |
| c | C (sensor) | yyjson | yyjson | yes |
| c | D (event) | yyjson | yyjson | yes |
| c | E (words) | yyjson | yyjson | yes |
| cpp | A (order) | yyjson | yyjson | yes |
| cpp | B (flat) | yyjson | yyjson | yes |
| cpp | C (sensor) | yyjson | yyjson | yes |
| cpp | D (event) | yyjson | yyjson | yes |
| cpp | E (words) | yyjson | yyjson | yes |
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
| mojo | A (order) | mojo-json | mojo-json | yes |
| mojo | B (flat) | mojo-json | mojo-json | yes |
| mojo | C (sensor) | mojo-json | mojo-json | yes |
| mojo | D (event) | EmberJson | EmberJson | yes |
| mojo | E (words) | EmberJson | EmberJson | yes |
| fortran | A (order) | jonquil | json-fortran | no |
| fortran | B (flat) | jonquil | json-fortran | no |
| fortran | C (sensor) | jonquil | json-fortran | no |
| fortran | D (event) | json-fortran | json-fortran | yes |
| fortran | E (words) | json-fortran | json-fortran | yes |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | `orjson` | — |
| go | ok | `goccy/go-json`, `segmentio/encoding/json` | — |
| java | ok | `jsoniter` | — |
| kotlin | ok | `moshi-reflect`, `moshi-codegen` | — |
| php | ok | `json` | — |
| javascript | ok | `JSON.stringify` | — |
| rust | ok | `sonic-rs` | — |
| c | ok | `yyjson` | — |
| cpp | ok | `yyjson` | — |
| csharp | ok | `SpanJson` | — |
| swift | ok | `IkigaJSON` | — |
| zig | ok | `serde.json` | — |
| mojo | ok | `mojo-json` | — |
| fortran | ok | `jonquil`, `json-fortran` | — |

## In memory, by language and sample

### python

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 7.33 | 448 | fastest |
| serpyco-rs | 15.9 | 448 | slower |
| mashumaro | 18.4 | 448 | slower |
| rapidjson | 22.9 | 448 | slower |
| json | 36.3 | 448 | slower |
| pydantic | 52.3 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 236 | 45404 | fastest |
| serpyco-rs | 481 | 45404 | slower |
| rapidjson | 554 | 45404 | slower |
| mashumaro | 645 | 45404 | slower |
| json | 704 | 45404 | slower |
| pydantic | 1089 | 45404 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 5.12 | 257 | fastest |
| serpyco-rs | 11.6 | 257 | slower |
| mashumaro | 11.9 | 257 | slower |
| rapidjson | 16.3 | 257 | slower |
| json | 27.4 | 257 | slower |
| pydantic | 29.7 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 155 | 25746 | fastest |
| serpyco-rs | 228 | 25746 | slower |
| rapidjson | 261 | 25746 | slower |
| mashumaro | 286 | 25746 | slower |
| json | 365 | 25746 | slower |
| pydantic | 547 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 3.00 | 168 | fastest |
| mashumaro | 6.95 | 168 | slower |
| serpyco-rs | 7.73 | 168 | slower |
| rapidjson | 10.7 | 168 | slower |
| pydantic | 17.4 | 168 | slower |
| json | 19.4 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 73.0 | 16546 | fastest |
| serpyco-rs | 120 | 16546 | slower |
| mashumaro | 139 | 16546 | slower |
| rapidjson | 222 | 16546 | slower |
| pydantic | 238 | 16546 | slower |
| json | 259 | 16546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 4.46 | 410 | fastest |
| mashumaro | 6.92 | 410 | slower |
| serpyco-rs | 7.87 | 410 | slower |
| rapidjson | 10.6 | 410 | slower |
| pydantic | 19.9 | 410 | slower |
| json | 20.2 | 410 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 206 | 41564 | fastest |
| serpyco-rs | 243 | 41564 | slower |
| mashumaro | 275 | 41564 | slower |
| rapidjson | 295 | 41564 | slower |
| json | 405 | 41564 | slower |
| pydantic | 494 | 41564 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 5.21 | 663 | fastest |
| mashumaro | 8.90 | 663 | slower |
| serpyco-rs | 9.20 | 663 | slower |
| pydantic | 19.6 | 663 | slower |
| rapidjson | 30.8 | 663 | slower |
| json | 38.9 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 211 | 65958 | fastest |
| serpyco-rs | 269 | 65958 | slower |
| mashumaro | 314 | 65958 | slower |
| pydantic | 488 | 65958 | slower |
| json | 1683 | 65958 | slower |
| rapidjson | 1798 | 65958 | slower |

### go

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 3.85 | 448 | fastest |
| segmentio/encoding/json | 4.01 | 448 | similar |
| sonic | 5.24 | 448 | slower |
| jsoniter | 5.33 | 448 | slower |
| ugorji/json | 6.61 | 448 | slower |
| encoding/json | 10.9 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 157 | 45404 | fastest |
| segmentio/encoding/json | 172 | 45404 | slower |
| goccy/go-json | 173 | 45404 | slower |
| jsoniter | 238 | 45404 | slower |
| ugorji/json | 251 | 45404 | slower |
| encoding/json | 625 | 45404 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 2.42 | 257 | fastest |
| segmentio/encoding/json | 2.80 | 257 | close |
| sonic | 3.03 | 257 | close |
| jsoniter | 3.07 | 257 | slower |
| ugorji/json | 4.09 | 257 | slower |
| encoding/json | 6.13 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 100 | 25746 | fastest |
| goccy/go-json | 104 | 25746 | similar |
| segmentio/encoding/json | 119 | 25746 | slower |
| jsoniter | 136 | 25746 | slower |
| ugorji/json | 154 | 25746 | slower |
| encoding/json | 335 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 1.68 | 168 | fastest |
| sonic | 1.69 | 168 | similar |
| segmentio/encoding/json | 1.75 | 168 | similar |
| jsoniter | 2.32 | 168 | slower |
| ugorji/json | 2.60 | 168 | slower |
| encoding/json | 3.52 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 46.4 | 16546 | fastest |
| goccy/go-json | 60.9 | 16546 | slower |
| segmentio/encoding/json | 62.8 | 16546 | slower |
| ugorji/json | 93.1 | 16546 | slower |
| jsoniter | 94.5 | 16546 | slower |
| encoding/json | 189 | 16546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 1.85 | 411 | fastest |
| goccy/go-json | 2.50 | 411 | slower |
| segmentio/encoding/json | 2.85 | 411 | slower |
| jsoniter | 2.96 | 411 | slower |
| ugorji/json | 3.31 | 411 | slower |
| encoding/json | 6.62 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 144 | 41431 | fastest |
| ugorji/json | 219 | 41431 | slower |
| goccy/go-json | 222 | 41431 | slower |
| jsoniter | 238 | 41431 | slower |
| segmentio/encoding/json | 240 | 41431 | slower |
| encoding/json | 564 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 4.61 | 663 | fastest |
| goccy/go-json | 7.40 | 663 | slower |
| segmentio/encoding/json | 7.62 | 663 | slower |
| ugorji/json | 9.67 | 663 | slower |
| jsoniter | 10.6 | 663 | slower |
| encoding/json | 12.5 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic | 276 | 65958 | fastest |
| goccy/go-json | 553 | 65958 | slower |
| segmentio/encoding/json | 561 | 65958 | slower |
| ugorji/json | 629 | 65958 | slower |
| jsoniter | 769 | 65958 | slower |
| encoding/json | 914 | 65958 | slower |

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
| JSON.stringify | 10.5 | 448 | fastest |
| fast-json-stringify | 15.2 | 448 | slower |
| simdjson-parse+JSON.stringify | 31.4 | 448 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 377 | 45404 | fastest |
| fast-json-stringify | 503 | 45404 | slower |
| simdjson-parse+JSON.stringify | 724 | 45404 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 4.92 | 257 | fastest |
| fast-json-stringify | 7.14 | 257 | slower |
| simdjson-parse+JSON.stringify | 14.7 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 265 | 25746 | fastest |
| fast-json-stringify | 323 | 25746 | slower |
| simdjson-parse+JSON.stringify | 426 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 4.42 | 168 | fastest |
| fast-json-stringify | 6.01 | 168 | slower |
| simdjson-parse+JSON.stringify | 13.7 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 96.8 | 16546 | fastest |
| fast-json-stringify | 129 | 16546 | slower |
| simdjson-parse+JSON.stringify | 220 | 16546 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 4.30 | 411 | fastest |
| fast-json-stringify | 7.69 | 411 | slower |
| simdjson-parse+JSON.stringify | 14.1 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 447 | 41431 | fastest |
| fast-json-stringify | 538 | 41431 | slower |
| simdjson-parse+JSON.stringify | 585 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 8.60 | 663 | fastest |
| fast-json-stringify | 8.79 | 663 | similar |
| simdjson-parse+JSON.stringify | 26.3 | 663 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 546 | 65958 | fastest |
| fast-json-stringify | 554 | 65958 | similar |
| simdjson-parse+JSON.stringify | 840 | 65958 | slower |

### rust

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 2.63 | 460 | fastest |
| serde_json | 3.18 | 460 | slower |
| simd-json | 3.67 | 460 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 136 | 47101 | fastest |
| serde_json | 195 | 47101 | slower |
| simd-json | 214 | 47101 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 1.66 | 258 | fastest |
| serde_json | 2.00 | 258 | slower |
| simd-json | 2.29 | 258 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 88.6 | 26978 | fastest |
| serde_json | 136 | 26978 | slower |
| simd-json | 165 | 26978 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 1.02 | 182 | fastest |
| serde_json | 1.18 | 182 | slower |
| simd-json | 1.64 | 182 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 44.4 | 18070 | fastest |
| serde_json | 66.2 | 18070 | slower |
| simd-json | 89.4 | 18070 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 2.18 | 390 | fastest |
| serde_json | 2.80 | 390 | slower |
| simd-json | 2.99 | 390 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 156 | 42750 | fastest |
| simd-json | 226 | 42750 | slower |
| serde_json | 259 | 42750 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde_json | 2.65 | 672 | fastest |
| sonic-rs | 2.73 | 672 | close |
| simd-json | 3.27 | 672 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde_json | 203 | 67763 | fastest |
| sonic-rs | 225 | 67763 | slower |
| simd-json | 228 | 67763 | slower |

### c

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 5.79 | 460 | fastest |
| cJSON | 13.8 | 460 | slower |
| json-c | 19.2 | 460 | slower |
| jansson | 22.2 | 460 | slower |
| parson | 26.4 | 460 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 340 | 45951 | fastest |
| cJSON | 818 | 45951 | slower |
| json-c | 1330 | 45951 | slower |
| jansson | 1577 | 45951 | slower |
| parson | 1811 | 45951 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 3.93 | 264 | fastest |
| cJSON | 7.98 | 264 | slower |
| json-c | 11.8 | 264 | slower |
| parson | 12.5 | 264 | slower |
| jansson | 13.0 | 264 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 243 | 25937 | fastest |
| cJSON | 487 | 25937 | slower |
| json-c | 708 | 25937 | slower |
| parson | 724 | 25937 | slower |
| jansson | 897 | 25937 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 2.22 | 171 | fastest |
| cJSON | 5.29 | 172 | slower |
| jansson | 7.29 | 171 | slower |
| json-c | 7.32 | 172 | slower |
| parson | 7.86 | 172 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 128 | 16878 | fastest |
| cJSON | 336 | 16910 | slower |
| json-c | 423 | 16962 | slower |
| jansson | 502 | 16878 | slower |
| parson | 565 | 16962 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 4.04 | 391 | fastest |
| cJSON | 9.26 | 391 | slower |
| parson | 10.6 | 391 | slower |
| json-c | 11.7 | 391 | slower |
| jansson | 14.6 | 391 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 355 | 41352 | fastest |
| cJSON | 700 | 41352 | slower |
| parson | 797 | 41352 | slower |
| json-c | 847 | 41352 | slower |
| jansson | 1211 | 41352 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 4.31 | 657 | fastest |
| jansson | 24.7 | 657 | slower |
| json-c | 28.2 | 688 | slower |
| cJSON | 35.5 | 666 | slower |
| parson | 42.5 | 688 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 297 | 66315 | fastest |
| jansson | 1928 | 66315 | slower |
| json-c | 2193 | 68605 | slower |
| cJSON | 3116 | 66887 | slower |
| parson | 3908 | 68605 | slower |

### cpp

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 15.1 | 458 | fastest |
| simdjson | 17.3 | 458 | slower |
| rapidjson | 18.4 | 458 | slower |
| nlohmann_json | 21.7 | 458 | slower |
| arduinojson | 25.2 | 458 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 629 | 45507 | fastest |
| simdjson | 875 | 45507 | slower |
| rapidjson | 908 | 45507 | slower |
| nlohmann_json | 1123 | 45507 | slower |
| arduinojson | 9083 | 45507 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 7.46 | 272 | fastest |
| simdjson | 9.86 | 272 | slower |
| rapidjson | 11.0 | 272 | slower |
| nlohmann_json | 12.4 | 272 | slower |
| arduinojson | 14.3 | 272 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 349 | 25463 | fastest |
| simdjson | 455 | 25463 | slower |
| rapidjson | 487 | 25463 | slower |
| nlohmann_json | 633 | 25463 | slower |
| arduinojson | 5089 | 25463 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 4.03 | 168 | fastest |
| simdjson | 5.38 | 168 | slower |
| rapidjson | 5.48 | 168 | slower |
| nlohmann_json | 7.83 | 168 | slower |
| arduinojson | 8.34 | 162 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 182 | 16546 | fastest |
| simdjson | 253 | 16546 | slower |
| rapidjson | 264 | 16543 | slower |
| nlohmann_json | 390 | 16546 | slower |
| arduinojson | 597 | 15916 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 7.12 | 411 | fastest |
| simdjson | 9.50 | 411 | slower |
| rapidjson | 10.1 | 411 | slower |
| nlohmann_json | 11.6 | 411 | slower |
| arduinojson | 14.6 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 568 | 41431 | fastest |
| simdjson | 669 | 41431 | slower |
| rapidjson | 732 | 41431 | slower |
| nlohmann_json | 973 | 41431 | slower |
| arduinojson | 19011 | 41431 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 9.25 | 658 | fastest |
| simdjson | 12.4 | 658 | slower |
| arduinojson | 13.2 | 455 | slower |
| rapidjson | 13.4 | 658 | slower |
| nlohmann_json | 20.2 | 658 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 467 | 65966 | fastest |
| simdjson | 674 | 65970 | slower |
| rapidjson | 701 | 65833 | slower |
| arduinojson | 1010 | 45907 | slower |
| nlohmann_json | 1347 | 65970 | slower |

### csharp

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 15.9 | 440 | fastest |
| NetJSON | 24.3 | 440 | slower |
| Utf8Json | 29.0 | 440 | slower |
| MS Bond Json | 41.0 | 440 | slower |
| Jil | 51.7 | 440 | slower |
| System.Text.Json | 71.1 | 440 | slower |
| ServiceStack Json | 79.4 | 440 | slower |
| fastJson | 93.5 | 972 | slower |
| Json.Net (Helper) | 99.1 | 541 | slower |
| Json.Net | 99.5 | 560 | slower |
| FsPicklerJson | 101 | 768 | slower |
| MS DataContract Json | 104 | 440 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 194 | 44614 | fastest |
| Utf8Json | 241 | 44614 | slower |
| NetJSON | 370 | 44383 | slower |
| MS Bond Json | 463 | 44383 | slower |
| Jil | 480 | 44614 | slower |
| System.Text.Json | 489 | 44614 | slower |
| FsPicklerJson | 799 | 50153 | slower |
| ServiceStack Json | 838 | 44614 | slower |
| Json.Net | 999 | 58628 | slower |
| Json.Net (Helper) | 1028 | 56520 | slower |
| fastJson | 1218 | 57174 | slower |
| MS DataContract Json | 1494 | 44614 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 8.27 | 254 | fastest |
| NetJSON | 10.5 | 254 | slower |
| MS Bond Json | 13.2 | 254 | slower |
| Utf8Json | 14.6 | 254 | slower |
| Json.Net (Helper) | 21.9 | 304 | slower |
| System.Text.Json | 22.2 | 254 | slower |
| ServiceStack Json | 22.4 | 254 | slower |
| Jil | 23.5 | 254 | slower |
| Json.Net | 24.3 | 329 | slower |
| fastJson | 26.2 | 585 | slower |
| MS DataContract Json | 34.6 | 254 | slower |
| FsPicklerJson | 42.9 | 579 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 117 | 25456 | fastest |
| Utf8Json | 157 | 25456 | slower |
| NetJSON | 186 | 25456 | slower |
| MS Bond Json | 235 | 25456 | slower |
| System.Text.Json | 260 | 25456 | slower |
| Jil | 307 | 25456 | slower |
| ServiceStack Json | 462 | 25456 | slower |
| FsPicklerJson | 463 | 30992 | slower |
| Json.Net (Helper) | 526 | 31360 | slower |
| Json.Net | 533 | 32971 | slower |
| fastJson | 565 | 31872 | slower |
| MS DataContract Json | 666 | 25456 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 9.93 | 157 | fastest |
| NetJSON | 10.9 | 142 | close |
| MS Bond Json | 10.9 | 142 | slower |
| Jil | 13.5 | 157 | slower |
| Json.Net | 16.8 | 172 | slower |
| Json.Net (Helper) | 16.9 | 167 | slower |
| Utf8Json | 18.7 | 157 | slower |
| ServiceStack Json | 18.9 | 157 | slower |
| fastJson | 23.3 | 310 | slower |
| System.Text.Json | 29.9 | 157 | slower |
| MS DataContract Json | 37.0 | 157 | slower |
| FsPicklerJson | 40.1 | 432 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 93.0 | 15456 | fastest |
| NetJSON | 135 | 13961 | slower |
| MS Bond Json | 161 | 13961 | slower |
| System.Text.Json | 162 | 15456 | slower |
| Jil | 188 | 15456 | slower |
| ServiceStack Json | 257 | 15456 | slower |
| FsPicklerJson | 258 | 15794 | slower |
| Json.Net | 267 | 16971 | slower |
| Utf8Json | 268 | 15456 | slower |
| Json.Net (Helper) | 275 | 16560 | slower |
| fastJson | 280 | 16944 | slower |
| MS DataContract Json | 441 | 15456 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 5.67 | 410 | fastest |
| NetJSON | 8.05 | 410 | slower |
| MS Bond Json | 9.56 | 410 | slower |
| Utf8Json | 12.2 | 410 | slower |
| ServiceStack Json | 13.2 | 410 | slower |
| Json.Net | 13.9 | 425 | slower |
| Json.Net (Helper) | 14.8 | 420 | slower |
| System.Text.Json | 15.9 | 410 | slower |
| Jil | 16.7 | 410 | slower |
| fastJson | 18.6 | 563 | slower |
| MS DataContract Json | 28.0 | 410 | slower |
| FsPicklerJson | 34.3 | 718 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 211 | 41574 | fastest |
| NetJSON | 264 | 41574 | slower |
| Utf8Json | 287 | 41574 | slower |
| MS Bond Json | 315 | 41574 | slower |
| System.Text.Json | 329 | 41574 | slower |
| Jil | 404 | 41574 | slower |
| fastJson | 409 | 43062 | slower |
| Json.Net | 460 | 43089 | slower |
| Json.Net (Helper) | 462 | 42678 | slower |
| ServiceStack Json | 495 | 41574 | slower |
| FsPicklerJson | 510 | 45212 | slower |
| MS DataContract Json | 912 | 41574 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| NetJSON | 17.6 | 663 | fastest |
| MS Bond Json | 21.9 | 663 | slower |
| SpanJson | 23.1 | 663 | slower |
| Utf8Json | 26.8 | 663 | slower |
| Json.Net | 28.6 | 678 | slower |
| Json.Net (Helper) | 29.4 | 673 | slower |
| Jil | 32.3 | 663 | slower |
| System.Text.Json | 34.7 | 663 | slower |
| fastJson | 36.3 | 818 | slower |
| ServiceStack Json | 37.2 | 663 | slower |
| MS DataContract Json | 45.5 | 663 | slower |
| FsPicklerJson | 59.5 | 1004 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 781 | 65968 | fastest |
| System.Text.Json | 811 | 65968 | similar |
| Utf8Json | 846 | 65974 | slower |
| NetJSON | 862 | 65968 | slower |
| Jil | 1118 | 65968 | slower |
| MS Bond Json | 1188 | 65968 | slower |
| ServiceStack Json | 1240 | 65968 | slower |
| fastJson | 1356 | 67460 | slower |
| Json.Net | 1356 | 67483 | slower |
| Json.Net (Helper) | 1378 | 67072 | slower |
| FsPicklerJson | 1507 | 72708 | slower |
| MS DataContract Json | 1935 | 65968 | slower |

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

### mojo

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 1.70 | 452 | fastest |
| EmberJson | 2.14 | 452 | slower |
| ehsanmok-json | 7.65 | 452 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 170 | 47144 | fastest |
| EmberJson | 196 | 47144 | slower |
| ehsanmok-json | 714 | 47144 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| EmberJson | 1.55 | 290 | fastest |
| mojo-json | 1.59 | 290 | close |
| ehsanmok-json | 5.24 | 290 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| EmberJson | 131 | 27675 | fastest |
| mojo-json | 140 | 27675 | slower |
| ehsanmok-json | 437 | 27675 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 0.66 | 164 | fastest |
| EmberJson | 0.87 | 168 | slower |
| ehsanmok-json | 4.03 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 48.7 | 16114 | fastest |
| EmberJson | 63.0 | 16556 | slower |
| ehsanmok-json | 347 | 16556 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| EmberJson | 1.97 | 411 | fastest |
| mojo-json | 3.10 | 411 | slower |
| ehsanmok-json | 6.20 | 411 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| EmberJson | 212 | 41441 | fastest |
| mojo-json | 314 | 41441 | slower |
| ehsanmok-json | 577 | 41441 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 2.73 | 491 | fastest |
| EmberJson | 3.66 | 668 | slower |
| ehsanmok-json | 12.6 | 668 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| mojo-json | 274 | 49656 | fastest |
| EmberJson | 403 | 66898 | slower |
| ehsanmok-json | 1289 | 66902 | slower |

### fortran

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jonquil | 86.5 | 505 | fastest |
| json-fortran | 89.5 | 473 | similar |
| rojff | 116 | 473 | slower |

**A (order), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 6609 | 46434 | fastest |
| rojff | 10642 | 46434 | slower |
| jonquil | 26629 | 49527 | slower |

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 40.8 | 258 | fastest |
| jonquil | 48.9 | 273 | slower |
| rojff | 64.5 | 260 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 2239 | 26647 | fastest |
| rojff | 4825 | 26847 | slower |
| jonquil | 8224 | 28040 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jonquil | 45.7 | 180 | fastest |
| json-fortran | 46.5 | 172 | similar |
| rojff | 50.8 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 1877 | 17806 | fastest |
| rojff | 2727 | 17406 | slower |
| jonquil | 3460 | 18509 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 44.8 | 430 | fastest |
| jonquil | 63.6 | 433 | slower |
| rojff | 64.2 | 430 | slower |

**E (words), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 2776 | 42110 | fastest |
| rojff | 6146 | 42110 | slower |
| jonquil | 14630 | 42303 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jonquil | 106 | 722 | fastest |
| json-fortran | 111 | 811 | slower |
| rojff | 209 | 685 | slower |

**C (sensor), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json-fortran | 10251 | 82130 | fastest |
| rojff | 19895 | 69558 | slower |
| jonquil | 27445 | 73072 | slower |

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

