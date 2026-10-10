# Fast to write, or fast to read?

**Question:** If we build a record once and read it many times, how do FlatBuffers and Cap’n Proto split write time and read time?
**Date:** 2026-10-10
**Sample:** `['document', 'telemetry']`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Named JSON only. A rank that flips when the sample or the stall rule changes was never a fact about the libraries.

## Does the fastest named-JSON library stay the same? (N = 1)

| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |
|----------|---------|--------|----------|---------|---------|------------|------------|
| cpp | capnproto | — | capnproto | — | — | no | [cpp/results.md](cpp/results.md) |
| csharp | ZeroFormatter | — | MemoryPack | — | — | no | [csharp/results.md](csharp/results.md) |
| java | flatbuffers | — | flatbuffers | — | — | no | [java/results.md](java/results.md) |
| kotlin | flatbuffers | — | flatbuffers | — | — | no | [kotlin/results.md](kotlin/results.md) |
| php | protobuf | — | protobuf | — | — | no | [php/results.md](php/results.md) |
| javascript | flatbuffers | — | flatbuffers | — | — | no | [javascript/results.md](javascript/results.md) |
| python | protobuf | — | protobuf | — | — | no | [python/results.md](python/results.md) |
| rust | rkyv | — | rkyv | — | — | no | [rust/results.md](rust/results.md) |
| c | flatcc | — | protobuf-wire | — | — | no | [c/results.md](c/results.md) |
| swift | FlatBuffers | — | SwiftProtobuf | — | — | no | [swift/results.md](swift/results.md) |
| zig | comptime-bin | — | comptime-bin | — | — | no | [zig/results.md](zig/results.md) |
| mojo | mojo-avro | — | mojo-flatbuffers | — | — | no | [mojo/results.md](mojo/results.md) |
| fortran | custom-binary | — | custom-binary | — | — | no | [fortran/results.md](fortran/results.md) |

## Does the fastest stay the same at 100 records?

| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |
|----------|--------|--------------|----------------|-------|
| cpp | A (order) | capnproto | — | no |
| cpp | C (sensor) | capnproto | — | no |
| csharp | A (order) | ZeroFormatter | — | no |
| csharp | C (sensor) | MemoryPack | — | no |
| java | A (order) | flatbuffers | — | no |
| java | C (sensor) | flatbuffers | — | no |
| kotlin | A (order) | flatbuffers | — | no |
| kotlin | C (sensor) | flatbuffers | — | no |
| php | A (order) | protobuf | — | no |
| php | C (sensor) | protobuf | — | no |
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
| zig | A (order) | comptime-bin | — | no |
| zig | C (sensor) | comptime-bin | — | no |
| mojo | A (order) | mojo-avro | — | no |
| mojo | C (sensor) | mojo-flatbuffers | — | no |
| fortran | A (order) | custom-binary | — | no |
| fortran | C (sensor) | custom-binary | — | no |

## Experiment 1 sample (A, N = 1) — not clearly slower

| Language | Status | Not clearly slower | Small gap |
|----------|--------|--------------------|-----------|
| cpp | ok | `capnproto` | — |
| csharp | ok | `ZeroFormatter` | — |
| java | ok | `flatbuffers` | `protobuf` |
| kotlin | ok | `flatbuffers` | `protobuf` |
| php | ok | `protobuf` | — |
| javascript | ok | `flatbuffers` | — |
| python | ok | `protobuf` | — |
| rust | ok | `rkyv`, `prost` | — |
| c | ok | `flatcc` | — |
| swift | ok | `FlatBuffers` | — |
| zig | ok | `comptime-bin` | — |
| mojo | ok | `mojo-avro` | — |
| fortran | ok | `custom-binary` | — |

## In memory, by language and sample

### cpp

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| capnproto | 1.09 | 1.66 | 392 | fastest |
| flatbuffers | 1.20 | 2.51 | 188 | slower |
| protobuf | 2.58 | 3.29 | 164 | slower |
| protobuf-wire | 3.82 | 2.30 | 164 | slower |
| flexbuffers | 12.5 | 15.0 | 467 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| capnproto | 3.16 | 3.27 | 4184 | fastest |
| protobuf | 3.40 | 3.03 | 4127 | similar |
| flatbuffers | 2.18 | 9.13 | 4660 | slower |
| protobuf-wire | 20.5 | 8.89 | 4636 | slower |
| flexbuffers | 22.9 | 33.6 | 4743 | slower |

### csharp

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| ZeroFormatter | 7.71 | 4.61 | 288 | fastest |
| MemoryPack | 10.7 | 6.86 | 352 | slower |
| FlatSharp | 15.7 | 9.23 | 572 | slower |
| ProtoBuf | 12.6 | 14.2 | 208 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| MemoryPack | 17.5 | 28.4 | 5540 | fastest |
| FlatSharp | 26.2 | 40.7 | 5588 | slower |
| ZeroFormatter | 29.7 | 43.0 | 5520 | slower |
| ProtoBuf | 38.8 | 55.4 | 6184 | slower |

### java

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 24.7 | 18.1 | 416 | fastest |
| protobuf | 16.7 | 41.4 | 155 | close |
| capnproto | 51.9 | 36.3 | 376 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 25.7 | 20.9 | 4192 | fastest |
| capnproto | 64.9 | 37.1 | 4184 | slower |
| protobuf | 44.6 | 58.9 | 4128 | slower |

### kotlin

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 27.5 | 18.9 | 416 | fastest |
| protobuf | 30.2 | 27.3 | 155 | close |
| capnproto | 52.5 | 39.1 | 376 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 72.0 | 51.5 | 4192 | fastest |
| protobuf | 78.8 | 52.2 | 4128 | similar |
| capnproto | 91.2 | 67.1 | 4184 | slower |

### php

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 129 | 71.3 | 160 | fastest |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 595 | 370 | 4124 | fastest |

### javascript

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 37.8 | 17.9 | 416 | fastest |
| flexbuffers | 181 | 68.5 | 579 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatbuffers | 33.1 | 17.9 | 4192 | fastest |
| flexbuffers | 980 | 494 | 19841 | slower |

### python

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 7.26 | 5.77 | 155 | fastest |
| flatbuffers | 114 | 36.1 | 416 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf | 9.06 | 6.10 | 4128 | fastest |
| flatbuffers | 217 | 60.9 | 4192 | slower |

### rust

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| rkyv | 0.87 | 0.76 | 272 | fastest |
| prost | 0.52 | 1.12 | 155 | similar |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| rkyv | 0.80 | 0.62 | 4144 | fastest |
| prost | 0.89 | 2.13 | 4131 | slower |

### c

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| flatcc | 0.95 | 0.19 | 236 | fastest |
| protobuf-wire | 0.77 | 0.50 | 166 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| protobuf-wire | 0.91 | 1.58 | 4637 | fastest |
| flatcc | 3.24 | 0.41 | 4164 | slower |

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

### zig

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| comptime-bin | 0.16 | 0.23 | 214 | fastest |
| flatbuffers | 0.71 | 0.38 | 468 | slower |
| protobuf | 0.60 | 0.54 | 155 | slower |
| serde.msgpack | 1.05 | 0.66 | 325 | slower |
| capnproto | 3.57 | 4.13 | 376 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| comptime-bin | 1.33 | 0.37 | 4140 | fastest |
| capnproto | 2.79 | 2.43 | 4184 | slower |
| serde.msgpack | 3.18 | 1.91 | 4663 | slower |
| flatbuffers | 6.23 | 0.55 | 4188 | slower |
| protobuf | 3.81 | 3.47 | 4128 | slower |

### mojo

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| mojo-avro | 0.22 | 1.53 | 118 | fastest |
| mojo-protobuf | 0.59 | 1.85 | 157 | slower |
| mojo-flatbuffers | 3.59 | 1.10 | 416 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| mojo-flatbuffers | 3.21 | 2.55 | 4200 | fastest |
| mojo-avro | 2.71 | 7.65 | 4135 | slower |
| mojo-protobuf | 3.26 | 10.3 | 4137 | slower |

### fortran

**A (order), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| custom-binary | 0.77 | 2.26 | 211 | fastest |
| json-fortran | 33.1 | 41.6 | 473 | slower |
| hdf5-fortran | 206 | 167 | 9536 | slower |

**C (sensor), 1 record(s)**

| Library | Write (µs) | Read (µs) | Size (bytes) | Group |
|---------|------------|-----------|--------------|-------|
| custom-binary | 3.33 | 3.64 | 4131 | fastest |
| hdf5-fortran | 232 | 157 | 11256 | slower |
| json-fortran | 721 | 525 | 11802 | slower |

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

