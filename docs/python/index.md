# Python Serializer Benchmark

Benchmark of **9 serializers** for Python 3.12, testing bytes and stream modes across 7 realistic data types.

## Quick Start

```bash
cd python
./scripts/run-benchmarks.sh smoke
```

## Serializer Groups

| Group | Serializers | Best For |
|-------|-------------|----------|
| **JSON** | orjson, msgspec, rapidjson | Public APIs |
| **Binary** | msgpack, cbor2 | Internal services |
| **Schema** | protobuf, avro | Microservices, data lakes |
| **Native** | pickle, cloudpickle | Python-only, caching |

## The 9 Tested Serializers

### JSON (3)

| Serializer | Library | Best For | Speed |
|------------|---------|----------|-------|
| **orjson** | `orjson` | Maximum JSON speed | ★★★★★ |
| **msgspec** | `msgspec` | Speed + validation | ★★★★☆ |
| **rapidjson** | `python-rapidjson` | RFC compliance | ★★★☆☆ |

**orjson** is the standout — Rust-based with SIMD operations, 3-5× faster than standard library `json`.

**msgspec** offers unique value with built-in schema validation and the lowest memory footprint.

### Binary (2)

| Serializer | Library | Format | Best For | Speed |
|------------|---------|--------|----------|-------|
| **msgpack** | `msgpack` | MessagePack | Speed + ecosystem | ★★★★☆ |
| **cbor2** | `cbor2` | CBOR | Standards compliance | ★★★☆☆ |

### Schema (2)

| Serializer | Library | Format | Best For |
|------------|---------|--------|----------|
| **protobuf** | `protobuf` | Protocol Buffers | Cross-language microservices |
| **avro** | `fastavro` | Avro | Hadoop/Spark data pipelines |

### Python-Native (2)

| Serializer | Library | Best For | Security |
|------------|---------|----------|----------|
| **pickle** | stdlib | Caching, ML, multiprocessing | ⚠️ Unsafe |
| **cloudpickle** | `cloudpickle` | Distributed computing (Dask, Ray) | ⚠️ Unsafe |

⚠️ **Security Warning**: Never unpickle data from untrusted sources. Pickle can execute arbitrary code.

## Test Data Types

| Type | Description |
|------|-------------|
| `Person` | Real-world dataclass |
| `Integer` | Primitive throughput |
| `SimpleObject` | Minimal overhead |
| `StringArray` | Memory allocation test |
| `Telemetry` | Numeric arrays |
| `EDI_835` | Deeply nested document |
| `ObjectGraph` | Circular references (pickle/cloudpickle only) |

## Top Results Summary

### Fastest Overall (by ops/sec)

| Rank | Serializer | Data Type | Ops/Sec |
|------|------------|-----------|---------|
| 1 | msgspec | Integer | 685,675 |
| 2 | msgspec | SimpleObject | 327,476 |
| 3 | orjson | Integer | 487,675 |
| 4 | orjson | StringArray | 30,948 |
| 5 | msgpack | Integer | 346,845 |

### Smallest Payload (by bytes)

| Serializer | Person Size | Notes |
|------------|-------------|-------|
| protobuf | 665 | Fixed schema, smallest |
| avro | 567 | Self-describing |
| msgpack | 1,631 | Binary schemaless |
| orjson | ~1,730 | Standard JSON |
| pickle | 1,321 | Python native |

### Memory Efficiency (peak bytes)

| Serializer | Person Memory | Notes |
|------------|---------------|-------|
| msgspec | ~5KB | Lowest overhead |
| orjson | ~28KB | Aggressive optimization |
| msgpack | ~37KB | Buffering overhead |
| protobuf | ~14KB | Schema-based |

## Architecture

### Serializer Base Class

```python
from benchmark.serializers.base import Serializer

class MySerializer(Serializer):
    def serialize(self, obj: Any) -> bytes:
        ...

    def deserialize(self, data: bytes) -> Any:
        ...

    def serialize_stream(self, obj: Any, stream: BytesIO) -> None:
        ...

    def deserialize_stream(self, stream: BytesIO) -> Any:
        ...
```

### Adding a Serializer

1. Create file in `src/benchmark/serializers/`
2. Inherit from `Serializer` base
3. Implement required methods
4. Register in `runner.py` `ALL_SERIALIZERS`

## Detailed Documentation

- **[Serializer Reference](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/main/python/docs/serializers.md)** — All 9 serializers with detailed descriptions, pros/cons, and benchmark notes

## Running Benchmarks

```bash
# Smoke test (1 repetition)
./scripts/run-benchmarks.sh smoke

# Verify all serializers
./scripts/run-benchmarks.sh all-single

# Full run (100 repetitions)
./scripts/run-benchmarks.sh full

# Custom (50 reps, JSON serializers, Person data)
./scripts/run-benchmarks.sh custom 50 "json" "Person"
```

## Local Development (uv)

```bash
cd python
uv sync
uv run python -m benchmark.runner 10 "json" "Person"
```

## Results

Results are written to:
- `logs/python/benchmark-log.csv` — Performance metrics
- `logs/python/benchmark-errors.csv` — Failure details

Columns include:
- `StringOrStream`, `TestDataName`, `SerializerName`
- `TimeSer`, `TimeDeser`, `Size`
- `OpPerSecSer`, `OpPerSecDeser`, `OpPerSecSerAndDeser`
- `MemoryPeakBytes` — Python heap allocation
- `FidelityScore` — Semantic roundtrip correctness

## Docker Support

```bash
# Build
docker build -t python-benchmark .

# Run
docker run -v $(pwd)/logs:/app/logs python-benchmark smoke
```

## Why Custom Runner Instead of pytest-benchmark?

1. **Format parity** with C# CSV schema
2. **Warmup logic** matching C# methodology
3. **Multi-metric** (throughput, latency, memory, fidelity)
4. **Dual-mode** testing (bytes vs stream)

## Cross-Language Notes

Python's JSON serializers (orjson, msgspec) significantly outperform C# equivalents due to highly optimized Rust/C implementations. However, C#'s schema serializers (MS Bond Fast) dominate binary performance.

## See Also

- [C# Benchmark](../c-sharp/index.md) — Cross-language comparison
- [Benchmark Results](../benchmark-results.md) — Interactive dashboard
- [Serializer Formats](../serializers/overview.md) — Format selection guide
