# Binary Serializers

Binary formats sacrifice human readability for significant improvements in size (20-50% smaller than JSON) and parsing speed.

## When to Use Binary

**Choose binary when:**
- Internal microservices where you control all endpoints
- High-throughput data pipelines
- Caching layers (Redis with binary values)
- Mobile apps where bandwidth affects battery life
- Network protocols where every byte matters

## Common Characteristics

| Aspect | Value |
|--------|-------|
| **Human-readable** | No |
| **Schema** | Optional |
| **Size** | 30-50% smaller than JSON |
| **Speed** | Faster than JSON |
| **Debugging** | Requires hex dumps or tools |

## Format Comparison

| Feature | MessagePack | CBOR |
|---------|-------------|------|
| **Standard** | De facto standard | IETF RFC 8949 |
| **Speed** | Faster (C extensions) | Slower (pure Python) |
| **Size** | Small | Often smallest |
| **Datetime** | Extension type | Native tags |
| **Streaming** | Chunks | Indefinite length |
| **Popularity** | Very high | Growing |

## C# Binary Serializers

| Serializer | Format | Best For | Speed |
|------------|--------|----------|-------|
| **GroBuf** | Custom binary | Maximum speed | ★★★★★ |
| **MS Bond Fast** | Bond | .NET ecosystem | ★★★★★ |
| **MS Bond Compact** | Bond | Balanced | ★★★★☆ |
| **MemoryPack** | Custom | Zero-copy | ★★★★☆ |
| **NetSerializer** | Custom | General use | ★★★★☆ |
| **FlatSharp** | FlatBuffers | Zero-allocation | ★★★★☆ |
| **ProtoBuf** | Protocol Buffers | Cross-language | ★★★★☆ |
| **MessagePack-CSharp** | MessagePack | Wide support | ★★★★☆ |
| **Hyperion** | Custom | Akka.NET | ★★★☆☆ |
| **Ceras** | Custom | Ease of use | ★★★☆☆ |
| **Migrant** | Custom | Complex graphs | ★★☆☆☆ |
| **FsPickler** | Custom | F# integration | ★★★☆☆ |
| **MS Binary** | BinaryFormatter legacy | Legacy only | ★★☆☆☆ |

### Example: MemoryPack

```csharp
// Serialize to byte array
byte[] bytes = MemoryPackSerializer.Serialize(person);

// Deserialize
Person person = MemoryPackSerializer.Deserialize<Person>(bytes);
```

### Example: MessagePack

```csharp
// Serialize
byte[] bytes = MessagePackSerializer.Serialize(person);

// Deserialize
Person person = MessagePackSerializer.Deserialize<Person>(bytes);
```

## Python Binary Serializers

| Serializer | Format | Best For | Speed |
|------------|--------|----------|-------|
| **msgpack** | MessagePack | Speed + ecosystem | ★★★★☆ |
| **cbor2** | CBOR | Standards compliance | ★★★☆☆ |

### Example: msgpack

```python
import msgpack

# Serialize
packed = msgpack.packb(person, use_bin_type=True)

# Deserialize
person = msgpack.unpackb(packed, raw=False)
```

### Example: cbor2

```python
import cbor2

# Serialize (handles datetime natively)
encoded = cbor2.dumps(person, datetime_as_timestamp=True)

# Deserialize
person = cbor2.loads(encoded)
```

## Performance Comparison

### C# Binary Leaders

| Serializer | Ops/Sec (Person) | Size (Person) |
|------------|------------------|-----------------|
| MS Bond Fast | 79,563 | ~400 bytes |
| NetSerializer | 35,785 | ~600 bytes |
| MemoryPack | 59,444* | ~500 bytes* |
| ProtoBuf | 22,735 | 665 bytes |

*MemoryPack: tested on SimpleObject (Person not supported in benchmark)

### Python Binary

| Serializer | Ops/Sec (Person) | Size (Person) |
|------------|------------------|-----------------|
| msgpack | 2,658 | 1,631 bytes |
| cbor2 | 2,113 | ~1,400 bytes |

*Note: C# binary serializers generally outperform Python due to value types and struct optimizations.*

## Binary vs JSON Trade-offs

| Aspect | Binary (MessagePack) | JSON |
|--------|---------------------|------|
| Size | 30-50% smaller | Larger |
| Speed | Faster parsing | Slower (text parsing) |
| Readability | None | Human-readable |
| Debugging | Harder | Easier |
| Schema | None | None |
| Cross-language | Wide support | Universal |

## Type Handling

### MessagePack Type Mapping

| Python/C# | MessagePack | Notes |
|-----------|-------------|-------|
| int | Integer | Variable encoding |
| float | Float | IEEE 754 |
| str/string | String | UTF-8 |
| bytes/byte[] | Binary | Native support |
| list/List | Array | Variable length |
| dict/Dictionary | Map | Key-value pairs |
| datetime | Extension | Needs custom handling |
| tuple | Array | Becomes list in Python |

### CBOR Type Mapping

| Type | CBOR | Notes |
|------|------|-------|
| int | Integer | Smaller encoding than MessagePack |
| float | Float/IEEE 754 | Multiple precision options |
| str | Text string | UTF-8 |
| bytes | Byte string | Native |
| datetime | Tag 0/1 | Native support |
| array | Array | Definite/indefinite length |

## When to Choose Which

| Scenario | Recommendation |
|----------|----------------|
| Maximum speed | MessagePack (C#) or GroBuf |
| Standards compliance | CBOR (RFC 8949) |
| IoT/embedded | CBOR (smallest) |
| Existing ecosystem | MessagePack (more libraries) |
| Streaming large data | CBOR (indefinite length) |

## Security Considerations

- **MessagePack**: Can deserialize arbitrary objects if `object_hook` is misused
- **CBOR**: Similar risks with custom decoders
- **Best practice**: Use default safe modes, validate after deserialization

## Further Reading

- [MessagePack Specification](https://msgpack.org/)
- [CBOR RFC 8949](https://tools.ietf.org/html/rfc8949)
- [Schema Serializers](./schema.md) — For even smaller size and faster speed
