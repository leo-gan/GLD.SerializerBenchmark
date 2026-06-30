# Selection Guide: Overview

> **Concepts vs what we measure:** This section describes *formats and trade-offs* in general. For libraries actually registered in harnesses, use [Serialization Categories](../analysis/serialization_categories.md) and each language’s tested-serializers page under `docs/<lang>/`.

Choosing the right format involves trade-offs between speed, size, compatibility, and human readability.

## Format Comparison Matrix

| Format | Schema | Human-Readable | Size | Speed | Cross-Language | Best For |
|--------|--------|----------------|------|-------|----------------|----------|
| **JSON** | Optional | Yes | Large | Medium | Universal | APIs, configs |
| **MessagePack** | Optional | No | Small | Fast | Wide | Internal services |
| **CBOR** | Optional | No | Small | Medium | Growing | IoT, standards |
| **Protobuf** | Required | No | Smallest | Fastest | Universal | Microservices |
| **Avro** | Required | No | Small | Fast | Hadoop/Spark | Data lakes |
| **FlatBuffers** | Required | No | Small | Fastest | Wide | Games, real-time |
| **Bond** | Required | No | Small | Fastest | Microsoft | .NET ecosystem |
| **Pickle** | None | No | Medium | Fast | Python-only | Caching, ML |

## When to Choose Each Format

### JSON

**Use when:**
- Building public APIs
- Humans need to read/debug the data
- Cross-language compatibility is required
- Schema flexibility is valued over performance

**Trade-offs:**
- + Human readable
- + Universal support
- − Large payload size
- − No circular reference support

See [JSON Serializers](./json.md) for library-specific guidance.

### Binary (MessagePack/CBOR)

**Use when:**
- Internal microservices communication
- Caching (Redis, Memcached)
- Bandwidth is constrained
- You want JSON-like flexibility with better performance

**Trade-offs:**
+ Smaller than JSON (20-50%)
+ Faster parsing
+ Cross-language support
− Not human readable
− No schema validation

See [Binary Serializers](./binary.md) for detailed comparison.

### Schema (Protobuf/Avro/Bond)

**Use when:**
- API contracts are stable
- Maximum performance is required
- Long-term data storage with evolution
- Mobile backends (battery life matters)
- High-throughput streaming (Kafka)

**Trade-offs:**
+ Smallest payload size
+ Fastest serialization
+ Schema evolution support
+ Type safety at build time
− Requires schema maintenance
− Upfront design cost

See [Schema Serializers](./schema.md) for implementation patterns.

### Native (Pickle/Cloudpickle)

**Use when:**
- Python-only environment
- Caching Python objects
- Distributed computing (Dask, Ray)
- Machine learning model serialization
- Circular references present

**Trade-offs:**
+ Handles any Python object
+ Circular reference support
+ Zero setup
− **Security risk** (arbitrary code execution)
− Python-only

## Decision Flowchart

```
Need human-readable output?
├── YES → JSON
│         └── Need maximum speed?
│               ├── YES → orjson (Python) / SpanJson (C#)
│               └── NO  → Standard library OK
│
└── NO → Cross-language required?
         ├── NO  → Pickle (Python only)
         │
         └── YES → Schema stability?
                   ├── YES → Schema-based (Protobuf/Avro/Bond)
                   │         └── .NET ecosystem?
                   │                 ├── YES → MS Bond Fast
                   │                 └── NO  → Protobuf
                   │
                   └── NO  → Binary schemaless (MessagePack/CBOR)
                             └── Need standards compliance?
                                   ├── YES → CBOR (RFC 8949)
                                   └── NO  → MessagePack
```

## Performance vs Flexibility Spectrum

```
Flexibility ◄────────────────────────────────────────► Performance

JSON ──── MessagePack ──── CBOR ──── Protobuf ──── Bond/FlatBuffers
  │            │             │            │            │
  │            │             │            │            └─ Fastest, strict schema
  │            │             │            └─ Fast, compact, wide support
  │            │             └─ Standardized binary
  │            └─ Flexible binary
  └─ Most flexible, slowest
```

## Language-Specific Guides (what we measure)

Inventories live on each language overview:

- **[C#](../c-sharp/index.md)** — 38 registered serializers (not MessagePack-CSharp / System.Text.Json / Wire)
- **[Python](../python/index.md)** — 10 serializers
- **[Rust](../rust/index.md)** — 12 crates
- **[C](../c/index.md)** — 12 named codecs (portable stand-ins in default CI build)
- **[JavaScript](../javascript/index.md)** — 11–12 (simdjson optional)

## References

- [JSON Specification (RFC 8259)](https://tools.ietf.org/html/rfc8259)
- [Protocol Buffers](https://developers.google.com/protocol-buffers)
- [MessagePack](https://msgpack.org/)
- [CBOR (RFC 8949)](https://tools.ietf.org/html/rfc8949)
- [Apache Avro](https://avro.apache.org/)
- [Microsoft Bond](https://github.com/microsoft/bond)
- [FlatBuffers](https://google.github.io/flatbuffers/)
