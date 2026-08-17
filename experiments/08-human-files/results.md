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
| go | goccy/go-json | — | — | — | goccy/go-json | no | [go/results.md](go/results.md) |
| swift | IkigaJSON | — | — | — | IkigaJSON | no | [swift/results.md](swift/results.md) |
| csharp | System.Text.Json | — | — | — | System.Text.Json | no | [csharp/results.md](csharp/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| go | A (order) | goccy/go-json | — | no |
| go | E (words) | goccy/go-json | — | no |
| swift | A (order) | IkigaJSON | — | no |
| swift | E (words) | IkigaJSON | — | no |
| csharp | A (order) | System.Text.Json | — | no |
| csharp | E (words) | System.Text.Json | — | no |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| go | ok | `goccy/go-json` | — |
| swift | ok | `IkigaJSON` | — |
| csharp | ok | `System.Text.Json` | `MS XmlSerializer` |

## In memory, by language and sample

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

