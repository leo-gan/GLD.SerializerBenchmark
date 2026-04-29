# Cross-Language Serializer Benchmark

> 🎓 **[Take the Serialization 101 Course & View Benchmark Reports](https://leo-gan.github.io/GLD.SerializerBenchmark/)**
> 
> *Our official documentation site serves as a comprehensive guide for Senior Software Developers and Data Scientists, covering serialization theory, C#/Python language specifics, and deep-dive benchmark results.*

This repository contains the source code for benchmarking serialization libraries across **.NET (C#)** and **Python**, using identical test data, dual-mode APIs, and comparable metrics to enable fair cross-language performance analysis.

## .NET (C#) Benchmark

- **38 serializers** including Json.NET, Protobuf-net, MessagePack, MemoryPack, FlatSharp, and more.
- Dual-mode testing: **String** and **Stream** APIs.
- Detailed CSV reporting with timing (ticks) and size (bytes).
- Jupyter Notebook analysis included.

**[Read the C# README →](c-sharp/README.md)**

## Python Benchmark

- **Serializers** across JSON, Binary, Schema, and Python-native groups.
- Dual-mode testing: **bytes** and **stream** APIs.
- Extended metrics: throughput, latency, memory allocation, output size, and type fidelity.
- Dockerized execution with `uv` for reproducible environments.

**[Read the Python README →](python/README.md)**

## Getting Started

### C# Benchmark

```bash
cd c-sharp
./scripts/run-benchmarks.sh smoke
```

### Python Benchmark

```bash
cd python
./scripts/run-benchmarks.sh smoke
```

## Shared Test Data

Both benchmarks use the same conceptual test data types, defined in [`schemas/benchmark_data.proto`](schemas/benchmark_data.proto) and configured via [`schemas/test_data_config.json`](schemas/test_data_config.json).

For details on how test data is generated and configured, see the **[Test Data Design](docs/test_data_design.md)**.

- **Person**: Nested POCO with enums, strings, and arrays.
- **Integer**: Primitive throughput baseline.
- **Telemetry**: Numeric arrays testing binary efficiency.
- **SimpleObject**: Minimal overhead.
- **StringArray**: GC/memory pressure test.
- **EDI_835**: Deeply nested real-world document.
- **ObjectGraph**: Circular references (only native serializers expected to pass).

## Results

Results are written to:
- `logs/csharp/benchmark-log.csv`
- `logs/csharp/benchmark-errors.csv`
- `logs/python/benchmark-log.csv`
- `logs/python/benchmark-errors.csv`

## License

MIT
