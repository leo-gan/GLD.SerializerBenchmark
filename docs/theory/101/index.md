# Serialization 101: Foundations

Programs manipulate structured data in memory—records, arrays, strings, and pointer-linked graphs—whose physical representation is tied to a specific process, compiler, and runtime. Storage devices and networks, however, transfer only linear sequences of octets. Serialization bridges that gap by defining a portable contract between writers and readers.

!!! note "Definition: Serialization and Deserialization"
    **Serialization** (also called *marshalling* or *encoding*) is the transformation of an in-memory data structure into a linear sequence of bytes according to a specified format contract. **Deserialization** (*unmarshalling* or *decoding*) reconstructs a semantically equivalent in-memory representation from that byte sequence, potentially in another process, machine, or programming language.

Inside a running process, composite values routinely rely on memory addresses: a record holds a pointer to an array, whose elements reference heap-allocated strings. Those addresses have meaning only within the originating address space. Flattening a structure onto a disk or network therefore requires replacing process-local pointers, compiler padding, and host byte order with explicit representation rules.

![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract.svg#only-light)
![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract-dark.svg#only-dark)

---

## The Serialization Model {#the-serialization-model}

Evaluating serialization choices requires keeping four layers distinct. Conflating them—for example, attributing a slow library implementation to a wire format, or applying a microbenchmark to the wrong access pattern—is the most common source of flawed architectural conclusions.

| Layer | Core Question | Role in This Suite |
|---|---|---|
| **Workload** | What data shape is exchanged, and how is it accessed? | A **data set** and **data type** ([Data sets](../../analysis/test_data_configuration.md)) |
| **Standard** | What rules govern the byte representation? | The Dashboard **Standard** filter; specifications are cataloged in [Compliance](../../compliance/index.md) |
| **Implementation** | How does a specific library realize that standard? | One registered serializer in one language benchmark runner |
| **Evaluation** | What are the speed, size, fidelity, and conformance properties? | Timings and round-trip fidelity on the [Dashboard](../../dashboard/index.html); specification tests in [Dashboard · Compliance](../../dashboard/index.html#compliance) |

A **standard** bounds what the wire representation can express and how compact it can be; an **implementation** determines how closely a given runtime approaches those bounds in latency, memory allocation, and strictness. In Python, `orjson` and the standard-library `json` module both implement RFC 8259 JSON; the performance difference between them is an implementation property, not a format property.

Two additional classifications appear throughout this documentation:

- **Family:** A coarse pedagogical grouping—text, schemaless binary, schema-driven, language-native, or columnar ([Families](../../analysis/families.md)). Families orient format selection, whereas benchmark rankings filter by the exact **standard** (YAML and JSON belong to the text family yet are distinct standards; Simple Binary Encoding belongs to the schema-driven family, runs on the `columnar` data set, and implements the `sbe` standard).
- **No public spec:** Serializers without an external wire specification—such as Python `pickle`, Rust `bincode`, and in-tree baselines—are grouped under **No public spec** on the Dashboard. They are timed normally, while specification conformance scoring does not apply.

---

## Design Axes of Serialization Standards {#how-standards-differ}

Five largely orthogonal properties characterize a serialization standard. Once a standard is selected, these properties are fixed regardless of which library implements it.

### Text vs. Binary

| Property | Text (JSON, XML, YAML, TOML) | Binary (MessagePack, Protocol Buffers, Parquet) |
|---|---|---|
| **Advantages** | Human-inspectable in logs, debugging tools, and version control | Compact payloads; avoids character scanning and decimal–binary numeric conversion |
| **Costs** | Larger wire size; higher CPU cost for tokenization, escaping, and number parsing | Opaque without schema or inspection tooling |

### Schemaless vs. Schema-Driven

A **schema** is an explicit, out-of-band specification of record fields, data types, and compatibility rules.

| Property | Schemaless (JSON, MessagePack, CBOR) | Schema-Driven (Protocol Buffers, Avro, FlatBuffers, SBE) |
|---|---|---|
| **Advantages** | No separate interface-definition or code-generation build step | Smaller wire size (field names omitted); static typing and code generation; structured evolution rules |
| **Costs** | Validation, documentation, and backward compatibility remain application responsibilities | Up-front schema authoring, tooling, and governance overhead |

### Row-Oriented vs. Columnar

A **row-oriented** standard stores all fields of one record contiguously before starting the next record (JSON objects, Protocol Buffers messages, Avro records). A **columnar** standard groups all values of a single column contiguously across many records (Apache Parquet, Apache ORC, Apache Arrow).

| Property | Row-Oriented | Columnar |
|---|---|---|
| **Advantages** | Efficient single-record reads, writes, and point lookups in APIs and RPC | Projects a subset of columns over wide tables with minimal I/O and higher compression ratios |
| **Costs** | Scans every field of every record during wide analytical queries | File headers, stripes, and alignment overhead penalize single-record traffic |

### Self-Describing vs. Schema-Dependent

- **Self-describing** encodings embed field names or type tags inside each payload (JSON, MessagePack, CBOR, Amazon Ion). Any compliant parser can decode the structure without external metadata, at the expense of repeated wire overhead.
- **Schema-dependent** encodings omit names and most structural metadata from the byte stream (Protocol Buffers binary, raw Avro). Bytes are compact but cannot be interpreted reliably without the writer's schema.

### Portable vs. Language-Native

- **Portable** standards define language-neutral wire semantics intended for multi-language interchange (JSON, CBOR, Protocol Buffers, Avro, Parquet).
- **Language-native** serializers mirror a single runtime's object model (Python `pickle`, Java `ObjectInputStream`). They handle arbitrary object graphs and cycles conveniently inside one runtime, but lock data to that runtime and pose severe code-execution risks on untrusted input.

!!! note "Definition: Trust Boundary"
    A **trust boundary** is any interface across which serialized bytes enter or leave a single administrative and security domain—such as a public network endpoint, a multi-tenant message queue, or a shared object store. Language-native formats are unsuitable across trust boundaries.

---

## Evaluation and Fair Comparison {#how-to-compare}

This benchmark suite separates three distinct empirical questions:

| Dimension | What Is Measured | Location |
|---|---|---|
| **Performance** | Encode latency, decode latency, throughput, and encoded byte size | [Dashboard](../../dashboard/index.html) |
| **Fidelity** | Whether a benchmark sample preserves its logical value across a round trip | Recorded alongside speed runs (`mean_fidelity`); does not test specification compliance |
| **Conformance** | Whether a library accepts and rejects edge cases per cited specification sections | [Dashboard · Compliance](../../dashboard/index.html#compliance) |

Fair interpretation requires holding all variables outside the question under test fixed:

| Comparison Type | Question Answered | Variables Held Fixed |
|---|---|---|
| **Implementation** | Which library realizes this contract more efficiently? | Language, standard, data set, data type, batch size |
| **Standard** | What is the cost trade-off between two contracts on this workload? | Language, data set, data type, batch size |
| **Cross-language** | Roughly how does this contract behave on another runtime? | Standard, data set, data type (directional only; runtimes differ) |
| **Conformance** | Does this library adhere to the normative specification? | Specification test corpus for that standard (independent of speed rank) |

For example, comparing two Protocol Buffers libraries in Rust is an *implementation* comparison; comparing Protocol Buffers and Avro on the same Python data type is a *standard* comparison. A fast library that fails specification edge cases still has a valid timing measurement—that result characterizes the implementation, not the standard.

---

## Chapters and Companion Labs in Part I

The remaining three chapters of Part I apply this four-layer model from distinct vantage points:

| Chapter | Primary Question | Companion Lab |
|---|---|---|
| [1.1 Historical perspective](historical_perspective.md) | Why did each major class of format emerge, and what engineering pressure did it address? | — |
| [1.2 Data science perspective](data_science_perspective.md) | Which contracts fit analytical tables, event logs, feature pipelines, and model artifacts? | [Data science lab](../notebooks/101/data_science_perspective.ipynb) |
| [1.3 Engineering perspective](engineer_perspective.md) | Which contracts and libraries fit online APIs, internal RPC, security boundaries, and long-lived services? | [Engineering lab](../notebooks/101/engineering_perspective.ipynb) |

See [Lab notebooks](../notebooks/README.md) for local and Google Colab setup. After Part I, continue to [Part II: Mechanisms (201)](../201/index.md).

---

## Exercises

1. **Separating layers:** A colleague benchmarks Python's standard-library `json` module against Rust's `prost` (Protocol Buffers) on a nested order record and concludes that *"Protocol Buffers is 80× faster than JSON."* Identify every variable confounded in that comparison and restate two fair experiments that isolate *(a)* implementation cost and *(b)* standard cost.

??? note "Solution"
    The claim confounds **three** variables simultaneously: programming language/runtime (CPython vs. compiled Rust), serialization standard (text JSON vs. schema-driven binary Protocol Buffers), and library implementation quality.
    - *(a) Implementation comparison:* Hold language, standard, data set, and data type fixed—e.g., compare Python `json` vs. `orjson` on `suite/document` at $N=1$.
    - *(b) Standard comparison:* Hold language, data set, and data type fixed while varying the standard—e.g., compare `msgspec` (JSON) vs. `protobuf` (Protocol Buffers) in Python on `suite/document` at $N=1$.

2. **Axis classification:** Classify **Apache Parquet**, **CBOR**, and **Python `pickle`** along all five design axes (text/binary, schema/schemaless, row/columnar, self-describing/schema-dependent, portable/language-native).

??? note "Solution"
    - **Parquet:** binary, schema-driven (footer schema), columnar, self-describing at the file level (schema embedded in file footer), portable.
    - **CBOR (RFC 8949):** binary, schemaless, row/document-oriented, self-describing (major-type tags and map keys), portable.
    - **`pickle`:** binary (VM opcode stream), schemaless (runtime class metadata), object-graph/row-oriented, self-describing within Python only, language-native.

3. **Fidelity vs. conformance:** Suppose a JSON library passes `mean_fidelity = 1.0` on all benchmark data types in this suite yet accepts bare `NaN` tokens on decode. Does that invalidate its speed ranking, its RFC 8259 conformance, or both?

??? note "Solution"
    It does **not** invalidate the speed measurement on valid benchmark samples, because the library round-tripped those inputs faithfully. It **does** represent a strict RFC 8259 conformance failure (Section 6 forbids `NaN` as a JSON number token). Performance and specification conformance are separate evaluation dimensions.

---

## References

1. Bray, T. (Ed.). (2017). *The JavaScript Object Notation (JSON) Data Interchange Format*. IETF RFC 8259. <https://www.rfc-editor.org/rfc/rfc8259>
2. Bormann, C., & Hoffman, P. (2020). *Concise Binary Object Representation (CBOR)*. IETF RFC 8949. <https://www.rfc-editor.org/rfc/rfc8949>
3. ITU-T. *Information technology — ASN.1 encoding rules: Specification of Basic Encoding Rules (BER), Canonical Encoding Rules (CER) and Distinguished Encoding Rules (DER)*. Recommendation X.690.
4. Melnik, S., et al. (2010). "Dremel: Interactive Analysis of Web-Scale Datasets." *Proceedings of the VLDB Endowment*, 3(1–2), 330–339.
5. Kleppmann, M. (2017). *Designing Data-Intensive Applications*, Chapter 4: "Encoding and Evolution." O'Reilly Media.
