# Serialization categories

**Job of this page:** the **four paradigms** this suite uses when grouping serializers, plus a short decision sketch and a **suite-level inventory by family**.

| For this instead… | Go here |
|-------------------|---------|
| Conceptual trade-offs (why formats exist / how to choose in product) | [Theory — engineering](../theory/engineer_perspective.md) · [101 home](../theory/index.md) |
| Per-library caveats and full names | Language **Overview** pages (SoT for “what we measure”) |
| Timings and plots | Language **Results** · [Benchmark Results](BENCHMARK_SUMMARY.md) hub |

**Rule of thumb:** compare serializers **within the same paradigm** and **within one language**. Cross-language and cross-paradigm “winners” are not interchangeable.

---

## The four families

Orientation only—not a leaderboard. Real speed/size depend on implementation and payload.

| Family | Schema on the wire | Human-readable | Typical size | Typical speed | Cross-language | Often used for |
|--------|--------------------|----------------|--------------|---------------|----------------|----------------|
| **JSON** (text) | Optional / external | Yes | Larger | Medium | Universal | Public APIs, configs |
| **Schemaless binary** | Type tags / field names often present | No | Smaller than JSON | Often faster than text JSON | Wide / growing | Internal services, caches |
| **Schema-driven** | Numbers / layout from schema or IDL | No | Often smallest | Often fastest deserialize | Where codegen exists | Stable contracts, streams |
| **Language-native** | Runtime type metadata | No | Medium | Varies | Usually one runtime | Same-stack caches / graphs |

---

## Decision sketch

1. **Need humans to read/edit the payload?**
   - **Yes** → JSON family  
   - **No** → continue  
2. **Need shared schema / IDL and evolution rules?**
   - **Yes** → Schema-driven  
   - **No** → continue  
3. **Single language / runtime and complex graphs OK (trusted data only)?**
   - **Yes** → Language-native  
   - **No** → Schemaless binary  

Product-oriented guidance: [engineering perspective](../theory/engineer_perspective.md).

---

## Family notes (suite-focused)

### JSON (text, schemaless)

- **Prefer when:** public APIs, human-edited config, multi-vendor clients without an IDL.  
- **Trade-offs:** readable and universal; larger payloads; binary often base64; performance varies sharply by implementation.  
- **In this suite (examples):** C# `Json.Net` / `SpanJson` / … · Python `json` / `orjson` / `msgspec` · Rust `serde_json` / `simd-json` · C `yyjson` / `cJSON` · JS `JSON.stringify` / `simdjson` (optional).  
  Full lists and caveats: language **Overview**.

### Schemaless binary

- **Prefer when:** internal services, caches/queues, JSON-like flexibility without text parse cost.  
- **Trade-offs:** not human-readable; evolution is ad hoc unless you add conventions. MessagePack vs CBOR is **implementation-specific**.  
- **In this suite (examples):** MessagePack / CBOR / BSON-style codecs across languages; plus language-local binary graphs (e.g. Rust `bincode` / `postcard`).  
  C# “MS Binary” and similar are **not** portable interchange—see [C# overview](../c-sharp/index.md).

### Schema-driven

- **Prefer when:** stable contracts, evolution rules, multi-platform codegen, high-throughput streams.  
- **Trade-offs:** schema/tooling cost; excellent size/speed when both ends share the model.

| Concern | Protobuf-like | Avro-like | FlatBuffers-like |
|---------|---------------|-----------|------------------|
| Schema location | Separate IDL | Often with data / registry | Separate IDL |
| Codegen | Common | Optional / dynamic | Common |
| Zero-copy access | Usually no | Usually no | Design goal |
| Typical niche | Microservices | Data platforms | Games / realtime |

- **In this suite (examples):** protobuf / Bond / FlatBuffers / MemoryPack-style / Avro / `prost` / `rkyv` (materialized for fidelity)—check language overviews for stand-ins (especially **C** portable builds).

### Language-native

- **Prefer when:** single-runtime caches and rich graphs inside a **hard trust boundary**.  
- **Trade-offs:** poor portability; version coupling; **unsafe** on untrusted input where the format can execute code (classic pickle / Java serialization risks).  
- **In this suite (examples):** Python `pickle` / `cloudpickle` / `dill` · JS `v8-serializer` · selected C# graph serializers. **ObjectGraph** is skipped for most pure tree formats.

---

## Reading results fairly

- Default comparison: **same language + same family + same fixture + same mode**.  
- Schema-driven often leads on size/throughput *within a language*—not a universal ranking.  
- Text parse and allocation/GC pressure dominate many managed-runtime stories.  
- Metrics live on language **Results**, not here.

## Further reading

- [JSON](https://www.json.org/) · [MessagePack](https://msgpack.org/) · [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)  
- [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/)  
- [Theory 101](../theory/index.md)
