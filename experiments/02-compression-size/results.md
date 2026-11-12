# Does squeezing the bytes make JSON small enough?

**Question:** After gzip or zstd, does JSON stay larger than a dense binary format?
**Date:** 2026-11-12
**Sample:** `['strings', 'telemetry', 'message']`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | — | msgspec-msgpack | msgspec-msgpack | — | msgspec-msgpack | no | [python/results.md](python/results.md) |
| go | — | gld-kiln | gld-kiln | — | gld-kiln | no | [go/results.md](go/results.md) |
| java | — | gld-kiln | gld-kiln | — | jsoniter | no | [java/results.md](java/results.md) |
| kotlin | — | protobuf | protobuf | — | moshi-codegen | no | [kotlin/results.md](kotlin/results.md) |
| php | — | json | rybakit-msgpack | — | json | no | [php/results.md](php/results.md) |
| javascript | — | JSON.stringify | msgpackr | — | JSON.stringify | no | [javascript/results.md](javascript/results.md) |
| rust | — | gld-kiln | gld-kiln | — | gld-kiln | no | [rust/results.md](rust/results.md) |
| c | — | protobuf-wire | protobuf-wire | — | protobuf-wire | no | [c/results.md](c/results.md) |
| cpp | — | gld-kiln | gld-kiln | — | gld-kiln | no | [cpp/results.md](cpp/results.md) |
| csharp | — | gld-kiln | gld-kiln | — | gld-kiln | no | [csharp/results.md](csharp/results.md) |
| swift | — | SwiftProtobuf | SwiftProtobuf | — | SwiftProtobuf | no | [swift/results.md](swift/results.md) |
| zig | — | comptime-bin | comptime-bin | — | comptime-bin | no | [zig/results.md](zig/results.md) |
| mojo | — | gld-kiln | gld-kiln | — | gld-kiln | no | [mojo/results.md](mojo/results.md) |
| fortran | — | custom-binary | custom-binary | — | custom-binary | no | [fortran/results.md](fortran/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | B (flat) | msgspec-msgpack | — | no |
| python | C (sensor) | msgspec-msgpack | — | no |
| python | E (words) | msgspec-msgpack | — | no |
| go | B (flat) | gld-kiln | — | no |
| go | C (sensor) | gld-kiln | — | no |
| go | E (words) | gld-kiln | — | no |
| java | B (flat) | gld-kiln | — | no |
| java | C (sensor) | gld-kiln | — | no |
| java | E (words) | jsoniter | — | no |
| kotlin | B (flat) | protobuf | — | no |
| kotlin | C (sensor) | protobuf | — | no |
| kotlin | E (words) | moshi-codegen | — | no |
| php | B (flat) | json | — | no |
| php | C (sensor) | rybakit-msgpack | — | no |
| php | E (words) | json | — | no |
| javascript | B (flat) | JSON.stringify | — | no |
| javascript | C (sensor) | msgpackr | — | no |
| javascript | E (words) | JSON.stringify | — | no |
| rust | B (flat) | gld-kiln | — | no |
| rust | C (sensor) | gld-kiln | — | no |
| rust | E (words) | gld-kiln | — | no |
| c | B (flat) | protobuf-wire | — | no |
| c | C (sensor) | protobuf-wire | — | no |
| c | E (words) | protobuf-wire | — | no |
| cpp | B (flat) | gld-kiln | — | no |
| cpp | C (sensor) | gld-kiln | — | no |
| cpp | E (words) | gld-kiln | — | no |
| csharp | B (flat) | gld-kiln | — | no |
| csharp | C (sensor) | gld-kiln | — | no |
| csharp | E (words) | gld-kiln | — | no |
| swift | B (flat) | SwiftProtobuf | — | no |
| swift | C (sensor) | SwiftProtobuf | — | no |
| swift | E (words) | SwiftProtobuf | — | no |
| zig | B (flat) | comptime-bin | — | no |
| zig | C (sensor) | comptime-bin | — | no |
| zig | E (words) | comptime-bin | — | no |
| mojo | B (flat) | gld-kiln | — | no |
| mojo | C (sensor) | gld-kiln | — | no |
| mojo | E (words) | gld-kiln | — | no |
| fortran | B (flat) | custom-binary | — | no |
| fortran | C (sensor) | custom-binary | — | no |
| fortran | E (words) | custom-binary | — | no |

## One order (n=1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | — | — |
| go | ok | — | — |
| java | ok | — | — |
| kotlin | ok | — | — |
| php | ok | — | — |
| javascript | ok | — | — |
| rust | ok | — | — |
| c | ok | — | — |
| cpp | ok | — | — |
| csharp | ok | — | — |
| swift | ok | — | — |
| zig | ok | — | — |
| mojo | ok | — | — |
| fortran | ok | — | — |

## In memory, by language and sample

### python

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 2.69 | 52 | fastest |
| orjson | 3.68 | 168 | slower |
| protobuf | 5.32 | 50 | slower |
| json | 16.4 | 168 | slower |
| gld-kiln | 16.8 | 57 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 4.32 | 339 | fastest |
| orjson | 4.87 | 410 | similar |
| protobuf | 7.29 | 367 | slower |
| json | 19.8 | 410 | slower |
| gld-kiln | 44.7 | 435 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 8.92 | 1190 | fastest |
| orjson | 11.3 | 2407 | slower |
| protobuf | 12.3 | 1061 | slower |
| gld-kiln | 31.7 | 1073 | slower |
| json | 85.6 | 2407 | slower |

### go

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.22 | 57 | fastest |
| protobuf | 1.90 | 50 | slower |
| goccy/go-json | 2.46 | 168 | slower |
| vmihailenco/msgpack | 2.93 | 128 | slower |
| encoding/json | 3.50 | 168 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 2.63 | 436 | fastest |
| goccy/go-json | 3.07 | 411 | slower |
| vmihailenco/msgpack | 3.47 | 346 | slower |
| protobuf | 3.54 | 368 | slower |
| encoding/json | 5.20 | 411 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 2.25 | 1073 | fastest |
| protobuf | 2.86 | 1061 | slower |
| vmihailenco/msgpack | 9.78 | 1212 | slower |
| goccy/go-json | 20.5 | 2407 | slower |
| encoding/json | 25.6 | 2407 | slower |

### java

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 27.8 | 57 | fastest |
| jsoniter | 28.1 | 150 | similar |
| protobuf | 35.9 | 50 | close |
| msgpack | 53.1 | 114 | slower |
| jackson | 54.7 | 158 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 39.9 | 411 | fastest |
| gld-kiln | 52.9 | 436 | slower |
| jackson | 67.4 | 411 | slower |
| msgpack | 84.3 | 346 | slower |
| protobuf | 89.9 | 368 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 46.5 | 1073 | fastest |
| jsoniter | 65.9 | 1328 | slower |
| protobuf | 98.9 | 1061 | slower |
| msgpack | 106 | 1212 | slower |
| jackson | 172 | 2407 | slower |

### kotlin

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 23.3 | 50 | fastest |
| moshi-codegen | 23.3 | 158 | close |
| jackson | 81.8 | 158 | slower |
| msgpack | 85.9 | 114 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 41.4 | 411 | fastest |
| protobuf | 46.8 | 368 | close |
| jackson | 108 | 411 | slower |
| msgpack | 129 | 346 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 75.4 | 1061 | fastest |
| moshi-codegen | 109 | 2407 | slower |
| msgpack | 166 | 1212 | slower |
| jackson | 242 | 2407 | slower |

### php

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.40 | 168 | fastest |
| rybakit-msgpack | 9.24 | 126 | slower |
| protobuf | 51.2 | 54 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| json | 3.61 | 326 | fastest |
| rybakit-msgpack | 12.8 | 261 | slower |
| protobuf | 117 | 283 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rybakit-msgpack | 49.3 | 1203 | fastest |
| json | 82.8 | 2406 | slower |
| protobuf | 272 | 1052 | slower |

### javascript

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 5.33 | 168 | fastest |
| msgpackr | 13.8 | 126 | slower |
| gld-kiln | 14.0 | 57 | slower |
| protobuf-es | 16.7 | 50 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 7.45 | 411 | fastest |
| msgpackr | 14.4 | 348 | slower |
| protobuf-es | 24.2 | 368 | slower |
| gld-kiln | 30.2 | 436 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpackr | 18.0 | 1214 | fastest |
| gld-kiln | 21.9 | 1073 | close |
| JSON.stringify | 23.6 | 2407 | slower |
| protobuf-es | 33.8 | 1061 | slower |

### rust

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 0.24 | 60 | fastest |
| prost | 0.47 | 55 | slower |
| rmp-serde | 1.05 | 136 | slower |
| sonic-rs | 1.28 | 182 | slower |
| serde_json | 1.51 | 182 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.05 | 403 | fastest |
| rmp-serde | 2.25 | 322 | slower |
| sonic-rs | 2.42 | 390 | slower |
| prost | 2.45 | 335 | slower |
| serde_json | 3.16 | 390 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 0.56 | 1066 | fastest |
| prost | 1.35 | 1054 | slower |
| rmp-serde | 1.67 | 1216 | slower |
| serde_json | 6.72 | 2420 | slower |
| sonic-rs | 7.65 | 2420 | slower |

### c

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.51 | 56 | fastest |
| gld-kiln | 0.98 | 61 | slower |
| mpack | 1.50 | 128 | slower |
| yyjson | 2.44 | 171 | slower |
| cJSON | 5.95 | 172 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.91 | 356 | fastest |
| gld-kiln | 2.00 | 424 | slower |
| mpack | 2.15 | 334 | slower |
| yyjson | 4.04 | 399 | slower |
| cJSON | 9.34 | 399 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.92 | 1181 | fastest |
| gld-kiln | 1.60 | 1068 | slower |
| mpack | 3.30 | 1207 | slower |
| yyjson | 11.2 | 2409 | slower |
| cJSON | 141 | 2446 | slower |

### cpp

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 0.68 | 57 | fastest |
| protobuf-wire | 1.15 | 50 | slower |
| msgpack | 2.38 | 124 | slower |
| simdjson | 4.92 | 168 | slower |
| nlohmann_json | 6.49 | 168 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.79 | 435 | fastest |
| protobuf-wire | 2.08 | 367 | slower |
| msgpack | 2.40 | 345 | slower |
| simdjson | 6.74 | 410 | slower |
| nlohmann_json | 8.30 | 410 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.44 | 1067 | fastest |
| msgpack | 5.42 | 1206 | slower |
| protobuf-wire | 6.02 | 1180 | slower |
| simdjson | 21.1 | 2400 | slower |
| nlohmann_json | 41.2 | 2400 | slower |

### csharp

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 9.50 | 57 | fastest |
| Google.Protobuf | 12.5 | 50 | slower |
| SpanJson | 12.8 | 157 | slower |
| System.Text.Json | 35.3 | 157 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 15.6 | 435 | fastest |
| Google.Protobuf | 19.2 | 367 | slower |
| SpanJson | 24.3 | 410 | slower |
| System.Text.Json | 55.7 | 410 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 11.4 | 1073 | fastest |
| Google.Protobuf | 18.6 | 1061 | slower |
| SpanJson | 101 | 2407 | slower |
| System.Text.Json | 115 | 2407 | slower |

### swift

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 4.56 | 50 | fastest |
| gld-kiln | 7.13 | 57 | slower |
| IkigaJSON | 20.9 | 168 | slower |
| Foundation.JSONEncoder | 22.1 | 168 | slower |
| SwiftMsgpack | 28.1 | 124 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 5.85 | 368 | fastest |
| gld-kiln | 9.51 | 436 | slower |
| IkigaJSON | 32.8 | 411 | slower |
| Foundation.JSONEncoder | 37.4 | 411 | slower |
| SwiftMsgpack | 55.8 | 346 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 10.8 | 1061 | fastest |
| gld-kiln | 13.1 | 1073 | close |
| IkigaJSON | 136 | 2407 | slower |
| Foundation.JSONEncoder | 149 | 2407 | slower |
| SwiftMsgpack | 187 | 1212 | slower |

### zig

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.19 | 57 | fastest |
| flatbuffers | 0.38 | 108 | slower |
| protobuf | 0.42 | 50 | slower |
| serde.msgpack | 0.48 | 124 | slower |
| std.json | 1.15 | 168 | slower |
| gld-kiln | 3.53 | 57 | slower |
| capnproto | 4.09 | 96 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.73 | 436 | fastest |
| serde.msgpack | 0.86 | 346 | slower |
| flatbuffers | 0.91 | 660 | slower |
| protobuf | 1.31 | 368 | slower |
| std.json | 2.83 | 411 | slower |
| gld-kiln | 7.55 | 436 | slower |
| capnproto | 15.8 | 736 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| comptime-bin | 0.61 | 1073 | fastest |
| flatbuffers | 0.94 | 1124 | slower |
| serde.msgpack | 1.44 | 1212 | slower |
| protobuf | 2.47 | 1061 | slower |
| gld-kiln | 7.03 | 1073 | slower |
| capnproto | 10.1 | 1120 | slower |
| std.json | 12.2 | 2407 | slower |

### mojo

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.05 | 57 | fastest |
| mojo-avro | 1.20 | 44 | close |
| mojo-protobuf | 1.36 | 50 | close |
| mojo-json | 2.15 | 164 | slower |
| mojo-flatbuffers | 2.50 | 104 | slower |
| mojo-cbor | 2.66 | 124 | slower |
| EmberJson | 4.90 | 168 | slower |
| ehsanmok-json | 6.46 | 168 | slower |
| mojo-toml | 20.5 | 167 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 2.14 | 436 | fastest |
| mojo-json | 4.45 | 411 | slower |
| mojo-protobuf | 4.53 | 368 | slower |
| mojo-cbor | 4.80 | 345 | slower |
| mojo-avro | 5.83 | 338 | slower |
| EmberJson | 5.95 | 411 | slower |
| mojo-flatbuffers | 7.28 | 660 | slower |
| ehsanmok-json | 9.52 | 411 | slower |
| mojo-toml | 43.8 | 441 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| gld-kiln | 1.90 | 1073 | fastest |
| mojo-protobuf | 3.96 | 1061 | slower |
| mojo-avro | 4.06 | 1059 | slower |
| mojo-flatbuffers | 5.39 | 1128 | slower |
| mojo-cbor | 6.96 | 1211 | slower |
| mojo-json | 11.7 | 1716 | slower |
| EmberJson | 16.6 | 2407 | slower |
| ehsanmok-json | 41.7 | 2407 | slower |
| mojo-toml | 210 | 2534 | slower |

### fortran

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 1.04 | 44 | fastest |
| toml-f | 21.2 | 169 | slower |
| json-fortran | 26.8 | 172 | slower |
| fortran-messagepack | 30.0 | 120 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 1.83 | 383 | fastest |
| json-fortran | 30.8 | 430 | slower |
| fortran-messagepack | 45.3 | 362 | slower |
| toml-f | 49.9 | 462 | slower |

**C (sensor), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| custom-binary | 2.09 | 1059 | fastest |
| fortran-messagepack | 67.2 | 1209 | slower |
| toml-f | 313 | 2758 | slower |
| json-fortran | 324 | 3008 | slower |

## What we saw

On named JSON, some languages keep one first place; others flip.

- **Python:** `orjson` is first on every sample and at both 1 and 100 records. On Sample A it is about **5.3 times** faster than `json`. That ratio stays put if we keep every trial after warm-up, drop more stalls (IQR 3.0), or keep the first trial. That gap is a stable fact for named JSON in Python.
- **JavaScript, C, Rust, Swift (N = 1):** the fast named-JSON library stays first on every sample (`JSON.stringify`, `yyjson`, `sonic-rs`, `IkigaJSON`).
- **Go, Java, C++, C#:** the first place **depends on the sample**. Go moves among `goccy/go-json`, `segmentio/encoding/json`, and `sonic`. Java is `jsoniter` on A–C and `dsl-json` on D–E. C++ moves among `simdjson`, `yyjson`, and `nlohmann_json`. C# is `SpanJson` except `NetJSON` on the sensor list.
- **1 vs 100:** Python, JavaScript, and C keep the same name. Go, Swift, and some Java / Rust / C++ / C# cells flip. Quote the number of records that matches the product.

Never quote a rank without naming the sample and N. A close contest (Go on Sample A) is not the same kind of fact as `orjson` versus `json`.

## What this page is not

- It is not a ranking of languages.
- It is not three separate evenings on this machine.
- It is not shuffled-order vs fixed-order (the runner always shuffles blocks).
- It is not two versions of the same library.

