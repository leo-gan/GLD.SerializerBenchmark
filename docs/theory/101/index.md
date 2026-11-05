# Serialization 101

Welcome to Serialization 101. This course is a starting point for anyone who wants to understand data serialization. You do not need prior experience with distributed systems, data lakes, or binary formats. First-year students, data scientists, and working engineers can all begin here.

| Jump | |
|------|--|
| **This track** | The model below · then a lens · then [201 mechanisms](../201/index.md) |
| **See numbers** | [Dashboard](../../dashboard/) · language **Overview** for the roster |
| **How we measure** | [Benchmarks](../../analysis/index.md) |

By the end of this track you should be able to:

1. Name the standard a library implements, tell that name apart from its family, and say which comparison you are making.
2. Explain what serialization is and why programs need it.
3. Read the history of formats as answers to real problems, not as a list of product names.
4. Choose a standard for a workload, then an implementation. Keep performance separate from conformance.
5. Connect these pages to measured libraries in this benchmark suite.

Check real numbers on the [Dashboard](../../dashboard/). Language **Overview** pages list the roster and caveats. For how the numbers are produced, see [Benchmarks](../../analysis/index.md).

---

## What is serialization?

**Serialization** is the process of turning an in-memory data structure into a **linear sequence of bytes**. Those bytes can be stored on disk, held in a cache, or sent across a network. **Deserialization** rebuilds a usable structure from those bytes. The rebuilt structure may live in another process, on another machine, or in another programming language.

Inside a running program, data is often a web of pointers and types. A record may point to an array, that array to strings, and those strings to characters. Networks and disks only store and transmit bytes in order. Every serialization format is a **contract** between a writer and a reader. The contract says how meaning is flattened into bytes, and how those bytes are rebuilt.

![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract.svg#only-light)
![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract-dark.svg#only-dark)

---

## The serialization model

| Layer | Question | In this suite |
|-------|----------|----------------|
| **Workload** | What is serialized, and how is it used? | A data set and a data type. Shapes are on the [test data](../../analysis/test_data_configuration.md) page. |
| **Standard** | What do the bytes mean? | The Dashboard **Standard** control. Names are defined in the [compliance catalog](../../compliance/). |
| **Implementation** | How does one library realize that contract? | One library on one language runner. |
| **Evaluation** | How fast is it, and does it follow the contract? | Dashboard timings and fidelity. [Compliance](../../dashboard/#compliance) for the specification. |

A serialization standard defines what the bytes mean. An implementation determines how efficiently and correctly those rules are realized. A workload determines whether the standard is appropriate.

The standard bounds the wire. The library is how close that language gets to reading and writing it.

A **family** is a teaching group: text, schemaless binary, schema-driven, language-native, or columnar. [Serialization categories](../../analysis/serialization_categories.md) is that map. A family is not a Dashboard filter. YAML is its own standard. **SBE** (Simple Binary Encoding) is schema-driven, its data set is columnar, and its standard is SBE. It is not a columnar file format like Parquet.

A **library** is one implementation of a standard in one language. `orjson` and Python’s `json` module are both the JSON standard. The speed gap between them is the library.

Libraries with no public spec, such as `pickle`, `bincode`, and the in-tree custom binaries, use the Dashboard standard **No public spec**. They stay on the speed table. Compliance does not score them. The conformance question does not apply. That is not a verdict that the library is inferior.

## How standards differ

These axes are properties of the standard. Once you choose a standard, they are fixed. The perspective documents fill in the details.

### Text versus binary

| | Text (JSON, XML, YAML, and similar) | Binary (MessagePack, Protocol Buffers, Parquet, and similar) |
|--|---------------------------|-----------------------------------------------|
| **Strength** | Humans can read it. Easier to debug and log. | Compact. Often much faster to encode and decode. |
| **Cost** | Larger payloads. Parsing character by character is slower. | Opaque without tools. Harder to inspect by hand. |

### Schema versus schemaless

A **schema** is a written description of the shape of the data: which fields exist, what types they have, and how they may change.

| | Schemaless (JSON, MessagePack, and similar) | Schema-driven (Protocol Buffers, Avro, FlatBuffers, and similar) |
|--|-----------------------------------|--------------------------------------------------|
| **Strength** | Ship data without an interface-description step. | Compact on the wire. Code generation. Clearer evolution rules when you invest in process. |
| **Cost** | Validation and compatibility are *your* job. | Up-front schema design and tooling. |

### Row-oriented versus columnar

| | Row (JSON objects, Protocol Buffers messages, Avro records) | Columnar (Parquet, ORC, Arrow tables) |
|--|-----------------------------------------------------|----------------------------------------|
| **Strength** | Whole records. Fits APIs, RPC, and online transaction-style access. | Scan a few columns over huge tables with far less input/output. |
| **Cost** | Poor for wide analytical queries. | Wrong default when you mostly fetch one document by id. |

A row-oriented format stores one complete record after another. A columnar format stores all values of one column together, then the next column. Analytics that touch only a few columns benefit from the columnar layout.

### Self-describing versus schema-dependent

- **Self-describing:** Field names or type tags travel with the data. JSON, MessagePack, and CBOR are examples. Easier to inspect. More metadata on the wire.
- **Schema-dependent:** The bytes are nearly meaningless without a shared schema. Classic Protocol Buffers and raw Avro work this way. Smaller and faster when both ends already agree.

### Portable versus language-native

- **Portable:** Built for multi-language interchange. JSON, Protocol Buffers, and MessagePack fit here.
- **Language-native:** Tied to one runtime. `pickle` and Java serialization are convenient inside a tight trust boundary. They are unsafe on untrusted input, and other languages cannot read them.

A **trust boundary** is any place where data leaves a fully controlled environment and may be influenced by someone else. A public network request is one example.

## How this suite evaluates

| Question | What it measures | Where |
|----------|------------------|--------|
| **Performance** | Encode time, decode time, and size | [Dashboard](../../dashboard/) |
| **Fidelity** | Whether the fixture still means the same thing after a round trip | The speed run. This is not a match to a specification. |
| **Conformance** | Whether the library follows the specification it claims | [Dashboard · Compliance](../../dashboard/#compliance). **No public spec** has no score. |

A fast library that fails conformance cases still has a performance result. That result is about the library, not about the standard.

## How to compare

| Comparison | Question | What stays fixed |
|------------|----------|------------------|
| **Implementation** | Which library is more efficient? | Language, standard, data set, and data type |
| **Standard** | Which contract fits this workload? | Language, data set, and data type. The standard changes. |
| **Cross-language** | What does this contract cost on another runtime? | Standard, data set, and data type. Directional. Runtimes differ. |
| **Conformance** | Does this implementation follow the standard? | The normative cases for that standard. Independent of the speed rank. |

An across-standard speed chart answers which contract is cheaper on that workload. It does not answer which library is better.

- Two Protocol Buffers libraries in Rust are an implementation comparison.
- Protocol Buffers and Avro on the same workload are a standard comparison.
- The same standard across languages mixes runtime cost into the result.
- Kiln can be timed and checked against the Kiln wire.
- `pickle` can be timed. It has no conformance score.

## Three lenses

Each lens reads the same model for a different job.

| Lens | Primary question | Best if you care about… |
|------|------------------|-------------------------|
| **[Historical](historical_perspective.md)** | *Why did this contract appear?* | Eras, people, constraints, and shifts in thinking |
| **[Data science](data_science_perspective.md)** | *Which contract fits this data workload?* | Lakes, pipelines, notebooks, models, columnar input/output |
| **[Engineering](engineer_perspective.md)** | *Which contract should we ship, and then which library?* | APIs, RPC, performance, security, and long-term change |

| Next | |
|------|--|
| **A lens** | [Historical](historical_perspective.md) · [Data science](data_science_perspective.md) · [Engineering](engineer_perspective.md) |
| **Mechanisms** | [Serialization 201](../201/index.md) |
| **Production judgment** | [Serialization 301](../301/index.md) |
| **Family map** | [Serialization categories](../../analysis/serialization_categories.md) |
| **Numbers** | [Dashboard](../../dashboard/) — set **Language**, **Standard**, **Data set**, and **Data type** |

## Lab notebooks (Python / Colab)

| Notebook | Article |
|----------|---------|
| [Data science lab](../notebooks/101/data_science_perspective.ipynb) | [Data science perspective](data_science_perspective.md) |
| [Engineering mini lab](../notebooks/101/engineering_perspective.ipynb) | [Engineering perspective](engineer_perspective.md) |

Install notes live in the [notebooks README](../notebooks/README.md).

## Scope and honesty

- This track is a **map**, not an encyclopedia of every library.
- Performance claims in prose are **illustrative**. Prefer the [Dashboard](../../dashboard/) for numbers on *this* runner and hardware.
- “Best format” means **best under your constraints**: team skills, trust boundaries, retention, latency, and multi-language requirements.
