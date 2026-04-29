# Benchmarked Packages Overview

Our benchmark suite evaluates a wide array of serialization libraries across both the C# and Python ecosystems. We categorize these serializers into distinct groups to help you make fair comparisons.

## Serialization Categories

When evaluating performance, it is critical to compare serializers within the same paradigm. Comparing a schema-driven binary format to a dynamic JSON parser is often comparing apples to oranges.

### 1. JSON (Text-based, Schemaless)
These serializers output standard JSON. They are optimized for human readability and web-API interoperability.

- **C#**: `System.Text.Json`, `Newtonsoft.Json`, `Jil`, `Utf8Json`
- **Python**: `json` (built-in), `orjson`, `ujson`, `msgspec`

### 2. Binary (Schemaless / Self-Describing)
These serializers output compact binary data but embed type information or field names directly in the payload, requiring no pre-shared schema.

- **C#**: `MessagePack-CSharp`, `BSON`
- **Python**: `msgpack`, `cbor2`

### 3. Binary (Schema-Driven)
These require a defined schema (like a `.proto` file). They strip out field names and types, relying entirely on the schema to reconstruct the data. They offer the smallest payload sizes and often the fastest speeds.

- **C#**: `Protobuf-net`, `MemoryPack`, `FlatSharp`
- **Python**: `protobuf` (Google), `FlatBuffers`

### 4. Language-Native
These serializers are deeply tied to their specific language runtime and can serialize arbitrary internal objects.

- **C#**: `BinaryFormatter` (Deprecated/Insecure)
- **Python**: `pickle`, `dill`

## High-Level Results Discussion

While the detailed metrics are available in the [Detailed Report](BENCHMARK_SUMMARY.md), the overarching trends are clear:

1. **Schema-Driven Binary dominates throughput.** `MemoryPack` (C#) consistently pushes the boundaries of theoretical memory bandwidth.
2. **Text parsing is a bottleneck.** Even the fastest JSON serializers (like `orjson` in Python) spend significant CPU time executing string-to-integer conversions.
3. **Allocation is the silent killer.** The fastest serializers are those that allocate the fewest objects on the heap, bypassing the Garbage Collector entirely.
