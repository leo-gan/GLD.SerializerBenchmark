# Files people edit are not a request path

**Question:** On the same records, how much slower and larger are YAML, TOML, and XML than JSON?
**Date:** 2026-08-17
**Sample:** `['document', 'strings']`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| python | orjson | — | — | — | orjson | no | [python/results.md](python/results.md) |
| java | jackson | — | — | — | jackson | no | [java/results.md](java/results.md) |
| javascript | JSON.stringify | — | — | — | JSON.stringify | no | [javascript/results.md](javascript/results.md) |
| rust | serde_json | — | — | — | serde_json | no | [rust/results.md](rust/results.md) |
| c | yyjson | — | — | — | yyjson | no | [c/results.md](c/results.md) |
| cpp | nlohmann_json | — | — | — | nlohmann_json | no | [cpp/results.md](cpp/results.md) |
| go | goccy/go-json | — | — | — | goccy/go-json | no | [go/results.md](go/results.md) |
| swift | IkigaJSON | — | — | — | IkigaJSON | no | [swift/results.md](swift/results.md) |
| csharp | System.Text.Json | — | — | — | System.Text.Json | no | [csharp/results.md](csharp/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| python | A (order) | orjson | — | no |
| python | E (words) | orjson | — | no |
| java | A (order) | jackson | — | no |
| java | E (words) | jackson | — | no |
| javascript | A (order) | JSON.stringify | — | no |
| javascript | E (words) | JSON.stringify | — | no |
| rust | A (order) | serde_json | — | no |
| rust | E (words) | serde_json | — | no |
| c | A (order) | yyjson | — | no |
| c | E (words) | yyjson | — | no |
| cpp | A (order) | nlohmann_json | — | no |
| cpp | E (words) | nlohmann_json | — | no |
| go | A (order) | goccy/go-json | — | no |
| go | E (words) | goccy/go-json | — | no |
| swift | A (order) | IkigaJSON | — | no |
| swift | E (words) | IkigaJSON | — | no |
| csharp | A (order) | System.Text.Json | — | no |
| csharp | E (words) | System.Text.Json | — | no |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| python | ok | `orjson` | — |
| java | ok | `jackson` | — |
| javascript | ok | `JSON.stringify` | — |
| rust | ok | `serde_json` | — |
| c | ok | `yyjson` | — |
| cpp | ok | `nlohmann_json` | — |
| go | ok | `goccy/go-json` | — |
| swift | ok | `IkigaJSON` | — |
| csharp | ok | `System.Text.Json` | `MS XmlSerializer` |

## In memory, by language and sample

### python

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 5.16 | 448 | fastest |
| yaml | 1372 | 429 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| orjson | 3.32 | 410 | fastest |
| yaml | 761 | 406 | slower |

### java

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jackson | 88.9 | 440 | fastest |
| jackson-yaml | 388 | 441 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| jackson | 31.1 | 411 | fastest |
| jackson-yaml | 149 | 471 | slower |

### javascript

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 8.69 | 448 | fastest |
| js-yaml | 88.2 | 477 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| JSON.stringify | 5.24 | 411 | fastest |
| js-yaml | 51.1 | 471 | slower |

### rust

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde_json | 2.90 | 460 | fastest |
| serde_yaml | 30.7 | 438 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| serde_json | 2.54 | 390 | fastest |
| serde_yaml | 22.8 | 383 | slower |

### c

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 5.97 | 460 | fastest |
| libyaml | 32.4 | 461 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| yyjson | 3.76 | 387 | fastest |
| libyaml | 18.6 | 447 | slower |

### cpp

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nlohmann_json | 12.6 | 458 | fastest |
| yaml-cpp | 165 | 486 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| nlohmann_json | 8.33 | 411 | fastest |
| yaml-cpp | 128 | 470 | slower |

### go

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 5.32 | 448 | fastest |
| pelletier/go-toml | 19.4 | 500 | slower |
| goccy/go-yaml | 201 | 429 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| goccy/go-json | 3.56 | 411 | fastest |
| pelletier/go-toml | 7.03 | 441 | slower |
| goccy/go-yaml | 94.7 | 407 | slower |

### swift

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 53.2 | 448 | fastest |
| TOML | 196 | 508 | slower |
| XMLCoder | 413 | 729 | slower |
| Yams | 417 | 429 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| IkigaJSON | 34.6 | 411 | fastest |
| TOML | 76.2 | 441 | slower |
| Yams | 320 | 407 | slower |
| XMLCoder | 402 | 803 | slower |

### csharp

**A (order), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| System.Text.Json | 96.3 | 588 | fastest |
| MS XmlSerializer | 128 | 1258 | close |
| YamlDotNet | 867 | 421 | slower |

**E (words), 1 record(s)**

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| System.Text.Json | 60.3 | 548 | fastest |
| MS XmlSerializer | 140 | 1187 | slower |
| YamlDotNet | 746 | 406 | slower |

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

