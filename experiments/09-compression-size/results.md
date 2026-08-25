# Just turn compression on

**Question:** After gzip or zstd, does JSON stay larger than a dense binary format?
**Date:** 2026-08-17
**Sample:** `['strings', 'telemetry', 'message']`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. **Size after gzip** is the number this experiment asks for. Full tables with gzip columns live in each language folder.

## Size after gzip (bytes)

Named JSON versus Protocol Buffers (or that language’s dense binary stand-in). Same seed, same three samples.

| Language | E words JSON | E gzip | E protobuf | E pb gzip | C numbers JSON | C gzip | C protobuf | C pb gzip | B tiny JSON | B gzip | B protobuf | B pb gzip |
|----------|--------------|--------|------------|-----------|----------------|--------|------------|-----------|-------------|--------|------------|-----------|
| python | 410 | 270 | 367 | 266 | 2407 | 1317 | 1061 | 1080 | 168 | 138 | 50 | 71 |
| go | 411 | 291 | 368 | 278 | 2407 | 1227 | 1061 | 1084 | 168 | 142 | 50 | 75 |
| java | 411 | 281 | 368 | 278 | 2407 | 1317 | 1061 | 1080 | 158 | 141 | 50 | 71 |
| javascript | 411 | 286 | 368 | 275 | 2407 | 1221 | 1061 | 1076 | 168 | 137 | 50 | 71 |
| rust | 390 | 270 | 335 | 256 | 2420 | 1335 | 1054 | 1068 | 182 | 148 | 55 | 78 |
| c | 399 | 276 | 356 | 270 | 2409 | 1324 | 1181 | 1139 | 171 | 141 | 56 | 77 |
| cpp | 411 | 281 | 368 | 278 | 2400 | 1305 | 1180 | 1141 | 168 | 138 | 50 | 71 |
| csharp | 410 | 272 | 492 | 386 | 2407 | 1320 | 1416 | 1102 | 157 | 139 | 68 | 88 |
| swift | 411 | 281 | 368 | 278 | 2407 | 1317 | 1061 | 1080 | 168 | 138 | 50 | 71 |

Java `jsoniter` writes a smaller JSON on Sample C (1328 → 745 gzip) than `jackson` (2407 → 1317). The table uses named JSON that matches the other languages (`jackson` / `SpanJson` / `orjson`).

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | — | orjson | msgspec-msgpack | — | orjson | no | [python/results.md](python/results.md) |
| go | — | protobuf | protobuf | — | protobuf | no | [go/results.md](go/results.md) |
| java | — | protobuf | jsoniter | — | jsoniter | no | [java/results.md](java/results.md) |
| javascript | — | JSON.stringify | msgpackr | — | JSON.stringify | no | [javascript/results.md](javascript/results.md) |
| rust | — | prost | prost | — | rmp-serde | no | [rust/results.md](rust/results.md) |
| c | — | protobuf-wire | protobuf-wire | — | protobuf-wire | no | [c/results.md](c/results.md) |
| cpp | — | protobuf-wire | msgpack | — | protobuf-wire | no | [cpp/results.md](cpp/results.md) |
| csharp | — | SpanJson | Google.Protobuf | — | Google.Protobuf | no | [csharp/results.md](csharp/results.md) |
| swift | — | SwiftProtobuf | SwiftProtobuf | — | SwiftProtobuf | no | [swift/results.md](swift/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | B (flat) | orjson | — | no |
| python | C (sensor) | msgspec-msgpack | — | no |
| python | E (words) | orjson | — | no |
| go | B (flat) | protobuf | — | no |
| go | C (sensor) | protobuf | — | no |
| go | E (words) | protobuf | — | no |
| java | B (flat) | protobuf | — | no |
| java | C (sensor) | jsoniter | — | no |
| java | E (words) | jsoniter | — | no |
| javascript | B (flat) | JSON.stringify | — | no |
| javascript | C (sensor) | msgpackr | — | no |
| javascript | E (words) | JSON.stringify | — | no |
| rust | B (flat) | prost | — | no |
| rust | C (sensor) | prost | — | no |
| rust | E (words) | rmp-serde | — | no |
| c | B (flat) | protobuf-wire | — | no |
| c | C (sensor) | protobuf-wire | — | no |
| c | E (words) | protobuf-wire | — | no |
| cpp | B (flat) | protobuf-wire | — | no |
| cpp | C (sensor) | msgpack | — | no |
| cpp | E (words) | protobuf-wire | — | no |
| csharp | B (flat) | SpanJson | — | no |
| csharp | C (sensor) | Google.Protobuf | — | no |
| csharp | E (words) | Google.Protobuf | — | no |
| swift | B (flat) | SwiftProtobuf | — | no |
| swift | C (sensor) | SwiftProtobuf | — | no |
| swift | E (words) | SwiftProtobuf | — | no |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | — | — |
| go | ok | — | — |
| java | ok | — | — |
| javascript | ok | — | — |
| rust | ok | — | — |
| c | ok | — | — |
| cpp | ok | — | — |
| csharp | ok | — | — |
| swift | ok | — | — |

## In memory, by language and sample

### python

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 1.85 | 168 | fastest |
| msgspec-msgpack | 1.96 | 52 | close |
| protobuf | 3.35 | 50 | slower |
| json | 12.5 | 168 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 2.46 | 410 | fastest |
| msgspec-msgpack | 3.57 | 339 | slower |
| protobuf | 4.77 | 367 | slower |
| json | 15.3 | 410 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 5.77 | 1190 | fastest |
| protobuf | 7.07 | 1061 | close |
| orjson | 8.04 | 2407 | slower |
| json | 79.1 | 2407 | slower |

### go

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 1.17 | 50 | fastest |
| goccy/go-json | 1.39 | 168 | slower |
| vmihailenco/msgpack | 1.60 | 118 | slower |
| encoding/json | 3.14 | 168 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 2.25 | 368 | fastest |
| vmihailenco/msgpack | 2.25 | 346 | similar |
| goccy/go-json | 2.31 | 411 | similar |
| encoding/json | 6.02 | 411 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 2.21 | 1061 | fastest |
| vmihailenco/msgpack | 8.72 | 1212 | slower |
| goccy/go-json | 21.2 | 2407 | slower |
| encoding/json | 33.2 | 2407 | slower |

### java

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 13.0 | 50 | fastest |
| jsoniter | 15.6 | 150 | slower |
| jackson | 37.1 | 158 | slower |
| msgpack | 40.6 | 114 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 28.2 | 411 | fastest |
| protobuf | 28.3 | 368 | similar |
| jackson | 53.5 | 411 | slower |
| msgpack | 65.1 | 346 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 46.9 | 1328 | fastest |
| protobuf | 55.4 | 1061 | slower |
| msgpack | 76.1 | 1212 | slower |
| jackson | 103 | 2407 | slower |

### javascript

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 3.59 | 168 | fastest |
| msgpackr | 11.2 | 126 | slower |
| protobuf-es | 21.9 | 50 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 5.54 | 411 | fastest |
| msgpackr | 11.0 | 348 | slower |
| protobuf-es | 43.1 | 368 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpackr | 13.7 | 1214 | fastest |
| JSON.stringify | 20.9 | 2407 | slower |
| protobuf-es | 76.1 | 1061 | slower |

### rust

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 1.36 | 55 | fastest |
| rmp-serde | 2.70 | 136 | slower |
| serde_json | 3.06 | 182 | slower |
| sonic-rs | 4.36 | 182 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rmp-serde | 1.96 | 322 | fastest |
| sonic-rs | 1.98 | 390 | similar |
| serde_json | 2.64 | 390 | slower |
| prost | 3.20 | 335 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 1.26 | 1054 | fastest |
| rmp-serde | 1.26 | 1216 | similar |
| serde_json | 6.12 | 2420 | slower |
| sonic-rs | 7.22 | 2420 | slower |

### c

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.32 | 56 | fastest |
| mpack | 1.07 | 128 | slower |
| yyjson | 1.82 | 171 | slower |
| cJSON | 4.50 | 172 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.81 | 356 | fastest |
| mpack | 1.84 | 334 | slower |
| yyjson | 3.41 | 399 | slower |
| cJSON | 8.34 | 399 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.72 | 1181 | fastest |
| mpack | 2.74 | 1207 | slower |
| yyjson | 9.31 | 2409 | slower |
| cJSON | 125 | 2446 | slower |

### cpp

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.98 | 50 | fastest |
| msgpack | 1.79 | 124 | slower |
| nlohmann_json | 5.09 | 168 | slower |
| simdjson | 5.79 | 168 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 1.91 | 368 | fastest |
| msgpack | 2.17 | 346 | slower |
| nlohmann_json | 7.15 | 411 | slower |
| simdjson | 7.39 | 411 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpack | 3.67 | 1206 | fastest |
| protobuf-wire | 5.07 | 1180 | slower |
| nlohmann_json | 34.0 | 2400 | slower |
| simdjson | 37.8 | 2400 | slower |

### csharp

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 8.74 | 157 | fastest |
| Google.Protobuf | 10.6 | 68 | slower |
| System.Text.Json | 29.3 | 212 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| Google.Protobuf | 17.4 | 492 | fastest |
| SpanJson | 17.4 | 410 | similar |
| System.Text.Json | 44.3 | 548 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| Google.Protobuf | 22.9 | 1416 | fastest |
| System.Text.Json | 122 | 3212 | slower |
| SpanJson | 137 | 2407 | slower |

### swift

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 3.86 | 50 | fastest |
| IkigaJSON | 20.4 | 168 | slower |
| Foundation.JSONEncoder | 21.6 | 168 | slower |
| SwiftMsgpack | 26.3 | 124 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 5.40 | 368 | fastest |
| IkigaJSON | 32.0 | 411 | slower |
| Foundation.JSONEncoder | 36.2 | 411 | slower |
| SwiftMsgpack | 55.1 | 346 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 5.48 | 1061 | fastest |
| IkigaJSON | 126 | 2407 | slower |
| Foundation.JSONEncoder | 136 | 2407 | slower |
| SwiftMsgpack | 173 | 1212 | slower |

## What we saw

The story is the same in every language we ran.

- **Words (Sample E):** gzip pulls named JSON next to Protocol Buffers (about 270–290 vs 256–278 bytes). C# `Google.Protobuf` is larger on this sample (492 raw, 386 gzip) because that writer keeps more envelope; `SpanJson` gzip is 272.
- **Numbers (Sample C):** the format still matters. Named JSON stays about 1220–1335 after gzip; protobuf / wire stays about 1068–1141 (C# protobuf 1102). gzip does **not** erase the extra field names and decimal digits.
- **Tiny record (Sample B):** gzip **enlarges** protobuf (50–68 → 71–88) and only shaves a little off JSON (168 → 137–148). Do not compress chatty control calls.

Do not leave JSON *for size* on text-heavy bodies if HTTP already compresses. Do not treat write times in two languages as one contest.

## What this page is not

- It is not a ranking of languages.
- It is not how long gzip itself takes (we record compressed **size**, once).
- It is not a production capture that already went through HTTP compression.

