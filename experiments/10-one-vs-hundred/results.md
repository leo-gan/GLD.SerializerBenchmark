# Does one record rank the same as one hundred?

**Question:** Does the library that is fastest for one record stay fastest when we write one hundred records at once?
**Date:** 2026-08-28
**Sample:** `['message', 'event']`, [1, 100] record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | — | orjson | — | orjson | — | no | [python/results.md](python/results.md) |
| go | — | protobuf | — | protobuf | — | no | [go/results.md](go/results.md) |
| java | — | protobuf | — | jsoniter | — | no | [java/results.md](java/results.md) |
| kotlin | — | protobuf | — | moshi-codegen | — | no | [kotlin/results.md](kotlin/results.md) |
| javascript | — | JSON.stringify | — | JSON.stringify | — | no | [javascript/results.md](javascript/results.md) |
| rust | — | prost | — | rmp-serde | — | no | [rust/results.md](rust/results.md) |
| c | — | protobuf-c | — | protobuf-wire | — | no | [c/results.md](c/results.md) |
| cpp | — | protobuf-wire | — | protobuf-wire | — | no | [cpp/results.md](cpp/results.md) |
| csharp | — | SpanJson | — | SpanJson | — | no | [csharp/results.md](csharp/results.md) |
| swift | — | SwiftProtobuf | — | SwiftProtobuf | — | no | [swift/results.md](swift/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | B (flat) | orjson | msgspec-msgpack | no |
| python | D (event) | orjson | protobuf | no |
| go | B (flat) | protobuf | protobuf | yes |
| go | D (event) | protobuf | goccy/go-json | no |
| java | B (flat) | protobuf | protobuf | yes |
| java | D (event) | jsoniter | jsoniter | yes |
| kotlin | B (flat) | protobuf | protobuf | yes |
| kotlin | D (event) | moshi-codegen | protobuf | no |
| javascript | B (flat) | JSON.stringify | JSON.stringify | yes |
| javascript | D (event) | JSON.stringify | msgpackr | no |
| rust | B (flat) | prost | prost | yes |
| rust | D (event) | rmp-serde | sonic-rs | no |
| c | B (flat) | protobuf-c | protobuf-wire | no |
| c | D (event) | protobuf-wire | protobuf-wire | yes |
| cpp | B (flat) | protobuf-wire | protobuf-wire | yes |
| cpp | D (event) | protobuf-wire | msgpack | no |
| csharp | B (flat) | SpanJson | MessagePack-CSharp | no |
| csharp | D (event) | SpanJson | SpanJson | yes |
| swift | B (flat) | SwiftProtobuf | SwiftProtobuf | yes |
| swift | D (event) | SwiftProtobuf | SwiftProtobuf | yes |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | — | — |
| go | ok | — | — |
| java | ok | — | — |
| kotlin | ok | — | — |
| javascript | ok | — | — |
| rust | ok | — | — |
| c | ok | — | — |
| cpp | ok | — | — |
| csharp | ok | — | — |
| swift | ok | — | — |

## In memory, by language and sample

### python

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 2.74 | 257 | fastest |
| msgspec-msgpack | 3.16 | 112 | slower |
| protobuf | 4.44 | 123 | slower |
| msgpack | 5.92 | 199 | slower |
| json | 15.3 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 70.2 | 12477 | fastest |
| msgspec-msgpack | 89.0 | 11148 | slower |
| orjson | 134 | 25746 | slower |
| msgpack | 206 | 19848 | slower |
| json | 347 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 1.72 | 168 | fastest |
| msgspec-msgpack | 1.93 | 52 | close |
| protobuf | 3.36 | 50 | slower |
| msgpack | 4.38 | 124 | slower |
| json | 12.2 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgspec-msgpack | 33.5 | 4831 | fastest |
| protobuf | 37.2 | 4841 | slower |
| orjson | 64.6 | 16546 | slower |
| msgpack | 117 | 12031 | slower |
| json | 251 | 16546 | slower |

### go

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 2.33 | 123 | fastest |
| goccy/go-json | 2.47 | 257 | similar |
| shamaton/msgpack | 2.92 | 196 | slower |
| vmihailenco/msgpack | 3.92 | 196 | slower |
| encoding/json | 5.78 | 257 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 113 | 25746 | fastest |
| protobuf | 126 | 12477 | slower |
| shamaton/msgpack | 138 | 19548 | slower |
| vmihailenco/msgpack | 215 | 19548 | slower |
| encoding/json | 359 | 25746 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 2.36 | 50 | fastest |
| shamaton/msgpack | 3.14 | 114 | close |
| goccy/go-json | 3.46 | 168 | close |
| vmihailenco/msgpack | 3.91 | 118 | slower |
| encoding/json | 6.09 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 43.6 | 4841 | fastest |
| shamaton/msgpack | 52.7 | 11031 | slower |
| goccy/go-json | 69.4 | 16546 | slower |
| vmihailenco/msgpack | 76.4 | 11457 | slower |
| encoding/json | 200 | 16546 | slower |

### java

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 26.6 | 254 | fastest |
| protobuf | 28.8 | 123 | similar |
| msgpack | 51.7 | 196 | slower |
| jackson | 57.9 | 254 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jsoniter | 171 | 25446 | fastest |
| protobuf | 194 | 12477 | close |
| jackson | 260 | 25446 | slower |
| msgpack | 424 | 19548 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 25.2 | 50 | fastest |
| jsoniter | 36.5 | 150 | slower |
| msgpack | 91.7 | 114 | slower |
| jackson | 103 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 116 | 4841 | fastest |
| jsoniter | 146 | 14804 | slower |
| jackson | 229 | 15546 | slower |
| msgpack | 275 | 11031 | slower |

### kotlin

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| moshi-codegen | 19.1 | 254 | fastest |
| protobuf | 26.7 | 123 | slower |
| jackson | 65.5 | 254 | slower |
| msgpack | 66.8 | 196 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 186 | 12477 | fastest |
| moshi-codegen | 228 | 25446 | slower |
| jackson | 322 | 25446 | slower |
| msgpack | 413 | 19548 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 35.0 | 50 | fastest |
| moshi-codegen | 47.5 | 158 | slower |
| msgpack | 132 | 114 | slower |
| jackson | 147 | 158 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf | 120 | 4841 | fastest |
| moshi-codegen | 225 | 15546 | slower |
| jackson | 338 | 15546 | slower |
| msgpack | 388 | 11031 | slower |

### javascript

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 4.67 | 257 | fastest |
| msgpackr | 11.2 | 209 | slower |
| @msgpack/msgpack | 18.9 | 199 | slower |
| protobufjs | 21.2 | 123 | slower |
| protobuf-es | 29.0 | 123 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpackr | 235 | 20848 | fastest |
| JSON.stringify | 249 | 25746 | close |
| @msgpack/msgpack | 292 | 19848 | slower |
| protobufjs | 355 | 12477 | slower |
| protobuf-es | 1231 | 12477 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 5.10 | 168 | fastest |
| msgpackr | 13.9 | 126 | slower |
| @msgpack/msgpack | 20.2 | 124 | slower |
| protobufjs | 26.8 | 52 | slower |
| protobuf-es | 37.7 | 50 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 92.9 | 16546 | fastest |
| msgpackr | 123 | 12231 | slower |
| protobufjs | 143 | 5047 | slower |
| @msgpack/msgpack | 144 | 12031 | slower |
| protobuf-es | 450 | 4841 | slower |

### rust

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| rmp-serde | 0.68 | 197 | fastest |
| sonic-rs | 0.82 | 258 | slower |
| prost | 0.83 | 114 | slower |
| serde_json | 1.06 | 258 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| sonic-rs | 95.4 | 26978 | fastest |
| rmp-serde | 100 | 20878 | slower |
| prost | 112 | 12578 | slower |
| serde_json | 142 | 26978 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 0.22 | 55 | fastest |
| rmp-serde | 0.35 | 136 | slower |
| sonic-rs | 0.51 | 182 | slower |
| serde_json | 0.57 | 182 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| prost | 25.6 | 5102 | fastest |
| rmp-serde | 35.9 | 13364 | slower |
| sonic-rs | 43.5 | 18070 | slower |
| serde_json | 63.9 | 18070 | slower |

### c

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.62 | 121 | fastest |
| protobuf-c | 0.63 | 121 | close |
| msgpack-c | 1.95 | 197 | slower |
| mpack | 2.04 | 197 | slower |
| yyjson | 2.47 | 255 | slower |
| cJSON | 5.63 | 255 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 52.9 | 12764 | fastest |
| protobuf-c | 53.3 | 12764 | close |
| mpack | 98.7 | 20364 | slower |
| msgpack-c | 105 | 20364 | slower |
| yyjson | 215 | 26164 | slower |
| cJSON | 457 | 26164 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-c | 0.21 | 51 | fastest |
| protobuf-wire | 0.22 | 51 | close |
| msgpack-c | 0.93 | 125 | slower |
| mpack | 0.93 | 125 | slower |
| yyjson | 1.22 | 170 | slower |
| cJSON | 3.35 | 170 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 27.8 | 4932 | fastest |
| protobuf-c | 27.9 | 4932 | similar |
| mpack | 56.4 | 12295 | slower |
| msgpack-c | 59.5 | 12295 | slower |
| yyjson | 105 | 16717 | slower |
| cJSON | 297 | 16741 | slower |

### cpp

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 1.49 | 138 | fastest |
| msgpack | 1.90 | 214 | slower |
| simdjson | 5.55 | 272 | slower |
| nlohmann_json | 5.74 | 272 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| msgpack | 84.1 | 19565 | fastest |
| protobuf-wire | 121 | 12183 | slower |
| simdjson | 378 | 25463 | slower |
| nlohmann_json | 411 | 25463 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 0.56 | 50 | fastest |
| msgpack | 1.18 | 124 | slower |
| nlohmann_json | 3.75 | 168 | slower |
| simdjson | 3.77 | 168 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| protobuf-wire | 40.2 | 4841 | fastest |
| msgpack | 47.0 | 12031 | slower |
| simdjson | 241 | 16546 | slower |
| nlohmann_json | 245 | 16546 | slower |

### csharp

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 7.87 | 254 | fastest |
| Google.Protobuf | 10.8 | 164 | slower |
| ProtoBuf | 11.0 | 164 | slower |
| MessagePack-CSharp | 11.4 | 156 | slower |
| System.Text.Json | 19.3 | 340 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 112 | 25456 | fastest |
| MessagePack-CSharp | 140 | 15536 | slower |
| Google.Protobuf | 163 | 16636 | slower |
| ProtoBuf | 187 | 16636 | slower |
| System.Text.Json | 295 | 33944 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SpanJson | 10.7 | 157 | fastest |
| Google.Protobuf | 10.8 | 68 | similar |
| MessagePack-CSharp | 13.3 | 72 | slower |
| ProtoBuf | 16.1 | 68 | slower |
| System.Text.Json | 50.1 | 212 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| MessagePack-CSharp | 83.8 | 6580 | fastest |
| SpanJson | 100 | 15456 | close |
| ProtoBuf | 116 | 6456 | close |
| Google.Protobuf | 127 | 6456 | similar |
| System.Text.Json | 278 | 20608 | slower |

### swift

**D (event), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 7.35 | 123 | fastest |
| IkigaJSON | 29.5 | 257 | slower |
| Foundation.JSONEncoder | 31.6 | 257 | slower |
| SwiftMsgpack | 45.1 | 199 | slower |

**D (event), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 222 | 12477 | fastest |
| Foundation.JSONEncoder | 1438 | 25746 | slower |
| IkigaJSON | 1559 | 25746 | slower |
| SwiftMsgpack | 2720 | 19848 | slower |

**B (flat), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 3.71 | 50 | fastest |
| IkigaJSON | 19.6 | 168 | slower |
| Foundation.JSONEncoder | 20.0 | 168 | slower |
| SwiftMsgpack | 25.3 | 124 | slower |

**B (flat), 100 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| SwiftProtobuf | 56.4 | 4841 | fastest |
| Foundation.JSONEncoder | 703 | 16546 | slower |
| IkigaJSON | 797 | 16546 | slower |
| SwiftMsgpack | 1191 | 12041 | slower |

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

