# JSON Serializers

JSON (JavaScript Object Notation) is the most interoperable serialization format, supported by virtually every programming language.

## When to Use JSON

**Choose JSON when:**
- Building public APIs requiring broad client compatibility
- Configuration files humans need to edit
- Debugging and logging (human readability valuable)
- Web services where bandwidth is not the bottleneck
- Cross-language data exchange required

## Common Characteristics

| Aspect | Value |
|--------|-------|
| **Human-readable** | Yes |
| **Schema** | Optional (JSON Schema available) |
| **Size** | 2-5× larger than binary |
| **Circular references** | Not supported |
| **Binary data** | Requires base64 encoding |

## C# JSON Serializers

| Serializer | Best For | Speed | Notes |
|------------|----------|-------|-------|
| **SpanJson** | Maximum JSON speed | ★★★★☆ | UTF-8 focused, struct-based |
| **Jil** | Fast, simple | ★★★★☆ | Sigil-based, limited maintenance |
| **Utf8Json** | Fast, modern | ★★★★☆ | UTF-8 optimized |
| **NetJSON** | Fast reflection | ★★★★☆ | No attributes needed |
| **Json.NET** | Flexibility | ★★★☆☆ | Industry standard, feature-rich |
| **MS DataContract Json** | WCF compatibility | ★★★☆☆ | Built-in |
| **ServiceStack Json** | ServiceStack ecosystem | ★★★☆☆ | Integrated with framework |
| **fastJson** | Speed claims | ★★★☆☆ | Verify with your data |
| **SharpYaml** | YAML/JSON hybrid | ★☆☆☆☆ | YAML serializer with JSON support |
| **YAXLib** | XML-focused | ★☆☆☆☆ | Primarily XML |

### Example: Json.NET

```csharp
// Serialize
string json = JsonConvert.SerializeObject(person);

// Deserialize
Person person = JsonConvert.DeserializeObject<Person>(json);
```

### Example: SpanJson

```csharp
// Serialize to byte array (UTF-8)
byte[] json = JsonSerializer.Generic.Utf8.Serialize(person);

// Deserialize
Person person = JsonSerializer.Generic.Utf8.Deserialize<Person>(json);
```

## Python JSON Serializers

| Serializer | Best For | Speed | Notes |
|------------|----------|-------|-------|
| **orjson** | Maximum JSON speed | ★★★★★ | Rust-based, SIMD, fastest option |
| **msgspec** | Speed + validation | ★★★★☆ | C-based, schema optional |
| **rapidjson** | RFC compliance | ★★★☆☆ | C++ RapidJSON wrapper |

### Example: orjson

```python
import orjson

# Serialize (returns bytes)
json_bytes = orjson.dumps(person)

# Deserialize
person = orjson.loads(json_bytes)
```

### Example: msgspec

```python
import msgspec

# Define schema (optional but recommended)
encoder = msgspec.json.Encoder()
decoder = msgspec.json.Decoder(Person)

# Serialize
json_bytes = encoder.encode(person)

# Deserialize with validation
person = decoder.decode(json_bytes)
```

## Performance Comparison

| Data Type | C# Best (SpanJson) | Python Best (orjson) | Winner |
|-----------|-------------------|---------------------|--------|
| Integer | ~129K ops/sec | ~488K ops/sec | Python |
| SimpleObject | ~34K ops/sec | ~209K ops/sec | Python |
| Person | ~23K ops/sec | ~60K ops/sec | Python |

*Note: Python's orjson/msgspec significantly outperform C# JSON serializers due to highly optimized Rust/C implementations.*

## Type Handling

### C# Type Support

| Type | Json.NET | SpanJson | Jil |
|------|----------|----------|-----|
| POCOs | ✓ | ✓ | ✓ |
| Dictionaries | ✓ | ✓ | ✓ |
| DateTime | ISO 8601 | ISO 8601 | ISO 8601 |
| Enums | As string/int | As int | As int |
| Nullable | ✓ | ✓ | ✓ |
| Polymorphism | ✓ | ✗ | ✗ |

### Python Type Support

| Type | orjson | msgspec | rapidjson |
|------|--------|---------|-----------|
| Dataclasses | Via `default` | Native | Via `default` |
| Datetime | Native | Native | Via hook |
| UUID | Native | ✗ | ✗ |
| Bytes | Native | ✗ | Via hook |
| Numpy | Native | ✗ | ✗ |

## Security Considerations

- **JSON is safe** — deserialization cannot execute arbitrary code
- **Validate input** — schema validation prevents injection attacks
- **Size limits** — protect against massive payloads causing OOM

## Further Reading

- [C# Serializer Details](../c-sharp/index.md)
- [Python Serializer Details](../python/index.md)
- [JSON Specification (RFC 8259)](https://tools.ietf.org/html/rfc8259)
