# Benchmark Results

Interactive performance comparison of .NET and Python serializers.

## Live Dashboard

View the full interactive dashboard with charts, pivot tables, and cross-language comparisons:

**[Open Dashboard →](./dashboard/index.html)**

The dashboard includes:
- Performance charts (top performers by ops/sec)
- Pivot tables (serializer × mode, serializer × data type)
- Cross-language winners by data type
- Violin plots showing distribution of times

## Quick Summary

### C# Top Performers (Operations/Second)

| Rank | Serializer | Best For | Relative Speed |
|------|-----------|----------|----------------|
| 1 | **GroBuf** | Binary, numeric arrays | ★★★★★ |
| 2 | **MS Bond Fast** | Schema-based microservices | ★★★★★ |
| 3 | **NetSerializer** | General binary | ★★★★☆ |
| 4 | **MemoryPack** | Modern binary (zero-copy) | ★★★★☆ |
| 5 | **FlatSharp** | FlatBuffers (zero-allocation) | ★★★★☆ |

### Python Top Performers (Operations/Second)

| Rank | Serializer | Category | Relative Speed |
|------|-----------|----------|----------------|
| 1 | **msgspec** | JSON/MessagePack | ★★★★★ |
| 2 | **orjson** | JSON (Rust-based) | ★★★★★ |
| 3 | **msgpack** | Binary | ★★★★☆ |
| 4 | **pickle** | Python-native | ★★★★☆ |
| 5 | **cloudpickle** | Distributed computing | ★★★☆☆ |

### Cross-Language Winners by Data Type

| Data Type | Winner | Best Serializer | Time (ns) |
|-----------|--------|-----------------|-----------|
| Integer | C# | MS Bond Fast | 1,293 |
| Person | C# | MS Bond Fast | 12,569 |
| SimpleObject | Python | msgspec | 3,054 |
| StringArray | Python | orjson | 32,312 |
| Telemetry | C# | MS Bond Fast | 8,849 |
| EDI_835 | C# | MS Bond Fast | 22,996 |
| ObjectGraph | C# | Json.Net | 13,235 |

## Key Findings

### Schema Serializers Dominate

**MS Bond Fast** (C#) consistently wins across most data types due to:
- Pre-compiled schema (no runtime reflection)
- Compact binary encoding
- Efficient packed arrays

### JSON Performance Gap

C# JSON serializers are generally slower than Python's `orjson` and `msgspec`:

| Operation | C# Best (SpanJson) | Python Best (orjson) | Winner |
|-----------|-------------------|---------------------|--------|
| Person | ~23K ops/sec | ~60K ops/sec | Python |
| SimpleObject | ~33K ops/sec | ~209K ops/sec | Python |

### Binary Format Trade-offs

| Format | Size vs JSON | Speed vs JSON | Use When |
|--------|--------------|---------------|----------|
| MessagePack | 20-50% smaller | Faster | Internal APIs |
| Protobuf | 50-70% smaller | Much faster | Microservices |
| FlatBuffers | Similar | Fastest (zero-copy) | Games/real-time |

## Violin Plots

The dashboard includes violin plots showing the distribution of serialize vs deserialize times:

- **Top half**: Serialization time distribution
- **Bottom half**: Deserialization time distribution
- **Width**: Density of measurements at that time value

These reveal characteristics hidden by averages:
- Bimodal distributions (different code paths)
- Variance within serializers
- Remaining outliers post-filtering

## Methodology Notes

Results are computed using:
- **Tukey's IQR method** for outlier removal
- **Warmup exclusion** (RepetitionIndex 0 removed)
- **Normalized nanoseconds** for cross-language fairness

See [Methodology](./methodology.md) for complete details.

## Raw Data

Download CSV files from the repository:
- `logs/csharp/benchmark-log.csv`
- `logs/python/benchmark-log.csv`

Or generate fresh results following [Getting Started](./getting-started.md).
