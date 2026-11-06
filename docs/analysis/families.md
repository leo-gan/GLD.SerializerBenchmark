# Families

Families are a teaching map. They group contracts by the job they are built for. A family is coarser than a standard. The Dashboard filters by **Standard**, not by family. A language **Overview** lists that language’s roster. The Standard control lists who claims a given contract.

Theory pages cover product trade-offs. Timings live on the [Dashboard](../dashboard/).

| If you need… | Go here |
|--------------|---------|
| Workload, standard, implementation, and how to compare | [Serialization 101](../theory/101/index.md) |
| Full registered names and caveats | Language **Overview** pages |
| Timings and plots | [Dashboard](../dashboard/) |

---

## Learning goals

By the end of this page you should be able to:

1. Name the families and one real example of each.
2. Move from a product question to a family, and from that family to a named standard.
3. Apply the comparison rule at the end of this page before treating a rank as a decision.

---

## The families

These rows are orientation only. Real speed and size depend on the implementation and the payload.

| Family | Schema on the wire | Human-readable | Typical size | Typical speed | Cross-language | Often used for |
|--------|--------------------|----------------|--------------|---------------|----------------|----------------|
| **JSON** (text) | Optional / external | Yes | Larger | Medium | Universal | Public APIs, configs |
| **Schemaless binary** | Type tags / field names often present | No | Smaller than JSON | Often faster than text JSON | Wide / growing | Internal services, caches |
| **Schema-driven** | Numbers / layout from schema or IDL | No | Often smallest | Often fastest deserialize | Where codegen exists | Stable contracts, streams |
| **Language-native** | Runtime type metadata | No | Medium | Varies | Usually one runtime | Same-stack caches / graphs |
| **Columnar** | Table schema, often a footer or IPC schema | No | Depends on encoding and compression | Scan of few columns over many rows | Where the library can write the format | Lakes, notebooks, feature batches |

XML, YAML, CSV, and TOML sit beside the text family. When this suite gives one of them a standard id, that id is its own contract. YAML is not JSON.

---

## Decision sketch

Work through these questions in order:

1. **Do people need to read or edit the payload?**
   - **Yes** → a text standard such as JSON, YAML, or TOML, where the language registers one.
   - **No** → continue.
2. **Do you need a shared schema or interface description language, and evolution rules?**
   - **Yes** → a schema-driven standard.
   - **No** → continue.
3. **Single language and runtime, complex graphs, and fully trusted data?**
   - **Yes** → a language-native library, only inside a hard trust boundary.
   - **No, but the payload really is a shared graph** → the **graph** data set. See [Data sets](test_data_configuration.md).
   - **No** → a schemaless binary standard such as MessagePack or CBOR.
4. **Which standard inside that family?** JSON, YAML, and TOML are different contracts. Protocol Buffers, Avro, and FlatBuffers are different contracts. Arrow IPC, Parquet, and ORC are different contracts. Open the [Dashboard](../dashboard/) with that standard selected, then compare libraries.

Product-oriented guidance: [engineering perspective](../theory/101/engineer_perspective.md).

---

## Labels that are easy to mix

**SBE** (Simple Binary Encoding) sits in the schema-driven family. Its data set is columnar. Its standard is SBE. The body is word-aligned, and variable-length data sits at the end of a message or a repeating group. SBE is not a columnar file format like Parquet.

**Columnar** names a family and a data set, and those are different questions. Arrow IPC, Parquet, and ORC are separate standards. Arrow IPC is the in-memory interchange. Parquet and ORC are on-disk columnar files. A one-row batch pays header and alignment cost. On `table_project`, deserialize is the question “read one column.”

**Dagr** has no public specification. The Dashboard standard is **No public spec**. One schema, four node layouts. Packed layouts cannot store a cycle, so they are absent from the graph data set.

**Graph, array, and tensor** are data sets, not families. The shapes and the run configs are on the [Data sets](test_data_configuration.md) page.

---

## Reading results fairly

Compare libraries in the **same language**, on the **same standard**, on the **same data set**, and on the **same data type**. Rank the parent row. A family is coarser than the standard id.

Schema-driven standards are often smaller and faster inside one language. That is not a universal ranking. Metrics live on the [Dashboard](../dashboard/).

## Further reading

- [JSON](https://www.json.org/) · [MessagePack](https://msgpack.org/) · [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)
- [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/) · [SBE](https://github.com/aeron-io/simple-binary-encoding)
- [Apache Arrow](https://arrow.apache.org/) · [Apache Parquet](https://parquet.apache.org/) · [Apache ORC](https://orc.apache.org/)
