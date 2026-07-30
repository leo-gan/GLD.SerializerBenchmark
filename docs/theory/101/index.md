# Serialization 101

Welcome to Serialization 101. This course is a starting point for **anyone** who wants to understand data serialization. You do not need prior experience with distributed systems, data lakes, or binary formats. First-year students, data scientists, and working engineers can all begin here.

By the end of this theory track you should be able to:

1. Explain what serialization is and why computer programs need it.
2. Read the history of data formats as answers to real problems, not as a list of product names.
3. Choose a format *for a specific kind of work* by using the right lens (data work versus services).
4. Connect the ideas in these pages to **measured** libraries in this multi-language benchmark suite.

Theory alone does not tell you what to ship in production. Use this course to build vocabulary and judgment. Then check real numbers with [Benchmarks](../../analysis/index.md) and each language’s **Results** pages.

---

## What is serialization?

**Serialization** is the process of turning an in-memory data structure into a **linear sequence of bytes**. Those bytes can be stored on disk, held in a cache, or sent across a network. **Deserialization** is the reverse process: rebuilding a usable structure from those bytes. The rebuilt structure may live in another process, on another machine, or in another programming language.

Why is this necessary? Inside a running program, data is often a web of pointers and types. A record may point to an array, which points to strings, which point to characters. Networks and disks do not understand that web. They only store and transmit bytes in order. Every serialization format is therefore a **contract** between a writer and a reader. The contract says how the web of meaning is flattened into bytes, and how those bytes are rebuilt later.

![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract.svg#only-light)
![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract-dark.svg#only-dark)

---

## Three lenses

The same family of formats appears under three perspectives on purpose. Each document answers a different question:

| Lens | Primary question | Best if you care about… |
|------|------------------|-------------------------|
| **[Historical](historical_perspective.md)** | *Why do these formats exist?* | Eras, people, constraints, and major shifts in thinking |
| **[Data science](data_science_perspective.md)** | *What should I use for data and machine-learning work?* | Lakes, pipelines, notebooks, models, and columnar input/output |
| **[Engineering](engineer_perspective.md)** | *What should I ship in services and systems?* | APIs, remote procedure calls (RPC), performance, security, and long-term change |

**Suggested order for a first pass**

1. Skim the **shared trade-offs** below (about ten minutes).
2. Read the **[historical perspective](historical_perspective.md)** once for the big picture.
3. Deep-dive the lens that matches your work (**[data science](data_science_perspective.md)** or **[engineering](engineer_perspective.md)**).
4. Open [Serialization categories](../../analysis/serialization_categories.md) and a language **Overview** or **Results** page for libraries you might actually use.
5. When you need *mechanisms* (how formats work under the hood), work through the **[Serialization 201](../201/index.md)** track:
    1. [Memory layout](../201/memory-layout.md)
    2. [Encode/decode cost](../201/encode-decode-cost.md)
    3. [Self-describing vs schema](../201/self-describing-vs-schema-dependent.md)
    4. [Schema evolution](../201/schema-evolution.md)
    5. [Dynamic vs IDL binary](../201/dynamic-vs-idl-binary.md)
    6. [Zero-copy](../201/zero-copy.md)
    7. [Compression vs format](../201/compression-is-not-a-format.md)

You can reverse steps 2 and 3 if you already have a concrete problem (for example, “I need Parquet for analytics” or “I need an internal service format”). Jump to a single 201 article when you already know the question you want answered.

When the mechanisms feel solid and you need **production judgment under several constraints at once**, continue to [Serialization 301](../301/index.md).

---

## Core trade-offs

These axes appear in every lens. Learn the *names* here; the perspective documents fill in the details.

### Text versus binary

| | Text (JSON, XML, YAML, and similar) | Binary (MessagePack, Protocol Buffers, Parquet, and similar) |
|--|---------------------------|-----------------------------------------------|
| **Strength** | Humans can read it; easier to debug and log | Compact; often much faster to encode and decode |
| **Cost** | Larger payloads; parsing character by character | Opaque without tools; harder to inspect by hand |

In other words, text formats trade size and speed for readability. Binary formats trade readability for density and often for speed.

### Schema versus schemaless

A **schema** is a written description of the shape of the data: which fields exist, what types they have, and how they may change over time.

| | Schemaless (JSON, MessagePack, and similar) | Schema-driven (Protocol Buffers, Avro, FlatBuffers, and similar) |
|--|-----------------------------------|--------------------------------------------------|
| **Strength** | Flexible; you can ship data without an interface-description step | Compact on the wire; code generation; clearer evolution rules when you invest in process |
| **Cost** | Validation and compatibility are *your* job | Up-front schema design and tooling |

### Row-oriented versus columnar

| | Row (JSON objects, Protocol Buffers messages, Avro records) | Columnar (Parquet, ORC, Arrow tables) |
|--|-----------------------------------------------------|----------------------------------------|
| **Strength** | Natural for whole records (APIs, RPC, online transaction-style access) | Scan a few columns over huge tables with far less input/output |
| **Cost** | Poor for wide analytical queries | Wrong default when you mostly “fetch one document by id” |

Think of a spreadsheet. A **row-oriented** format stores one complete row after another. A **columnar** format stores all values of column A together, then all values of column B, and so on. Analytics queries that touch only a few columns benefit from the columnar layout.

### Self-describing versus schema-dependent

- **Self-describing (to varying degrees):** field names or type tags travel with the data (JSON, MessagePack, CBOR). These are easier to inspect, but they carry more metadata on the wire.
- **Schema-dependent:** the wire data is nearly meaningless without a shared schema (classic Protocol Buffers, raw Avro). These are smaller and faster when both ends already agree on the contract.

### Portable versus language-native

- **Portable:** designed for multi-language interchange (JSON, Protocol Buffers, MessagePack, and similar).
- **Language-native:** tied to one runtime (`pickle`, Java serialization, and similar). These are convenient inside a tight trust boundary, but they are dangerous or unusable across languages and on untrusted inputs.

A **trust boundary** is any place where data leaves a fully controlled environment and may be influenced by someone else—for example, a public network request.

---

## Lab notebooks (Python / Colab)

Hands-on companions for two of the lenses:

| Notebook | Article |
|----------|---------|
| [Data science lab](../notebooks/101/data_science_perspective.ipynb) | [Data science perspective](data_science_perspective.md) |
| [Engineering mini lab](../notebooks/101/engineering_perspective.ipynb) | [Engineering perspective](engineer_perspective.md) |

Install and layout notes live in the [notebooks README](../notebooks/README.md).

## Scope and honesty

- This theory track is a **map**, not an encyclopedia of every library.
- Performance claims in prose are **illustrative**. Prefer suite **Results** for numbers on *this* benchmark runner and hardware.
- “Best format” always means **best under your constraints** (team, trust boundary, retention, latency budget, multi-language needs).
