# Write once, read many times

**Question:** For a record we build once and read many times, how do FlatBuffers and Cap’n Proto split write time and read time, compared with Protocol Buffers?
**Date:** 2026-08-17
**Sample:** `['document', 'telemetry']`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| cpp | flatbuffers | — | protobuf | — | — | no | [cpp/results.md](cpp/results.md) |
| csharp | ZeroFormatter | — | MemoryPack | — | — | no | [csharp/results.md](csharp/results.md) |
| javascript | flatbuffers | — | flatbuffers | — | — | no | [javascript/results.md](javascript/results.md) |
| python | protobuf | — | protobuf | — | — | no | [python/results.md](python/results.md) |
| rust | rkyv | — | rkyv | — | — | no | [rust/results.md](rust/results.md) |
| c | flatcc | — | protobuf-wire | — | — | no | [c/results.md](c/results.md) |
| swift | FlatBuffers | — | SwiftProtobuf | — | — | no | [swift/results.md](swift/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| cpp | A (order) | flatbuffers | — | no |
| cpp | C (sensor) | protobuf | — | no |
| csharp | A (order) | ZeroFormatter | — | no |
| csharp | C (sensor) | MemoryPack | — | no |
| javascript | A (order) | flatbuffers | — | no |
| javascript | C (sensor) | flatbuffers | — | no |
| python | A (order) | protobuf | — | no |
| python | C (sensor) | protobuf | — | no |
| rust | A (order) | rkyv | — | no |
| rust | C (sensor) | rkyv | — | no |
| c | A (order) | flatcc | — | no |
| c | C (sensor) | protobuf-wire | — | no |
| swift | A (order) | FlatBuffers | — | no |
| swift | C (sensor) | SwiftProtobuf | — | no |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| cpp | ok | `flatbuffers` | — |
| csharp | ok | `ZeroFormatter` | — |
| javascript | ok | `flatbuffers` | — |
| python | ok | `protobuf` | — |
| rust | ok | `rkyv` | — |
| c | ok | `flatcc` | — |
| swift | ok | `FlatBuffers` | — |

## In memory, by language and sample

### cpp

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 0.33 | 0.94 | 188 | fastest |
| capnproto | 0.78 | 0.76 | 392 | slower |
| protobuf | 0.58 | 0.99 | 164 | slower |
| protobuf-wire | 1.65 | 0.87 | 164 | slower |
| flexbuffers | 6.77 | 6.41 | 467 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 0.72 | 0.63 | 4127 | fastest |
| capnproto | 1.18 | 1.73 | 4184 | slower |
| flatbuffers | 0.58 | 3.41 | 4660 | slower |
| protobuf-wire | 11.7 | 3.20 | 4636 | slower |
| flexbuffers | 9.26 | 13.1 | 4743 | slower |

### csharp

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| ZeroFormatter | 7.79 | 5.50 | 288 | fastest |
| MemoryPack | 11.0 | 6.88 | 352 | slower |
| FlatSharp | 16.1 | 9.93 | 572 | slower |
| ProtoBuf | 13.0 | 14.0 | 208 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| MemoryPack | 20.0 | 30.3 | 5540 | fastest |
| FlatSharp | 29.1 | 46.0 | 5588 | slower |
| ZeroFormatter | 32.5 | 47.7 | 5520 | slower |
| ProtoBuf | 35.9 | 57.4 | 6184 | slower |

### javascript

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 24.9 | 13.8 | 416 | fastest |
| flexbuffers | 383 | 55.7 | 579 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 31.0 | 17.5 | 4192 | fastest |
| flexbuffers | 1012 | 615 | 19841 | slower |

### python

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 2.55 | 3.00 | 155 | fastest |
| flatbuffers | 89.7 | 29.6 | 416 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 6.46 | 5.57 | 4128 | fastest |
| flatbuffers | 206 | 57.4 | 4192 | slower |

### rust

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| rkyv | 0.43 | 0.32 | 272 | fastest |
| prost | 0.51 | 0.58 | 155 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| rkyv | 0.33 | 0.20 | 4144 | fastest |
| prost | 0.76 | 0.95 | 4131 | slower |

### c

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatcc | 0.47 | 0.12 | 236 | fastest |
| protobuf-wire | 0.53 | 0.27 | 166 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf-wire | 0.52 | 1.06 | 4637 | fastest |
| flatcc | 1.67 | 0.31 | 4164 | close |

### swift

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| FlatBuffers | 3.85 | 3.92 | 440 | fastest |
| SwiftProtobuf | 4.65 | 4.35 | 155 | slower |
| CapnProto | 15.9 | 10.5 | 376 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| SwiftProtobuf | 5.73 | 4.90 | 4128 | fastest |
| FlatBuffers | 5.62 | 8.36 | 4216 | slower |
| CapnProto | 33.9 | 15.2 | 4184 | slower |

## What we saw

Look at write time and read time separately. Do not add them.

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

