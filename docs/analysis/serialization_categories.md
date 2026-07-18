# Serialization categories

**Job of this page:** the **four paradigms** this suite uses when grouping serializers, plus a short decision sketch and **suite-level examples by family**.

| For this instead… | Go here |
|-------------------|---------|
| Conceptual trade-offs (product / theory) | [Theory — engineering](../theory/101/engineer_perspective.md) · [101 home](../theory/101/index.md) |
| Full registered names and caveats | Language **Overview** pages (SoT for “what we measure”) |
| Timings and plots | Language **Results** · [Benchmark Results](BENCHMARK_SUMMARY.md) hub |

**Rule of thumb:** compare serializers **within the same paradigm** and **within one language**. Cross-language and cross-paradigm “winners” are not interchangeable.

Registered counts (Overview SoT): C# **36** · Python **16** · Rust **15** · C **20** · JavaScript **20** (simdjson optional) · Go **19** · Java **18** · C++ **27+**.

---

## The four families

Orientation only—not a leaderboard. Real speed/size depend on implementation and payload.

| Family | Schema on the wire | Human-readable | Typical size | Typical speed | Cross-language | Often used for |
|--------|--------------------|----------------|--------------|---------------|----------------|----------------|
| **JSON** (text) | Optional / external | Yes | Larger | Medium | Universal | Public APIs, configs |
| **Schemaless binary** | Type tags / field names often present | No | Smaller than JSON | Often faster than text JSON | Wide / growing | Internal services, caches |
| **Schema-driven** | Numbers / layout from schema or IDL | No | Often smallest | Often fastest deserialize | Where codegen exists | Stable contracts, streams |
| **Language-native** | Runtime type metadata | No | Medium | Varies | Usually one runtime | Same-stack caches / graphs |

Some harness entries (C# **XML** / **YAML** / **CSV**, etc.) sit outside a pure four-box split; treat them as adjacent text or specialized formats and use the language Overview category column.

---

## Decision sketch

1. **Need humans to read/edit the payload?**
   - **Yes** → JSON family (or other text formats where registered)  
   - **No** → continue  
2. **Need shared schema / IDL and evolution rules?**
   - **Yes** → Schema-driven  
   - **No** → continue  
3. **Single language / runtime and complex graphs OK (trusted data only)?**
   - **Yes** → Language-native  
   - **No** → Schemaless binary  

Product-oriented guidance: [engineering perspective](../theory/101/engineer_perspective.md).

---

## Family notes (suite-focused)

Examples use **log `SerializerName` values** from language overviews (not necessarily package names on PyPI/crates.io).

### JSON (text)

- **Prefer when:** public APIs, human-edited config, multi-vendor clients without an IDL.  
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
  - **C++:** `nlohmann_json`, `rapidjson`, `simdjson`, `arduinojson`, `yyjson`  

### Schemaless binary

- **Prefer when:** internal services, caches/queues, JSON-like flexibility without text parse cost.  
- **Trade-offs:** not human-readable; evolution is ad hoc unless you add conventions.  
- **Examples in suite:**  
  - **Python:** `msgpack`, `msgspec-msgpack`, `cbor2`  
  - **Rust:** `rmp-serde`, `ciborium`, `minicbor`, `bson`, `bincode`, `postcard`, `bitcode`, `nanoserde`, `speedy`, `flexbuffers`  
  - **C:** `mpack`, `msgpack-c`, `tinycbor`, `cbor-encode`, `qcbor`, `ubj`, `libbson`, `custom-binary`  
  - **JavaScript:** `msgpackr`, `@msgpack/msgpack`, `json-pack-msgpack`, `cbor-x`, `cbor`, `bson`, `bser`, `sia`  
  - **Go:** `vmihailenco/msgpack`, `shamaton/msgpack`, `ugorji/msgpack`, `fxamacker/cbor`, `ugorji/cbor`, `kelindar/binary`, `mongo-bson`  
  - **Java:** `kryo`, `fory`, `protostuff`, `hessian`, `msgpack`, `jackson-cbor`, `jackson-smile`, `ion`, `bson`  
  - **C++:** `msgpack`, `nlohmann_*`, `cereal`, `bitsery`, `zpp_bits`, `yas`, `cista`, `boost_serialization`, `jsoncons_*`, `custom_binary`  
  - **C#:** many binary graph/type serializers (`Ceras`, `Hyperion`, `BinaryPack`, `MemoryPack`, …)—portability and trust model vary; see [C# overview](../c-sharp/index.md). **MessagePack-CSharp is not registered.**

### Schema-driven

- **Prefer when:** stable contracts, evolution rules, multi-platform codegen, high-throughput streams.  
- **Trade-offs:** schema/tooling cost.

| Concern | Protobuf-like | Avro-like | FlatBuffers-like |
|---------|---------------|-----------|------------------|
| Schema location | Separate IDL | Often with data / registry | Separate IDL |
| Codegen | Common | Optional / dynamic | Common |
| Zero-copy access | Usually no | Usually no | Design goal |
| Typical niche | Microservices | Data platforms | Games / realtime |

- **Examples in suite:**  
  - **C#:** `ProtoBuf` (protobuf-net), `Google.Protobuf`, `MS Bond Fast` / `Compact`, `FlatSharp`, `ZeroFormatter`, `MemoryPack` (model/generator path)  
  - **Python:** `protobuf`, `avro` (fastavro), `flatbuffers`  
  - **Rust:** `prost` (shared `.proto`), `rkyv` (timed deser **materializes** owned values), `flexbuffers`  
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
  - **C#:** legacy / graph-oriented binaries (e.g. `MS Binary`)—see Overview  
  - **Rust / C:** no pickle-equivalent native graph codec; use language-native stacks only where listed above

---

## Reading results fairly

- Default comparison: **same language + same family + same fixture + same mode**.  
- Schema-driven often leads on size/throughput *within a language*—not a universal ranking.  
- **C** uses real library APIs when deps are built (`fetch-and-build-deps.sh`); read the C Overview for `upb` / `ubj` notes.  
- Metrics live on language **Results**, not here.

## Further reading

- [JSON](https://www.json.org/) · [MessagePack](https://msgpack.org/) · [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)  
- [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/)  
- [Theory 101](../theory/101/index.md)
