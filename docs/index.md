# Serialization & Deserialization

*A comprehensive benchmark of the language-specific serializers across realistic data scenarios.*

## What is Serialization?

**Serialization** converts in-memory data structures into a format that can be stored or transmitted. **Deserialization** reverses this process, reconstructing the original objects from the stored/transmitted format.

```
┌─────────────────┐    Serialize    ┌─────────────────┐
│   In-Memory     │ ───────────────> │  Byte Stream    │
│   Objects       │                  │  / File / Wire  │
│  (POCOs/ Dicts) │                  │  (JSON/Binary)  │
└─────────────────┘                  └─────────────────┘
        │                                    │
        │         Deserialize                │
        │<───────────────────────────────────│
```

### Why It Matters

| Concern | Impact |
|--------|--------|
| **Latency** | Directly affects API response times and user experience |
| **Throughput** | Determines system capacity under load |
| **Payload Size** | Impacts bandwidth costs and mobile battery life |
| **CPU Usage** | Affects server costs and thermal throttling |
| **Memory Pressure** | Influences GC pauses and allocation overhead |

## Format Taxonomy

| Format | Schema | Human-Readable | Size | Speed | Use Case |
|--------|--------|----------------|------|-------|----------|
| **JSON** | Optional | Yes | Large | Medium | APIs, configs, debugging |
| **Binary (MsgPack/CBOR)** | Optional | No | Small | Fast | Internal services, caching |
| **Schema (Protobuf/Avro)** | Required | No | Smallest | Fastest | Microservices, storage |
| **Native (Pickle)** | None | No | Medium | Fast | Python-only, in-process |

## Benchmark Overview

This project provides **fair, reproducible cross-language comparisons** using identical test data and measurement methodologies.

### Test Data Coverage

| Data Type | Description | Stress Point |
|-----------|-------------|--------------|
| `Integer` | Single primitive | Raw throughput ceiling |
| `Person` | Nested POCO with enums | Real-world object complexity |
| `SimpleObject` | Minimal structure | Overhead baseline |
| `StringArray` | 100 strings | Memory allocation pressure |
| `Telemetry` | Numeric arrays | Binary format efficiency |
| `EDI_835` | Deeply nested document | Recursion depth |
| `ObjectGraph` | Circular references | Reference tracking |

### Serializer Count

| Language | Serializers | Modes |
|----------|-------------|-------|
| C# | 38 | String, Stream |
| Python | 9 | Bytes, Stream |

## Quick Links

- **[Getting Started](./getting-started.md)** — Run benchmarks in 5 minutes
- **[Methodology](./methodology.md)** — How we measure and compare
- **[Serializer Guide](./serializers/overview.md)** — Choose the right format
- **[C# Benchmarks](./c-sharp/index.md)** — .NET 8 serializer details
- **[Python Benchmarks](./python/index.md)** — Python serializer details
- **[Results Dashboard](./benchmark-results.md)** — Interactive performance charts

## Citation

```bibtex
@misc{serializerbenchmark2024,
  title={Cross-Language Serializer Benchmark},
  author={Ganeline, Leonid},
  year={2026},
  url={https://leo-gan.github.io/GLD.SerializerBenchmark/}
}
```

---

*For implementation details, see the [GitHub repository](https://github.com/leo-gan/GLD.SerializerBenchmark).*
