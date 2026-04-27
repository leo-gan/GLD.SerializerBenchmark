# Cross-Language Serializer Benchmark

This repository benchmarks serialization libraries across **.NET (C#)** and **Python**, using identical test data, dual-mode APIs, and comparable metrics to enable fair cross-language performance analysis.

## Structure

```
├── c-sharp/          # .NET 8 benchmark (38 serializers)
├── python/           # Python 3.12 benchmark (9 serializers)
├── schemas/          # Shared Protobuf schema definitions
├── logs/             # Benchmark output CSVs
│   ├── csharp/
│   └── python/
└── README.md         # This file
```

## .NET (C#) Benchmark

- **38 serializers** including Json.NET, Protobuf-net, MessagePack, MemoryPack, FlatSharp, and more.
- Dual-mode testing: **String** and **Stream** APIs.
- Detailed CSV reporting with timing (ticks) and size (bytes).
- Jupyter Notebook analysis included.

**[Read the C# README →](c-sharp/README.md)**

## Python Benchmark

- **9 serializers** across JSON, Binary, Schema, and Python-native groups.
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

Both benchmarks use the same conceptual test data types, defined in [`schemas/benchmark_data.proto`](schemas/benchmark_data.proto):

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
