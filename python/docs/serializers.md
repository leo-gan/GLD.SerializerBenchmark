# Python Tested Serializers

This document describes the 10 Python serializers tested in the benchmark suite, organized by category.

## JSON Serializers

JSON (JavaScript Object Notation) serializers convert Python objects to human-readable text format. These are the most interoperable choice for APIs, configuration files, and cross-language data exchange. All JSON serializers in this benchmark use C-extensions (Rust or C) for performance, significantly outperforming Python's standard library `json` module.

**Common Characteristics:**
- **Human-readable:** Output can be inspected with any text editor or HTTP debugging tools
- **Universal support:** Every programming language has JSON parsers
- **Schema-optional:** Can work with any Python object using `default` hooks, but types are not enforced
- **Size overhead:** Text representation is larger than binary formats (typically 2-5x)
- **No circular refs:** JSON cannot represent circular object graphs

**When to Choose JSON:**
- Public APIs requiring broad client compatibility
- Configuration files humans need to edit
- Debugging and logging (human-readable is valuable)
- Web services where bandwidth is not the bottleneck

---

### orjson
**Library:** `orjson`  
**Type:** Binary JSON encoder/decoder  
**Description:** A fast, correct JSON library for Python. Written in Rust, it significantly outperforms standard library `json` and other Python JSON libraries. Supports dataclasses, datetime, UUID, bytes, and numpy arrays natively.

**Key Features:**
- Fastest JSON serializer in the benchmark (3-5x faster than standard library `json`)
- Optional strict UTF-8 enforcement and ASCII output
- Supports indent for pretty-printing
- Handles dataclasses and datetime objects via `default` hook
- Optimized Rust implementation with SIMD operations

**When to Use:**
- High-throughput APIs serving JSON responses
- Data pipelines processing large volumes of JSON
- Microservices requiring low-latency serialization
- Situations where JSON interoperability is required but speed matters

**Pros:**
- **Speed:** Fastest JSON option; significantly outperforms ujson, simplejson, and stdlib
- **Safety:** Strict UTF-8 handling prevents encoding issues
- **Standards compliant:** Produces RFC 8259 compliant JSON
- **Rich type support:** UUID, bytes, datetime, numpy arrays natively

**Cons:**
- **Rust dependency:** Requires compiled extension (no pure-Python fallback)
- **No circular reference support:** Will raise error on circular object graphs
- **Memory:** Higher memory usage than msgspec due to aggressive optimization strategies

**Benchmark Notes:**
- Best performer for small-to-medium objects (270K+ ops/sec on Person)
- Uses `default` hook for dataclass and datetime serialization
- Excludes `ObjectGraph` (circular references) by design
- Output size comparable to standard JSON (no compression)

---

### msgspec
**Library:** `msgspec`  
**Type:** Schema-validated JSON/MessagePack  
**Description:** A fast serialization and validation library, written in C. Supports JSON and MessagePack with zero-copy deserialization. Uses type annotations for schema definition and validation.

**Key Features:**
- Native dataclass support (no custom hooks needed)
- Built-in datetime support (ISO 8601 format)
- Type-safe deserialization with validation
- Low memory footprint
- Zero-copy deserialization for MessagePack
- Also supports JSON and MessagePack from same API

**When to Use:**
- Data validation is as important as serialization speed
- Type safety and runtime validation are required
- Memory-constrained environments
- Applications using both JSON and MessagePack
- Schema-first API design

**Pros:**
- **Memory efficiency:** Lowest memory usage among all serializers in benchmark
- **Type safety:** Validates incoming data against Python type annotations
- **Zero overhead dataclasses:** Native support without conversion functions
- **Dual format:** Same code works with JSON and MessagePack
- **Excellent error messages:** Clear validation failures with path information

**Cons:**
- **Schema required:** Must define types upfront (not schema-free like standard JSON)
- **C extension:** Requires compiled code (though wheels provided for all platforms)
- **Limited dynamic typing:** Less flexible for untyped/dynamic data structures
- **Learning curve:** Different API pattern than standard `json` module

**Benchmark Notes:**
- Excellent memory efficiency (lowest memory usage among JSON serializers ~5KB vs 28KB for orjson)
- Native dataclass support eliminates conversion overhead
- Slightly slower than orjson but significantly faster than standard library
- Excludes `ObjectGraph` by design
- Strong type validation prevents runtime errors

---

### rapidjson
**Library:** `python-rapidjson`  
**Type:** C++ JSON parser  
**Description:** Python wrapper around RapidJSON, a fast C++ JSON parser and generator. Supports standard JSON with optional precise number parsing and validation.

**Key Features:**
- C++ backend based on Tencent's RapidJSON library
- Compliant with RFC 8259
- Supports custom encoders/decoders
- Number precision options (decimal vs float)
- Pretty-printing with customizable indentation

**When to Use:**
- Need RFC-compliant JSON with precise number handling
- Applications requiring decimal precision (financial data)
- Mixed environments with C++ JSON consumers
- Situations where orjson is unavailable

**Pros:**
- **Standards compliant:** Strict RFC 8259 adherence
- **Number precision:** Can preserve decimal precision without floating-point conversion
- **C++ performance:** Faster than pure-Python JSON libraries
- **Mature codebase:** Based on widely-used RapidJSON C++ library

**Cons:**
- **Slower than orjson:** ~10x slower in our benchmarks
- **Verbose API:** Requires manual hook setup for dataclasses
- **Limited type support:** No built-in datetime/dataclass handling
- **Maintenance:** Slower update cadence than orjson

**Benchmark Notes:**
- Requires custom `default` and `object_hook` for dataclasses
- Uses datetime string parsing in hooks (manual conversion)
- 3x slower than msgspec, 10x slower than orjson
- Excludes `ObjectGraph` by design
- Good choice when precise decimal handling is critical

---

## Binary Serializers

Binary serializers convert Python objects to compact byte representations. They sacrifice human readability for significant improvements in size (20-50% smaller than JSON) and parsing speed (no string parsing overhead). Both MessagePack and CBOR are schemaless like JSON but encode data in binary form.

**Common Characteristics:**
- **Compact size:** Binary encoding removes text formatting overhead
- **Fast parsing:** No string tokenization; direct byte interpretation
- **Cross-language:** Wide support across programming languages
- **Type preservation:** Better handling of binary data, datetime, and numeric types
- **Not human-readable:** Requires hex dumps or specialized tools to inspect

**Binary vs JSON Trade-offs:**

| Aspect | Binary (msgpack/CBOR) | JSON |
|--------|----------------------|------|
| Size | Smaller (~30-50%) | Larger |
| Speed | Faster parsing | Slower (text parsing) |
| Readability | None | Human-readable |
| Debugging | Harder | Easier |
| Schema | None | None |

**When to Choose Binary:**
- Internal microservices where you control all endpoints
- High-throughput data pipelines
- Caching layers (Redis with binary values)
- Mobile apps where bandwidth matters

---

### msgpack
**Library:** `msgpack`  
**Type:** Binary serialization format  
**Description:** MessagePack is an efficient binary serialization format that exchanges data among multiple languages like JSON but is faster and smaller. It supports rich data types including datetime and binary data.

**Key Features:**
- Compact binary representation (typically 20-50% smaller than JSON)
- Cross-language compatible (50+ language implementations)
- Supports streaming (unpack from file-like objects)
- Custom type support via `default` and `object_hook`
- Handles binary data natively (no base64 encoding needed)
- Extensible type system

**When to Use:**
- Network protocols where bandwidth matters
- Caching systems (Redis, Memcached)
- Microservices communicating internally
- Storing structured data in binary columns
- Replacing JSON for internal APIs

**Pros:**
- **Compact size:** Significantly smaller than JSON for most data
- **Speed:** Faster parsing than JSON (no string parsing overhead)
- **Binary data:** Native support for bytes without encoding overhead
- **Rich ecosystem:** Widely supported across languages and platforms
- **Streaming:** Can unpack from streams without loading entire message

**Cons:**
- **Not human-readable:** Cannot debug with standard text tools
- **No schema:** No built-in validation (unlike protobuf/avro)
- **Type loss:** Python tuples become lists, custom types need hooks
- **Security:** Like pickle, can deserialize arbitrary objects if not careful

**Benchmark Notes:**
- Smaller output size than JSON (especially for numeric data: 1,631 bytes vs 1,730 for Person)
- Uses `default`/`object_hook` for dataclass conversion
- Memory allocation higher due to internal buffering strategies
- Excludes `ObjectGraph` (circular references) by design

---

### cbor2
**Library:** `cbor2`  
**Type:** CBOR (Concise Binary Object Representation)  
**Description:** CBOR is a binary serialization format specified in RFC 8949. Designed to be small, schema-free, and extensible. Version 6.0+ is a major rewrite in Rust, offering significantly improved performance and memory safety.

**Key Features:**
- IETF standard (RFC 8949) - formally specified
- Smaller than MessagePack for some data types
- Native datetime support (using CBOR tags 0 and 1)
- Streaming support via file-like objects
- Supports indefinite-length arrays/maps
- Extensible with custom tags

**When to Use:**
- IETF-compliant protocols requiring standard binary format
- Constrained environments (IoT, embedded)
- Situations where CBOR is mandated (some government/military specs)
- Streaming large data structures

**Pros:**
- **Standardized:** RFC 8949 ensures long-term compatibility
- **Datetime native:** Built-in support without custom hooks
- **Streaming:** Better support for indefinite-length data
- **Flexible:** Tags system allows rich type extensions
- **Smallest binary:** Often beats MessagePack on size

**Cons:**
- **Less popular:** Smaller ecosystem than MessagePack
- **Complex API:** Hook signatures and configuration (like timezone handling) differ from other libraries
- **Overhead:** Enabling circular reference support (value sharing) adds a performance cost
- **Learning curve:** Less documentation and community examples compared to JSON/msgpack

**Comparison with MessagePack:**
| Feature | CBOR | MessagePack |
|---------|------|-------------|
| Standard | IETF RFC 8949 | No formal RFC |
| Datetime | Native tags | Extension type |
| Streaming | Indefinite length | Chunks |
| Speed | Fast (Rust) | Faster (C) |
| Popularity | Growing | Very popular |

**Benchmark Notes:**
- Requires careful encoder/decoder hook setup (different signature than msgpack)
- Supports circular references via `value_sharing=True` (disabled by default for performance)
- Uses native CBOR tags for `datetime` (requires timezone-aware objects or explicit timezone setting)
- Much improved performance in 6.0+ due to Rust backend
- Excludes `ObjectGraph` in this benchmark due to the added complexity of cyclic object reconstruction

---

## Schema Serializers

Schema serializers require pre-defined schemas (.proto or .avsc files) that specify the exact structure, types, and field numbers of data. They offer the smallest output sizes, fastest deserialization, and strongest compatibility guarantees at the cost of up-front schema design and code generation.

**Common Characteristics:**
- **Smallest output:** Binary with field numbers instead of field names (2-10x smaller than JSON)
- **Schema enforcement:** Types checked at build time, not runtime
- **Evolution support:** Forward/backward compatible changes via field numbering
- **Code generation:** Schema changes require regenerating Python classes
- **No bare primitives:** Cannot serialize standalone integers/strings (must be message fields)

**Schema vs Schemaless Trade-offs:**

| Aspect | Schema (protobuf/avro) | Schemaless (JSON/msgpack) |
|--------|----------------------|---------------------------|
| Size | Smallest | Larger |
| Validation | Compile-time | Runtime or none |
| Flexibility | Rigid (schema changes) | Flexible (any structure) |
| Interop | Excellent (code gen) | Good (dynamic) |
| Initial setup | Higher (schema files) | Lower |

**When to Choose Schema Serializers:**
- Microservices with stable, well-defined APIs
- Long-term data storage requiring evolution
- Mobile backends where payload size affects battery life
- High-throughput streaming (Kafka, Kinesis)
- Cross-platform systems (mobile + web + backend)

---

### protobuf
**Library:** `protobuf`  
**Type:** Binary protocol buffers  
**Description:** Google's Protocol Buffers is a language-neutral, platform-neutral, extensible mechanism for serializing structured data. Requires pre-defined `.proto` schemas.

**Key Features:**
- Schema enforcement via `.proto` files
- Extremely compact binary output (smallest among all serializers)
- Cross-language compatibility (20+ languages)
- Forward/backward compatibility with field numbering
- Efficient packed repeated fields
- Versioned schemas (proto2, proto3, proto3 optional)

**When to Use:**
- Microservice communication (gRPC uses protobuf)
- Long-term data storage requiring schema evolution
- Cross-platform mobile app backends
- High-throughput streaming data pipelines
- Situations where every byte matters

**Pros:**
- **Smallest output:** Consistently smallest serialized size (665 bytes for Person)
- **Fast deserialization:** Binary format parsed efficiently
- **Schema evolution:** Add/remove fields without breaking old readers
- **Type safety:** Generated code provides IDE autocomplete and type checking
- **Ecosystem:** Massive adoption, excellent tooling (protoc, linters, docs)

**Cons:**
- **Schema maintenance:** Requires `.proto` files and code generation step
- **No bare primitives:** Cannot serialize standalone integers/strings
- **Generated code:** Must regenerate when schema changes
- **Build complexity:** Additional build step in CI/CD
- **Learning curve:** Different type system than Python

**Technical Details:**
```protobuf
// Datetime handling: converts to int64 milliseconds since epoch
int64 created_at_ms = timestamp_ms(datetime)

// Enums stored as integers (not names)
Gender.MALE = 0, Gender.FEMALE = 1

// Maps to dicts, repeated to lists
map<string, int32> metadata = 5;
repeated string tags = 6;
```

**Benchmark Notes:**
- Requires generated Python code from `.proto` files
- Converts datetimes to milliseconds since epoch (truncates microseconds)
- Enum values serialized as integers (not strings)
- **Excludes:** `Integer` (bare primitives not supported) and `ObjectGraph` (circular refs)
- Best size-to-speed ratio for schema-based serialization

---

### avro
**Library:** `fastavro`  
**Type:** Binary Avro format  
**Description:** Apache Avro is a row-oriented remote procedure call and data serialization framework. Uses schemas for data structures and types. Schema is stored with the data for self-description.

**Key Features:**
- Schema included with data (self-describing)
- Rich type system including unions (null, multiple types)
- Efficient binary encoding with code generation
- Schema evolution with default values
- Hadoop ecosystem integration (Spark, Hive, etc.)
- RPC support (Avro RPC, though less common now)

**When to Use:**
- Hadoop/Spark data pipelines
- Data lakes requiring schema-on-read
- Streaming platforms (Kafka with Schema Registry)
- Long-term archival with embedded schemas
- Situations needing schema evolution without code regeneration

**Pros:**
- **Self-describing:** Schema travels with data (unlike protobuf)
- **Hadoop native:** First-class support in big data ecosystem
- **No code gen needed:** Can use dynamic schemas at runtime
- **Rich types:** Unions, maps, arrays with null support
- **Schema registry:** Confluent Schema Registry integration for Kafka

**Cons:**
- **Slower than protobuf:** Self-describing overhead impacts speed
- **Java-centric:** Best tooling and support in JVM ecosystem
- **Complex schemas:** JSON Schema syntax can be verbose
- **Dynamic overhead:** Runtime schema validation slower than generated code
- **Smaller ecosystem:** Fewer language implementations than protobuf

**Comparison with Protobuf:**
| Feature | Avro | Protobuf |
|---------|------|----------|
| Schema location | In data | Separate .proto file |
| Code generation | Optional | Required |
| Hadoop/Spark | Native | Via connectors |
| Size | Small | Smallest |
| Speed | Fast | Faster |
| Schema evolution | Yes | Yes |
| Null support | First-class | Via wrappers |

**Benchmark Notes:**
- Uses `fastavro` library for performance (C extensions)
- Datetimes converted to milliseconds (truncates microseconds)
- Schemas defined in `.avsc` JSON files
- **Excludes:** `Integer` (bare primitives) and `ObjectGraph` (circular refs)
- Output size: 567 bytes (Person) - slightly larger than protobuf's 665 bytes
- Good choice for data lakes, protobuf for microservices

---

## Python-Native Serializers

Python-native serializers are designed exclusively for Python-to-Python communication. They can serialize virtually any Python object including functions, classes, lambdas, and circular references—something no cross-language format can achieve. However, they carry significant security risks and cannot share data with non-Python systems.

**Common Characteristics:**
- **Universal Python support:** Handles any Python object automatically
- **Circular reference handling:** Native support for object graphs with cycles
- **No schema needed:** Zero setup for custom classes
- **Security risk:** Can execute arbitrary code during deserialization
- **Python-only:** No interoperability with other languages

**⚠️ Critical Security Warning:**
Both `pickle` and `cloudpickle` can execute arbitrary Python code during deserialization. **Never unpickle data from untrusted sources.** This includes:
- User-uploaded files
- Data from unauthenticated API endpoints
- Cookies or session data from web requests
- Cache entries from shared cache servers

**When to Choose Python-Native:**
- Internal caching (memoization, Redis with pickle)
- Python multiprocessing (Queue, Pool)
- Machine learning model serialization
- Deep copying complex objects
- Distributed computing (Dask, Ray)

**When NOT to Use:**
- Public APIs or data exchange
- Persisting user data long-term
- Any data that might come from untrusted sources

---

### pickle
**Library:** `pickle` (standard library)  
**Type:** Python-specific binary serialization  
**Description:** Python's native serialization format. Can serialize nearly any Python object including custom classes, functions, and circular references.

**Key Features:**
- Native Python object support (no conversion needed)
- Handles circular references automatically (only serializer with native support)
- Supports all Python types including lambdas, nested functions, and metaclasses
- Multiple protocol versions (0-5, with 5 being highest for Python 3.8+)
- Optimized for Python object graphs

**When to Use:**
- Caching Python objects in memory (memoization)
- Session storage for Python web applications (trusted environment)
- Machine learning model persistence (sklearn, PyTorch)
- Temporary serialization between Python processes (multiprocessing)
- Deep copying complex object hierarchies

**⚠️ Security Warning:**
**NEVER unpickle data from untrusted sources.** Pickle can execute arbitrary code during deserialization. Malicious payloads can compromise your system. Use only for:
- Data you created yourself
- Data from authenticated, trusted sources
- Internal service communication within secure networks

For untrusted data, use JSON, MessagePack, or protobuf.

**Pros:**
- **Universal:** Handles ANY Python object automatically
- **Circular refs:** Only native solution for circular object graphs
- **No schema:** Zero setup for custom classes
- **Fast:** No conversion overhead for Python objects
- **Built-in:** No external dependencies

**Cons:**
- **Security risk:** Arbitrary code execution during deserialization
- **Python-only:** Cannot share data with other languages
- **Version sensitive:** Protocol changes between Python versions
- **Large output:** Not optimized for size (1,321 bytes for Person)
- **No streaming:** Must load entire pickle at once

**Protocol Versions:**
| Protocol | Python | Features |
|----------|--------|----------|
| 0 | All | Human-readable (ASCII) |
| 1 | All | Binary |
| 2 | 2.3+ | New-style classes |
| 3 | 3.0+ | Python 3 types |
| 4 | 3.4+ | Large objects, framing |
| 5 | 3.8+ | Out-of-band buffers |

**Benchmark Notes:**
- Fastest for complex Python objects (no conversion overhead)
- Only serializer besides cloudpickle that handles `ObjectGraph` circular refs
- Fidelity: 1.00 on all supported types
- **Security:** Only unpickle data you trust (arbitrary code execution risk)

---

### cloudpickle
**Library:** `cloudpickle`  
**Type:** Extended pickle for distributed computing  
**Description:** An extended version of pickle that can serialize objects that the standard pickle cannot, such as functions with closures, classes defined in `__main__`, and dependencies on external modules.

**Key Features:**
- Extends pickle for distributed/cloud computing
- Serializes functions and classes defined in `__main__` (interactive sessions)
- Handles dynamic module dependencies
- Drop-in replacement for pickle (same API)
- Supports closures and dynamically defined functions
- Used internally by Dask, Ray, and Apache Spark

**When to Use:**
- Distributed computing frameworks (Dask, Ray, PySpark)
- Jupyter notebook serialization (functions defined in `__main__`)
- Sending Python objects to remote workers
- Machine learning pipelines with dynamic functions
- Interactive development workflows

**⚠️ Security Warning:**
Same security concerns as pickle - can execute arbitrary code. Only use with trusted data sources.

**Pros:**
- **Interactive support:** Can pickle functions defined in Jupyter/IPython
- **Distributed computing:** Used by major frameworks (Dask, Ray)
- **Closure support:** Serializes functions with captured variables
- **Drop-in:** Replace `import pickle` with `import cloudpickle`
- **Dynamic imports:** Handles modules not available at unpickling time

**Cons:**
- **Slower than pickle:** Additional introspection overhead
- **Larger output:** More metadata for dynamic objects
- **Same security issues:** Arbitrary code execution risk
- **Python-only:** No cross-language support
- **External dependency:** Not in standard library

**Pickle vs Cloudpickle:**
| Feature | Pickle | Cloudpickle |
|---------|--------|-------------|
| `__main__` functions | ❌ | ✅ |
| Closures | Limited | ✅ |
| Standard library | ✅ | ❌ |
| Speed | Faster | Slower |
| Size | Smaller | Larger |
| Security | Same risk | Same risk |

**Benchmark Notes:**
- Slightly slower than pickle (~30% slower in our tests)
- Handles `ObjectGraph` circular references (same as pickle)
- Larger output size than pickle for some objects (same 1,321 bytes for Person)
- Designed for sending Python objects between processes/machines
- Best choice for distributed/interactive Python computing

---

## Summary Table

| Serializer | Category | Speed | Size | Circular Refs | Schema Required | Cross-Language |
|-----------|----------|-------|------|---------------|-------------------|----------------|
| orjson | JSON | ★★★★★ | ★★★☆☆ | No | No | Yes |
| msgspec | JSON | ★★★★☆ | ★★★☆☆ | No | Optional | Yes |
| rapidjson | JSON | ★★★☆☆ | ★★★☆☆ | No | No | Yes |
| msgpack | Binary | ★★★★☆ | ★★★★☆ | No | No | Yes |
| cbor2 | Binary | ★★★☆☆ | ★★★★★ | No | No | Yes |
| protobuf | Schema | ★★★☆☆ | ★★★★★ | No | Yes | Yes |
| avro | Schema | ★★★☆☆ | ★★★★★ | No | Yes | Yes |
| pickle | Native | ★★★★☆ | ★★★☆☆ | Yes | No | No |
| cloudpickle | Native | ★★★☆☆ | ★★★☆☆ | Yes | No | No |

**Legend:** ★ = Poor, ★★ = Fair, ★★★ = Good, ★★★★ = Very Good, ★★★★★ = Excellent
