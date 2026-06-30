# Serialization Categories

When evaluating performance, compare serializers within the same paradigm. Comparing a schema-driven binary format to a dynamic JSON parser is often apples-to-oranges.

This page lists categories as used in **this suite**. Examples are libraries **registered in the harnesses**, not the entire ecosystem.

### 1. JSON (Text-based, Schemaless)

Optimized for human readability and web-API interoperability.

- **C#**: `Json.Net`, `JsonNetHelper`, `Jil`, `NetJSON`, `SpanJson`, `Utf8Json`, `FastJson`, `ServiceStack` JSON, `DataContractJson`, Bond JSON (`MS Bond Json`)
- **Python**: `orjson`, `msgspec`, `rapidjson`
- **Rust**: `serde_json`, `simd-json`, `sonic-rs`
- **C**: `cJSON`, `yyjson`, `jansson`, `parson` (CI build may use portable stand-ins — see [C overview](../c/index.md))
- **JavaScript**: `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional native)

### 2. Binary (Schemaless)

Compact binary with type tags / field names in the payload; no pre-shared schema required.

- **C#**: `MS Binary` (BinaryFormatter), `Ceras`, `Hyperion`, `NetSerializer`, `BinaryPack`, `GroBuf`, `Migrant`, `Apex.Serialization`, FsPickler binary, ServiceStack type serializer
- **Python**: `msgpack`, `msgspec-msgpack`, `cbor2`
- **Rust**: `rmp-serde`, `ciborium`, `bincode`, `postcard`, `bitcode`, `minicbor`
- **C**: `mpack`, `tinycbor`, `ubj`, `cbor-encode`, `custom-binary`
- **JavaScript**: `msgpackr`, `@msgpack/msgpack`, `cbor-x`, `cbor`, `bson`, `bser`

### 3. Binary (Schema-Driven / Schema-ish)

Schema, IDL, or fixed layout (field numbers, FlexBuffers, etc.).

- **C#**: protobuf-net (`ProtoBuf`), `Google.Protobuf`, Bond Fast/Compact, `FlatSharp`, `MemoryPack`, `ZeroFormatter`
- **Python**: `protobuf`, `avro` (fastavro)
- **Rust**: `flexbuffers`, `prost-wire` (envelope stand-in; see Rust caveats)
- **C**: `nanopb`, `protobuf-c`, `flatcc` (default build: tagged envelopes)
- **JavaScript**: `avsc`, `protobufjs`

### 4. Language-Native

Tied to one runtime; often supports cycles and arbitrary objects.

- **C#**: legacy binary / graph-capable serializers where supported (see C# tested list)
- **Python**: `pickle`, `cloudpickle`
- **JavaScript**: `v8-serializer`
- **Rust / C**: no pickle-equivalent in this suite; `ObjectGraph` is skipped for most formats

## High-Level Results Discussion

Detailed metrics belong in generated reports under `reports/` (and copies such as [violin plots](violin-plots.md)). Overarching trends observed in this project:

1. **Schema-driven binary** often wins on size and throughput within a language.
2. **Text parsing** remains a bottleneck even for fast JSON libraries.
3. **Allocation** (GC / heap churn) dominates at high throughput on managed runtimes.
4. **Cross-language rankings are not interchangeable** — compare within language first, then formats.

For format-level trade-offs (when to choose JSON vs MessagePack vs Protobuf), see the [Selection Guide](../serializers/index.md) (concepts). For **what we actually measure**, use each language overview under `docs/<lang>/index.md`.
