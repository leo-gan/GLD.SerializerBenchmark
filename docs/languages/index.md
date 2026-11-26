---
title: "Languages"
---

# Languages

Fourteen benchmark runners execute the same logical data sets ([Suite](../analysis/suite.md), [Columnar](../analysis/columnar.md), [Graph](../analysis/graph.md), [Array](../analysis/array.md), and [Tensor](../analysis/tensor.md)) under a shared CSV contract and statistical analysis pipeline. Each language page documents the host runtime, registered serializer roster, timed call paths, and measurement caveats; live L1 measurements belong to the [Dashboard](../dashboard/index.html).

> **Cross-language comparison scope:** Absolute latencies across languages conflate serializer design with runtime architecture—ahead-of-time compilation versus JIT warmup, manual memory management versus tracing garbage collection or reference counting, and runtime object representations. Treat cross-language timings as rough orientation only; perform formal comparisons **within one language, one standard, one data set, and one data type** ([Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)).

## Runtime Matrix

| Language | Execution & Memory | Target Toolchain | Data Sets | Stream I/O | Links |
|---|---|---|---|---|---|
| **C** | Native AOT; manual allocation | C11 / CMake (Release) | `suite`, `array`, `tensor` | Adapted (`ion-c`, `yyjson` native) | [Overview](../c/index.md) · [Dashboard](../dashboard/index.html?lang=c) · [Call-site](../analysis/call-sites/c-custom-binary-vs-ubj.md) |
| **C#** | CLR JIT; tracing GC | .NET 10 (`net10.0`) | `suite`, `columnar`, `array`, `tensor` | Native, text-on-stream, adapted | [Overview](../c-sharp/index.md) · [Dashboard](../dashboard/index.html?lang=csharp) · [Call-site](../analysis/call-sites/csharp-binarypack-vs-bond.md) |
| **C++** | Native AOT; RAII / manual | C++20 / CMake (Release) | `suite`, `columnar`, `graph`, `array`, `tensor` | Native + adapted | [Overview](../cpp/index.md) · [Dashboard](../dashboard/index.html?lang=cpp) · [Call-site](../analysis/call-sites/cpp-bitsery-vs-yas.md) · [401](../theory/401/cpp-simdjson-wrapper.md) |
| **Fortran** | Native AOT; process allocator | gfortran 13+ / fpm 0.13 | `suite`, `array` | Bytes + native file (`netcdf`, `adios2`) | [Overview](../fortran/index.md) · [Dashboard](../dashboard/index.html?lang=fortran) · [Call-site](../analysis/call-sites/fortran-json-fortran-vs-rojff.md) |
| **Go** | Native AOT; concurrent tracing GC | Go 1.27 (`go.mod`) | `suite`, `columnar`, `graph`, `tensor` | Native + adapted | [Overview](../go/index.md) · [Dashboard](../dashboard/index.html?lang=go) · [Call-site](../analysis/call-sites/go-kelindar-vs-avro.md) |
| **Java** | HotSpot JVM JIT; tracing GC | JDK 21 / Maven 3.9+ | `suite`, `columnar`, `tensor` | Native + adapted | [Overview](../java/index.md) · [Dashboard](../dashboard/index.html?lang=java) · [Call-site](../analysis/call-sites/java-protostuff-vs-protobuf.md) |
| **JavaScript** | Node.js V8 JIT; tracing GC | Node.js 18+ | `suite`, `columnar`, `graph`, `array`, `tensor` | Bytes only | [Overview](../javascript/index.md) · [Dashboard](../dashboard/index.html?lang=javascript) · [Call-site](../analysis/call-sites/javascript-json-vs-protobuf.md) · [401](../theory/401/javascript-three-protobufs.md) |
| **Kotlin** | HotSpot JVM JIT; tracing GC | Kotlin 2.3.20 / JVM 21 / Gradle | `suite`, `columnar` | Native + adapted | [Overview](../kotlin/index.md) · [Dashboard](../dashboard/index.html?lang=kotlin) · [Call-sites](../analysis/call-sites/index.md) |
| **Mojo** | Native AOT; ownership | Mojo 1.1.0 (`pixi`) | `suite`, `columnar`, `graph`, `array`, `tensor` | Bytes only | [Overview](../mojo/index.md) · [Dashboard](../dashboard/index.html?lang=mojo) · [Call-site](../analysis/call-sites/mojo-emberjson-vs-avro.md) |
| **PHP** | Zend opcode VM (CLI); refcount + cyclic GC | PHP 8.2+ / Composer | `suite` | Text-on-stream + adapted | [Overview](../php/index.md) · [Dashboard](../dashboard/index.html?lang=php) · [Call-site](../analysis/call-sites/php-json-vs-protobuf.md) |
| **Python** | CPython bytecode VM; refcount + cyclic GC + GIL | CPython 3.12+ (`uv`) | `suite`, `columnar`, `graph`, `array`, `tensor` | Native, text-on-stream, adapted | [Overview](../python/index.md) · [Dashboard](../dashboard/index.html?lang=python) · [Call-sites](../analysis/call-sites/index.md) · [401](../theory/401/python-msgspec-vs-orjson.md) |
| **Rust** | Native AOT; compile-time ownership | Rust 2021 (`cargo --release`) | `suite`, `columnar`, `graph`, `array`, `tensor` | Native + adapted | [Overview](../rust/index.md) · [Dashboard](../dashboard/index.html?lang=rust) · [Call-site](../analysis/call-sites/rust-speedy-vs-postcard.md) · [401](../theory/401/rust-speedy-vs-bincode.md) |
| **Swift** | Native AOT; ARC | Swift 6.0+ / SwiftPM (`-c release`) | `suite`, `graph`, `tensor` | Adapted | [Overview](../swift/index.md) · [Dashboard](../dashboard/index.html?lang=swift) · [Call-site](../analysis/call-sites/swift-flatbuffers-vs-protobuf.md) |
| **Zig** | Native AOT; explicit allocators | Zig 0.16.x (`zig build`) | `suite`, `tensor` | Native, text-on-stream, adapted | [Overview](../zig/index.md) · [Dashboard](../dashboard/index.html?lang=zig) · [Call-site](../analysis/call-sites/zig-std-json-vs-serde-json.md) |

## Reading a Language Overview

Each language page follows a uniform five-section specification:

1. **Runtime & Environment** — execution model, authoritative language specification, toolchain pin, and runner entry point.
2. **Registered Serializers** — uniform five-column roster (`Serializer`, `Standard`, `Data sets`, `Stream I/O`, `Timed call path & notes`) plus a collapsible provenance drawer generated from `config/serializer-sources.json`.
3. **Measurement Caveats** — language-specific timing, fidelity, optional dependency, or framing constraints.
4. **Results & Further Reading** — pre-filtered Dashboard link, compliance report, source-level call-site notes, and build instructions.

For methodology and timing rules shared across all fourteen runners, see [Benchmarks](../analysis/index.md) and [Timing contract](../analysis/TIMING_HONESTY.md).
