# Serialization categories

This page introduces the **four families** this suite uses when grouping serializers, a short decision sketch, and **examples from the suite** by family.

Theory pages cover product trade-offs in more depth. Language **Overview** pages list every registered library name and caveats.

| If you need… | Go here |
|--------------|---------|
| Conceptual trade-offs (product / theory) | [Theory — engineering](../theory/101/engineer_perspective.md) · [101 home](../theory/101/index.md) |
| Full registered names and caveats | Language **Overview** pages |
| Timings and plots | [Dashboard](../dashboard/) |

---

## Learning goals

By the end of this page you should be able to:

1. Name the four families and one real example of each.
2. Decide which family fits a simple product question (public API, schema contract, same-process cache, …).
3. State the comparison rule: **same language + same family** before crowning a winner.

**Rule of thumb:** compare serializers **within the same paradigm** and **within one language**. Cross-language and cross-paradigm “winners” are not interchangeable.

Registered counts (Overview source of truth): C# **36** · Python **16** · Rust **15** · C **20** · JavaScript **20** (simdjson optional) · Go **19** · Java **18** · C++ **27+** · Swift **14**.

---

## The four families

These rows are orientation only—not a leaderboard. Real speed and size depend on implementation and payload.

| Family | Schema on the wire | Human-readable | Typical size | Typical speed | Cross-language | Often used for |
|--------|--------------------|----------------|--------------|---------------|----------------|----------------|
| **JSON** (text) | Optional / external | Yes | Larger | Medium | Universal | Public APIs, configs |
| **Schemaless binary** | Type tags / field names often present | No | Smaller than JSON | Often faster than text JSON | Wide / growing | Internal services, caches |
| **Schema-driven** | Numbers / layout from schema or IDL | No | Often smallest | Often fastest deserialize | Where codegen exists | Stable contracts, streams |
| **Language-native** | Runtime type metadata | No | Medium | Varies | Usually one runtime | Same-stack caches / graphs |

Some benchmark-runner entries (C# **XML** / **YAML** / **CSV**, and similar) sit outside a pure four-box split. Treat them as adjacent text or specialized formats and use the language Overview category column.

---

## Decision sketch

Work through these questions in order:

1. **Do people need to read or edit the payload?**
   - **Yes** → JSON family (or other text formats where registered).
   - **No** → continue.
2. **Do you need a shared schema / IDL and evolution rules?**
   - **Yes** → Schema-driven.
   - **No** → continue.
3. **Single language / runtime, complex graphs, and fully trusted data?**
   - **Yes** → Language-native (only inside a hard trust boundary).
   - **No** → Schemaless binary.

Product-oriented guidance: [engineering perspective](../theory/101/engineer_perspective.md).

---

## Family notes (suite-focused)

Examples use **log `SerializerName` values** from language overviews (not always the same as package names on PyPI or crates.io).

### JSON (text)

- **Prefer when:** public APIs, human-edited config, multi-vendor clients without an interface description language (IDL).
- **Trade-offs:** readable; larger payloads; performance varies sharply by implementation.
- **Examples in suite:**
  - **C#:** `Json.Net`, `Json.Net (Helper)`, `System.Text.Json`, `SpanJson`, `Utf8Json`, `Jil`, `NetJSON`, `ServiceStack Json`, …
  - **Python:** `json`, `orjson`, `msgspec`, `rapidjson`, `pydantic`, `mashumaro`, `serpyco-rs`
  - **Rust:** `serde_json`, `simd-json`, `sonic-rs`
  - **C:** `cJSON`, `yyjson`, `jansson`, `parson`, `json-c`
  - **JavaScript:** `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional native)
  - **Go:** `encoding/json`, `sonic`, `goccy/go-json`, `jsoniter`, `segmentio/encoding/json`, `ugorji/json`
  - **Go (adjacent text):** `goccy/go-yaml`, `pelletier/go-toml` (human-readable documents; not JSON wire)
  - **Java:** `jackson`, `gson`, `fastjson2`, `dsl-json`, `moshi`, `jsoniter`
  - **C++:** `nlohmann_json`, `rapidjson`, `simdjson`, `arduinojson`, `yyjson`, `glaze`

### Schemaless binary

- **Prefer when:** internal services, caches and queues, JSON-like flexibility without text parse cost.
- **Trade-offs:** not human-readable; evolution is ad hoc unless you add conventions.
- **Examples in suite:**
  - **Python:** `msgpack`, `msgspec-msgpack`, `cbor2`
  - **Rust:** `rmp-serde`, `ciborium`, `minicbor`, `bson`, `bincode`, `postcard`, `bitcode`, `nanoserde`, `speedy`, `flexbuffers`
  - **C:** `mpack`, `msgpack-c`, `tinycbor`, `libcbor`, `libcbor-stream`, `qcbor`, `ubj`, `libbson`, `custom-binary`
  - **JavaScript:** `msgpackr`, `@msgpack/msgpack`, `json-pack-msgpack`, `cbor-x`, `cbor`, `bson`, `bser`, `sia`
  - **Go:** `vmihailenco/msgpack`, `shamaton/msgpack`, `ugorji/msgpack`, `fxamacker/cbor`, `ugorji/cbor`, `kelindar/binary`, `mongo-bson`
  - **Java:** `kryo`, `fory`, `protostuff`, `hessian`, `msgpack`, `jackson-cbor`, `jackson-smile`, `ion`, `bson`
  - **C++:** `msgpack`, `nlohmann_*`, `cereal`, `bitsery`, `zpp_bits`, `yas`, `cista`, `boost_serialization`, `jsoncons_*`, `custom_binary`
  - **C#:** many binary graph/type serializers (`Ceras`, `Hyperion`, `BinaryPack`, `MemoryPack`, …)—portability and trust model vary; see the [C# overview](../c-sharp/index.md). **MessagePack-CSharp is registered** (`ContractlessStandardResolver`).

### Schema-driven

- **Prefer when:** stable contracts, evolution rules, multi-platform code generation, high-throughput streams.
- **Trade-offs:** schema and tooling cost.

| Concern | Protobuf-like | Avro-like | FlatBuffers-like |
|---------|---------------|-----------|------------------|
| Schema location | Separate IDL | Often with data / registry | Separate IDL |
| Code generation | Common | Optional / dynamic | Common |
| Zero-copy access | Usually no | Usually no | Design goal |
| Typical niche | Microservices | Data platforms | Games / realtime |

- **Examples in suite:**
  - **C#:** `ProtoBuf` (protobuf-net), `Google.Protobuf`, `Apache.Avro`, `LightProto`, `MS Bond Fast` / `Compact`, `FlatSharp`, `ZeroFormatter`, `MemoryPack` (model/generator path)
  - **Python:** `protobuf`, `avro` (fastavro), `flatbuffers`
  - **Rust:** `prost` (shared `.proto`), `serde_avro_fast` (Avro; not official `apache-avro` — see inventory), `rkyv` (timed deserialize **materializes** owned values), `flexbuffers`
  - **C:** `protobuf` (Google libprotobuf), `nanopb`, `protobuf-c`, `protobuf-wire` (in-tree), `flatcc`, `avro-c`, `zcbor`
  - **JavaScript:** `avsc`, `protobufjs`, `protobuf-es`, `google-protobuf`, `flatbuffers`, `flexbuffers`, `bebop`
  - **Go:** `protobuf`, `hamba/avro`, `linkedin/goavro`
  - **Java:** `protobuf`, `avro`
  - **C++:** `protobuf` (libprotobuf), `protobuf-wire` (in-tree), `avro`/`avro_c`, `thrift`, `capnproto`, `flatbuffers`, `flexbuffers`

### Language-native

- **Prefer when:** single-runtime caches and rich graphs inside a **hard trust boundary**.
- **Trade-offs:** poor portability; **unsafe** on untrusted input where formats can execute code.
- **Examples in suite:**
  - **Python:** `pickle`, `cloudpickle`, `dill`
  - **JavaScript:** `v8-serializer`, `devalue`
  - **Go:** `encoding/gob`
  - **Java:** `java-serialization`
  - **C#:** legacy / graph-oriented binaries (for example `MS Binary`)—see Overview
  - **Rust / C:** no pickle-equivalent native graph codec; use language-native stacks only where listed above

---

## Reading results fairly

- Default comparison: **same language + same family + same data type + same mode**.
- Schema-driven formats often lead on size and throughput *within a language*—that is not a universal ranking.
- **C** uses real library APIs when dependencies are built (`fetch-and-build-deps.sh`); read the [C Overview](../c/index.md) for visitor domain shape, `protobuf-wire` (in-tree, not Google upb), and payload-wrapped rows (`ubj`, flatcc, avro-c).
- Metrics live on the [Dashboard](../dashboard/), not on this page.

## Further reading

- [JSON](https://www.json.org/) · [MessagePack](https://msgpack.org/) · [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)
- [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/)
- [Theory 101](../theory/101/index.md)
