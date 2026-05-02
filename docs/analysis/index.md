# Benchmarks

Empirical performance comparison of 38 C# and 10 Python serialization libraries using identical test data and measurement methodologies.

---

## Quick Access

| Report                                                    | Description                                                           |
|-----------------------------------------------------------|-----------------------------------------------------------------------|
| [Serialization Categories](./serialization_categories.md) | How serializers are classified (JSON, Binary, Schema)                 |
| [Analysis Methodology](./ANALYSIS_METHODOLOGY.md)         | Statistical methods and data processing pipeline                      |
| [Test Data Configuration](./test_data_configuration.md)   | Test data types and generation rules                                  |
| [Detailed Report](./BENCHMARK_SUMMARY.md)                 | Raw performance tables with latency, throughput, and size metrics     |
| [Performance](./violin-plots.md)                               | Statistical visualizations showing performance, variance and outliers |

---

## Summary Statistics

### C# Top Performers

Top performers by ops/sec.

| Rank | Serializer | Test Data | Mode | Ops/Sec |
|------|------------|-----------|------|---------|
| 1 | MS Bond Fast | Integer | string | 804,528 |
| 2 | NetSerializer | Integer | string | 419,342 |
| 3 | MS Bond Compact | Integer | string | 320,888 |

### Python Top Performers

Top performers by ops/sec.

| Rank | Serializer | Test Data | Mode | Ops/Sec |
|------|------------|-----------|------|---------|
| 1 | msgspec | Integer | bytes | 544,088 |
| 2 | orjson | Integer | bytes | 392,197 |
| 3 | msgspec | Integer | stream | 290,684 |

---

## Key Findings

- **Binary formats** (MessagePack, Protobuf) consistently outperform text formats (JSON, XML)
- **Schema-driven** serializers achieve smaller payload sizes by omitting field names
- **Zero-allocation** techniques in modern C# serializers (MemoryPack, FlatBuffers) minimize GC pressure
- Python's **orjson** and **msgspec** (C-extensions) are 10-100x faster than pure-Python alternatives

---

## Raw Data

Download complete benchmark results:

- [C# CSV](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/gh-pages/data/csharp/)
- [Python CSV](https://github.com/leo-gan/GLD.SerializerBenchmark/tree/gh-pages/data/python/)
