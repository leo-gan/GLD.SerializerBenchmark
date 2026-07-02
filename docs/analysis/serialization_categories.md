# Serialization Categories

Categories used in **this suite**, with short format trade-offs. Compare serializers **within the same paradigm** and **within one language**; cross-language rankings are not interchangeable.

Registered names below are harness inventories (see language **Overview** for caveats). Timings and plots: language **Results** · hub [Benchmark Results](BENCHMARK_SUMMARY.md).

## Indicative format comparison

Orientation only—not a leaderboard. Real speed/size depend on implementation and payload.

| Family | Schema | Human-readable | Typical size | Typical speed | Cross-language | Often used for |
|--------|--------|----------------|--------------|---------------|----------------|----------------|
| **JSON** (text) | Optional | Yes | Larger | Medium | Universal | Public APIs, configs |
| **Schemaless binary** | Optional | No | Smaller than JSON | Often faster than text JSON | Wide / growing | Internal services, caches |
| **Schema-driven** | Required / fixed layout | No | Often smallest | Often fastest deserialize | Wide where codegen exists | Stable contracts, streams |
| **Language-native** | Runtime | No | Medium | Varies | Usually one runtime | Caching, same-stack graphs |

## Decision sketch

```text
Need humans to read/edit the payload?
  ├── YES → JSON
  └── NO
        Need shared schema / IDL and evolution rules?
          ├── YES → Schema-driven
          └── NO
                Single language / runtime, complex graphs OK?
                  ├── YES → Language-native
                  └── NO  → Schemaless binary
```

## JSON (text, schemaless)

Text interchange optimized for interoperability and debuggability, not minimum size.

**Prefer when:** public APIs, human-edited config, multi-vendor clients without an IDL.

**Trade-offs:** readable and universal; larger payloads; cycles usually unsupported without extensions; binary blobs often base64. Performance varies sharply by implementation (native vs pure).

**In this suite:**

- **C#**: `Json.Net`, `JsonNetHelper`, `Jil`, `NetJSON`, `SpanJson`, `Utf8Json`, `FastJson`, `ServiceStack` JSON, `DataContractJson`, Bond JSON (`MS Bond Json`)
- **Python**: `json`, `orjson`, `msgspec`, `rapidjson`, `pydantic`, `mashumaro`, `serpyco-rs`
- **Rust**: `serde_json`, `simd-json`, `sonic-rs`
- **C**: `cJSON`, `yyjson`, `jansson`, `parson` (default build may use portable stand-ins — [C overview](../c/index.md))
- **JavaScript**: `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional native)

## Schemaless binary

Structured binary without a mandatory IDL; field names or type tags often appear in the payload (unlike classic Protobuf wire format). Families include **MessagePack**, **CBOR**, and various language-specific binary graphs.

**Prefer when:** internal services, caches/queues, bandwidth limits with JSON-like flexibility.

**Trade-offs:** typically smaller/faster than text JSON; not human-readable; evolution is ad hoc unless you impose conventions. MsgPack vs CBOR trade-offs are **implementation-specific**.

**In this suite:**

- **C#**: `MS Binary` (BinaryFormatter), `Ceras`, `Hyperion`, `NetSerializer`, `BinaryPack`, `GroBuf`, `Migrant`, `Apex.Serialization`, FsPickler binary, ServiceStack type serializer
- **Python**: `msgpack`, `msgspec-msgpack`, `cbor2`
- **Rust**: `rmp-serde`, `ciborium`, `bincode`, `postcard`, `bitcode`, `minicbor`
- **C**: `mpack`, `tinycbor`, `ubj`, `cbor-encode`, `custom-binary`
- **JavaScript**: `msgpackr`, `@msgpack/msgpack`, `cbor-x`, `cbor`, `bson`, `bser`

MessagePack-CSharp is **not** registered unless listed on the [C# overview](../c-sharp/index.md).

## Schema-driven

IDL, schema, or fixed layout: field numbers, codegen, or zero-copy buffers (**Protobuf**, **Avro**, **Bond**, **FlatBuffers**, MemoryPack-style models, etc.).

**Prefer when:** stable contracts, long-lived storage with evolution rules, high-throughput streams, multi-platform codegen.

**Trade-offs:** often among smallest/fastest with strong typing; schema and tooling cost up front.

| Concern | Protobuf-like | Avro-like | FlatBuffers-like |
|---------|---------------|-----------|------------------|
| Schema location | Separate IDL | Often with data / registry | Separate IDL |
| Codegen | Common | Optional / dynamic | Common |
| Zero-copy access | Usually no | Usually no | Design goal |
| Typical niche | Microservices | Data platforms | Games / realtime |

Harness rows may be full codegen types or documented stand-ins (e.g. Rust `prost-wire`, C portable envelopes)—read language overviews.

**In this suite:**

- **C#**: protobuf-net (`ProtoBuf`), `Google.Protobuf`, Bond Fast/Compact, `FlatSharp`, `MemoryPack`, `ZeroFormatter`
- **Python**: `protobuf`, `avro` (fastavro), `flatbuffers`
- **Rust**: `flexbuffers`, `prost-wire` (envelope stand-in; see Rust caveats)
- **C**: `nanopb`, `protobuf-c`, `flatcc` (default build: tagged envelopes)
- **JavaScript**: `avsc`, `protobufjs`

## Language-native

Tied to one runtime/VM; often supports cycles and rich graphs at the cost of portability and, often, **safety on untrusted input** (classic pickle risks).

**Prefer when:** single-language deployments, internal caches/queues, types IDL formats reject.

**Trade-offs:** poor cross-language portability; version coupling; treat untrusted payloads as dangerous where applicable.

**In this suite:**

- **C#**: legacy binary / graph-capable serializers where supported (see [C# overview](../c-sharp/index.md))
- **Python**: `pickle`, `cloudpickle`, `dill`
- **JavaScript**: `v8-serializer`
- **Rust / C**: no pickle-equivalent; `ObjectGraph` skipped for most formats

## Notes on interpreting results

- Within-language, within-category comparisons are the fair default.
- Schema-driven entries often lead on size/throughput **in a given language**—not a universal ranking.
- Text parsing and allocation/GC pressure remain common bottlenecks on managed runtimes.
- Detailed metrics: language **Results** (pivots + plots), not this page.

## Further reading

- [JSON](https://www.json.org/) · [MessagePack](https://msgpack.org/) · [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)
- [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/)
