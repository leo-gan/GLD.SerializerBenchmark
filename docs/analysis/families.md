# Format Families

**Families** provide a high-level pedagogical map grouping wire formats by design trade-offs. Because a family is coarser than a **standard** (e.g., JSON, YAML, and TOML are distinct standards), the Dashboard filters and ranks by **Standard** rather than family. Conceptual mechanics are treated in depth in [Serialization 101](../theory/101/index.md) and [Serialization 201](../theory/201/index.md); live measurements live on the [Dashboard](../dashboard/index.html).

## Family Overview

The table summarizes typical design properties; actual latency and wire density always depend on both payload shape and library implementation.

| Family | Wire Schema | Human-Readable | Typical Size | Typical Decode Profile | Cross-Language | Common Workloads |
|---|---|---|---|---|---|---|
| **Text (JSON, YAML, TOML, XML, TOON)** | Optional / external | Yes | Larger | Delimiter scanning and radix conversion | Universal | Public APIs, configuration, logs |
| **Schemaless binary** | Type tags and field names | No | Compact | Tag dispatch + map key resolution | Broad (MessagePack, CBOR, BSON, Ion, Smile) | Internal services, document caches |
| **Schema-driven** | External IDL / field tags or offsets | No | Smallest | Tag stream or direct offset loads | Strong where codegen exists (Protobuf, Avro, FlatBuffers, Cap'n Proto, SBE) | RPC contracts, event streams, telemetry |
| **Language-native** | Runtime type metadata | No | Medium | Direct runtime graph reflection/codegen | Single runtime only | Same-language caches and object graphs (strictly inside trust boundaries) |
| **Columnar** | Table schema in IPC header or file footer | No | Very compact on wide tables | Columnar projection and vectorized scans | Strong across analytics engines (Arrow IPC, Parquet, ORC) | Analytical lakes, feature batches |

## Selection Heuristic

When mapping a workload to a candidate standard before consulting the Dashboard:

1. **Human inspection or editing required?** Start with a text standard (`json`, `yaml`, `toml`).
2. **Cross-language contract with schema evolution required?** Select a schema-driven standard (`protobuf`, `avro`, `flatbuffers`, `capnp`, `sbe`) or columnar interchange (`arrow`, `parquet`, `orc`) for wide analytical tables.
3. **Single runtime, complex object graphs (shared references or cycles), inside a hard trust boundary?** Consider a language-native codec or an explicit graph-capable format ([Graph data set](graph.md)). Never deserialize untrusted bytes with opcode/graph codecs ([3.1 Trust boundaries](../theory/301/trust-boundaries.md)).
4. **Otherwise:** Evaluate schemaless binary standards (`msgpack`, `cbor`, `ion`, `bson`), then open the [Dashboard](../dashboard/index.html) filtered to **one language, one standard, one data set, and one data type** to compare concrete libraries.

## Commonly Confused Labels

- **Columnar family vs. `columnar` data set:** The *family* classifies analytical standards (`arrow`, `parquet`, `orc`), whereas the *data set* (`table`, `table_project`, `nested_table`, `signal`) is a workload matrix that also times row-oriented peers for comparison. Simple Binary Encoding (`sbe`), for example, belongs to the **schema-driven** family, uses the `sbe` standard, and is measured on the `columnar` data set ([Row vs. columnar](../theory/301/row-vs-columnar.md)).
- **`graph`, `array`, and `tensor`:** These are **data sets** (workload shapes), not format families ([Data sets](test_data_configuration.md)).
- **Dagr (`custom`):** Has no public specification (Dashboard standard **No public spec**). Its packed layouts inline references and therefore cannot represent cyclic graphs, appearing on `suite` only while `regular` and `frozen` also run on `graph`.

## Primary Specifications

- Text & schemaless binary: [JSON (RFC 8259)](https://www.rfc-editor.org/rfc/rfc8259) · [MessagePack](https://msgpack.org/) · [CBOR (RFC 8949)](https://www.rfc-editor.org/rfc/rfc8949.html)
- Schema-driven: [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/) · [SBE](https://github.com/aeron-io/simple-binary-encoding)
- Columnar: [Apache Arrow](https://arrow.apache.org/) · [Apache Parquet](https://parquet.apache.org/) · [Apache ORC](https://orc.apache.org/)
