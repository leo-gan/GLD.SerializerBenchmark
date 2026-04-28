# Schema Serializers

Schema serializers require pre-defined schemas (.proto, .avsc, or .bond files) that specify exact data structures, types, and field numbers. They offer the smallest output sizes, fastest deserialization, and strongest compatibility guarantees.

## When to Use Schema Serializers

**Choose schema serializers when:**
- Microservice API contracts are stable and well-defined
- Long-term data storage requires schema evolution
- Mobile backends where payload size affects battery life
- High-throughput streaming (Kafka, Kinesis)
- Cross-platform systems (mobile + web + backend)
- Every byte and nanosecond matters

## Common Characteristics

| Aspect | Value |
|--------|-------|
| **Human-readable** | No |
| **Schema** | Required |
| **Size** | Smallest (2-10× smaller than JSON) |
| **Speed** | Fastest deserialization |
| **Validation** | Compile-time type checking |
| **Evolution** | Forward/backward compatible |

## Format Comparison

| Feature | Protobuf | Avro | Bond | FlatBuffers |
|---------|----------|------|------|-------------|
| **Origin** | Google | Apache | Microsoft | Google |
| **Schema location** | Separate .proto | Embedded in data | Separate .bond | Separate .fbs |
| **Code generation** | Required | Optional | Required | Required |
| **Hadoop/Spark** | Via connectors | Native | Limited | Limited |
| **Best for** | Microservices | Data lakes | .NET ecosystem | Games/real-time |
| **Zero-copy** | No | No | Partial | Yes |

## C# Schema Serializers

| Serializer | Format | Best For | Speed |
|------------|--------|----------|-------|
| **MS Bond Fast** | Bond | .NET microservices | ★★★★★ |
| **MS Bond Compact** | Bond | Balanced size/speed | ★★★★☆ |
| **ProtoBuf** | Protocol Buffers | Cross-language | ★★★★☆ |
| **FlatSharp** | FlatBuffers | Zero-allocation | ★★★★☆ |
| **MS Bond Json** | Bond JSON | Human-readable | ★★★☆☆ |

### Example: MS Bond Fast

```csharp
// Define schema (Person.bond)
// namespace Benchmark
// {
//     struct Person {
//         0: string Name;
//         1: int32 Age;
//     }
// }

// Serialize (after generating C# from schema)
var writer = new CompactBinaryWriter<OutputBuffer>(new OutputBuffer());
Serialize.To(writer, person);
byte[] bytes = writer.Data.Array;

// Deserialize
var reader = new CompactBinaryReader<InputBuffer>(new InputBuffer(bytes));
Person person = Deserialize<Person>.From(reader);
```

### Example: Protocol Buffers

```csharp
// Generated from .proto file
// Serialize
byte[] bytes = person.ToByteArray();

// Deserialize
Person person = Person.Parser.ParseFrom(bytes);
```

## Python Schema Serializers

| Serializer | Format | Best For | Speed |
|------------|--------|----------|-------|
| **protobuf** | Protocol Buffers | Cross-language | ★★★☆☆ |
| **avro** | Avro | Hadoop/Spark pipelines | ★★★☆☆ |

### Example: Protocol Buffers (Python)

```python
from benchmark_data_pb2 import Person

# Serialize
bytes_data = person.SerializeToString()

# Deserialize
person = Person()
person.ParseFromString(bytes_data)
```

### Example: Avro

```python
import fastavro
import io

# Schema defined in .avsc file
schema = {
    'type': 'record',
    'name': 'Person',
    'fields': [
        {'name': 'name', 'type': 'string'},
        {'name': 'age', 'type': 'int'}
    ]
}

# Serialize
buf = io.BytesIO()
fastavro.schemaless_writer(buf, schema, person_dict)
bytes_data = buf.getvalue()

# Deserialize
buf = io.BytesIO(bytes_data)
person = fastavro.schemaless_reader(buf, schema)
```

## Schema Evolution

All schema formats support forward and backward compatibility:

### Adding Fields

```protobuf
// Version 1
message Person {
    string name = 1;
}

// Version 2 - backward compatible
message Person {
    string name = 1;
    int32 age = 2;  // New clients write, old clients ignore
}
```

### Compatibility Rules

| Change | Forward | Backward | Notes |
|--------|---------|----------|-------|
| Add field | ✓ | ✓ | Use default values |
| Remove field | ✗ | ✗ | Reserve field number |
| Rename field | ✓ | ✓ | Field numbers matter |
| Change type | ✗ | ✗ | Use new field number |

## Performance Comparison

### C# Schema Serializers (Person object)

| Serializer | Ops/Sec | Size (bytes) | Time (ns) |
|------------|---------|--------------|-----------|
| MS Bond Fast | 79,563 | ~400 | 12,569 |
| MS Bond Compact | 62,005 | ~350 | 16,128 |
| ProtoBuf | 22,735 | 665 | 43,985 |

### Python Schema Serializers (Person object)

| Serializer | Ops/Sec | Size (bytes) | Notes |
|------------|---------|--------------|-------|
| protobuf | 5,165 | 665 | Code generation required |
| avro | 5,209 | 567 | Self-describing |

*Note: C# Bond significantly outperforms all other options, especially for .NET ecosystems.*

## Schema vs Schemaless Trade-offs

| Aspect | Schema | Schemaless (JSON/msgpack) |
|--------|--------|---------------------------|
| Size | Smallest | Larger |
| Speed | Fastest | Fast |
| Validation | Compile-time | Runtime or none |
| Flexibility | Rigid | Flexible |
| Setup | Higher | Lower |
| Evolution | Planned | Ad-hoc |

## When to Choose Which

| Scenario | Recommendation |
|----------|----------------|
| .NET microservices | MS Bond Fast |
| Cross-language gRPC | Protobuf |
| Hadoop/Spark pipelines | Avro |
| Games/real-time | FlatBuffers (zero-copy) |
| Mobile backends | Protobuf or Bond |
| Schema registry (Kafka) | Avro or Protobuf |

## Defining Schemas

### Protocol Buffers Example

```protobuf
syntax = "proto3";

message Person {
    string name = 1;
    int32 age = 2;
    
    enum Gender {
        UNKNOWN = 0;
        MALE = 1;
        FEMALE = 2;
    }
    Gender gender = 3;
    
    repeated string tags = 4;
    map<string, int32> scores = 5;
}
```

### Bond Example

```bond
namespace Benchmark;

struct Person {
    0: string Name;
    1: int32 Age;
    2: Gender Gender;
    3: vector<string> Tags;
    4: map<string, int32> Scores;
};

enum Gender {
    Unknown = 0,
    Male = 1,
    Female = 2
};
```

## Code Generation

```bash
# Protobuf
cd schemas
protoc --csharp_out=../c-sharp/src/Generated benchmark_data.proto
protoc --python_out=../python/src/benchmark/generated benchmark_data.proto

# Bond
gbc csharp Person.bond --output-dir ../c-sharp/src/Generated
```

## Further Reading

- [Protocol Buffers Guide](https://developers.google.com/protocol-buffers/docs/overview)
- [Microsoft Bond Documentation](https://github.com/microsoft/bond)
- [Apache Avro Specification](https://avro.apache.org/docs/current/spec.html)
- [FlatBuffers Overview](https://google.github.io/flatbuffers/)
