# .NET (C#) Serializer Benchmark

Benchmark of **38 serializers** for .NET 8, testing String and Stream modes across 7 realistic data types.

## Quick Start

```bash
cd c-sharp
./scripts/run-benchmarks.sh smoke
```

## Featured Serializers

| Category | Top Performers | Use Case |
|----------|----------------|----------|
| **JSON** | SpanJson, Jil, Utf8Json | Public APIs |
| **Binary** | GroBuf, MemoryPack, NetSerializer | Internal services |
| **Schema** | MS Bond Fast, ProtoBuf, FlatSharp | Microservices |
| **Legacy** | MS Binary, SharpYaml | Compatibility |

## All 38 Tested Serializers

### JSON (9)
| Serializer | Best For |
|------------|----------|
| Json.NET | Industry standard, flexibility |
| SpanJson | Maximum JSON speed |
| Jil | Fast, simple |
| Utf8Json | UTF-8 optimized |
| NetJSON | Fast reflection |
| ServiceStack Json | ServiceStack integration |
| fastJson | Speed claims |
| MS DataContract Json | WCF compatible |
| SharpYaml | YAML with JSON |

### Binary & Schema (18)
| Serializer | Format | Best For |
|------------|--------|----------|
| MS Bond Fast | Bond | Maximum .NET speed |
| MS Bond Compact | Bond | Size/speed balance |
| MS Bond Json | Bond | Human-readable |
| ProtoBuf | Protocol Buffers | Cross-language |
| MemoryPack | Custom | Zero-copy binary |
| FlatSharp | FlatBuffers | Zero-allocation |
| GroBuf | Custom | Fastest overall |
| NetSerializer | Custom | General binary |
| MessagePack | MessagePack | Wide support |
| Ceras | Custom | Ease of use |
| Hyperion | Custom | Akka.NET |
| FsPickler | Custom | F# integration |
| FsPicklerJson | Pickle+JSON | F# + human-readable |
| Migrant | Custom | Complex graphs |
| MS Binary | BinaryFormatter | Legacy only |
| ServiceStack Type | Custom | ServiceStack |
| SharpSerializer | Custom | XML-like |
| ExtendedXmlSerializer | XML | XML with features |

### XML & YAML (7)
| Serializer | Format | Best For |
|------------|--------|----------|
| MS XmlSerializer | XML | Built-in |
| MS DataContract | XML | WCF |
| YAXLib | XML | XML features |
| SharpYaml | YAML | YAML serialization |
| YamlDotNet | YAML | YAML ecosystem |
| CsvHelper | CSV | Tabular data |
| Bond | CSV (limited) | Bond CSV export |

### Specialized (4)
| Serializer | Best For |
|------------|----------|
| Wire | Akka.NET persistence |
| ZeroFormatter (if present) | Zero-format |

## Test Data Types

| Type | Description |
|------|-------------|
| `SimpleObject` | Minimal overhead baseline |
| `Person` | Real-world POCO with nesting |
| `Integer` | Primitive throughput |
| `StringArray` | GC pressure test |
| `Telemetry` | Binary efficiency (numeric arrays) |
| `EDI_835` | Deeply nested document |
| `ObjectGraph` | Circular references |

## Top Results Summary

### Fastest Overall (by ops/sec)

| Rank | Serializer | Data Type | Ops/Sec |
|------|------------|-----------|---------|
| 1 | GroBuf | Integer | 290,604 |
| 2 | MS Bond Fast | Integer | 773,149 |
| 3 | NetSerializer | Integer | 429,066 |
| 4 | Hyperion | Integer | 223,508 |
| 5 | MemoryPack | Integer | 183,013 |

### Smallest Payload (by bytes)

| Serializer | Person Size | Notes |
|------------|-------------|-------|
| MS Bond Fast | ~400 | Variable encoding |
| MS Bond Compact | ~350 | Compact encoding |
| ProtoBuf | 665 | Fixed schema |
| GroBuf | ~600 | Fast binary |
| NetSerializer | ~600 | General binary |

## Architecture

### ISerDeser Interface

```csharp
public interface ISerDeser
{
    string Name { get; }
    void Initialize(Type primaryType, List<Type> secondaryTypes);
    string Serialize(object obj);
    object Deserialize(string serialized);
    void Serialize(object obj, Stream stream);
    object Deserialize(Stream stream);
}
```

### Adding a Serializer

1. Create class in `src/Serializers/`
2. Implement `ISerDeser`
3. Register in `Program.cs`

## Detailed Documentation

- **[Serializer Reference](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/main/c-sharp/src/Docs/Serializers.md)** — All 38 serializers with descriptions
- **[Result Explanations](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/main/c-sharp/src/Docs/ResultExplanations.md)** — Understanding the output

## Running Benchmarks

```bash
# Smoke test (1 repetition)
./scripts/run-benchmarks.sh smoke

# Verify all serializers
./scripts/run-benchmarks.sh all-single

# Full run (100 repetitions)
./scripts/run-benchmarks.sh full

# Custom (50 reps, Json serializers, Person data)
./scripts/run-benchmarks.sh custom 50 "Json" "Person"
```

## Results

Results are written to:
- `logs/csharp/benchmark-log.csv` — Performance metrics
- `logs/csharp/benchmark-errors.csv` — Failure details

## Docker Support

```bash
# Build
docker build -t csharp-benchmark .

# Run
docker run -v $(pwd)/logs:/app/logs csharp-benchmark smoke
```

## See Also

- [Python Benchmark](../python/index.md) — Cross-language comparison
- [Benchmark Results](../benchmark-results.md) — Interactive dashboard
- [Serializer Formats](../serializers/overview.md) — Format selection guide
