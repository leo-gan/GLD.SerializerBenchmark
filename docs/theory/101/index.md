# Serialization 101

This is a starting point for **anyone** who wants to understand data serialization—students, data scientists, backend engineers, and systems architects. You do not need prior expertise.

By the end of this theory track you should be able to:

1. Explain what serialization is and why it exists.
2. Read a format’s history as a response to real constraints (not as a list of brand names).
3. Choose a format *for a workload* using the right lens (data work versus services).
4. Connect concepts to **measured** libraries in this multi-language benchmark suite.

Theory alone does not decide production choices. Use this course to build vocabulary and judgment, then check numbers with [Benchmarks](../../analysis/index.md) and each language’s **Results** pages.

---

## What is serialization?

**Serialization** turns an in-memory data structure (objects, records, graphs) into a **linear sequence of bytes** that can be stored, cached, or sent across a network. **Deserialization** rebuilds a usable structure from those bytes—often in another process, machine, or programming language.

Memory is a web of pointers and types. The network and the disk only understand bytes. Every format is a **contract** between a writer and a reader about how that collapse and rebuild work.

![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract.svg#only-light)
![Serialization as a contract: in memory, on the wire, rebuilt](../assets/diagrams/101-serialize-contract-dark.svg#only-dark)

---

## Three lenses

The same formats appear under three perspectives on purpose. Each document answers a different question:

| Lens | Primary question | Best if you care about… |
|------|------------------|-------------------------|
| **[Historical](historical_perspective.md)** | *Why do these formats exist?* | Eras, people, constraints, and paradigm shifts |
| **[Data science](data_science_perspective.md)** | *What should I use for data and machine-learning work?* | Lakes, pipelines, notebooks, models, columnar input/output |
| **[Engineering](engineer_perspective.md)** | *What should I ship in services and systems?* | APIs, remote procedure calls (RPC), performance, security, evolution |

**Suggested order for a first pass**

1. Skim the **shared trade-offs** below (about ten minutes).
2. Read the **[historical perspective](historical_perspective.md)** once for the big picture.
3. Deep-dive the lens that matches your work (**[data science](data_science_perspective.md)** or **[engineering](engineer_perspective.md)**).
4. Open [Serialization categories](../../analysis/serialization_categories.md) and a language **Overview** or **Results** page for libraries you might actually use.
5. When you need *mechanisms*, work through the **[Serialization 201](../201/index.md)** track:
    1. [Memory layout](../201/memory-layout.md)
    2. [Encode/decode cost](../201/encode-decode-cost.md)
    3. [Self-describing vs schema](../201/self-describing-vs-schema-dependent.md)
    4. [Schema evolution](../201/schema-evolution.md)
    5. [Dynamic vs IDL binary](../201/dynamic-vs-idl-binary.md)
    6. [Zero-copy](../201/zero-copy.md)
    7. [Compression vs format](../201/compression-is-not-a-format.md)

You can reverse steps 2 and 3 if you already have a concrete problem (“I need Parquet for analytics” or “I need an internal RPC format”). Jump to a single 201 article when you already know the question.

When mechanisms feel solid and you need **production judgment under several constraints at once**, continue to [Serialization 301](../301/index.md).

---

## Core trade-offs

These axes appear in every lens. Learn the *names* here; details live in the perspective documents.

### Text versus binary

| | Text (JSON, XML, YAML, and similar) | Binary (MessagePack, Protocol Buffers, Parquet, and similar) |
|--|---------------------------|-----------------------------------------------|
| **Strength** | Humans can read it; easier to debug and log | Compact; often much faster to encode and decode |
| **Cost** | Larger payloads; parsing character by character | Opaque without tools; harder ad-hoc inspection |

### Schema versus schemaless

| | Schemaless (JSON, MessagePack, and similar) | Schema-driven (Protocol Buffers, Avro, FlatBuffers, and similar) |
|--|-----------------------------------|--------------------------------------------------|
| **Strength** | Flexible; you can ship data without an interface-description step | Compact on the wire; code generation; clearer evolution rules when you invest in process |
| **Cost** | Validation and compatibility are *your* job | Up-front schema design and tooling |

### Row-oriented versus columnar

| | Row (JSON objects, Protocol Buffers messages, Avro records) | Columnar (Parquet, ORC, Arrow tables) |
|--|-----------------------------------------------------|----------------------------------------|
| **Strength** | Natural for whole records (APIs, RPC, online transaction-style access) | Scan a few columns over huge tables with far less input/output |
| **Cost** | Poor for wide analytical queries | Wrong default when you mostly “fetch one document by id” |

### Self-describing versus schema-dependent

- **Self-describing (to varying degrees):** field names or type tags travel with the data (JSON, MessagePack, CBOR). Easier to inspect; more metadata on the wire.
- **Schema-dependent:** the wire data is nearly meaningless without a shared schema (classic Protocol Buffers, raw Avro). Smaller and faster when both ends already agree on the contract.

### Portable versus language-native

- **Portable:** designed for multi-language interchange (JSON, Protocol Buffers, MessagePack, and similar).
- **Language-native:** tied to one runtime (`pickle`, Java serialization, and similar). Convenient inside a tight trust boundary; dangerous or unusable across languages and on untrusted inputs.

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
- Performance claims in prose are **illustrative**. Prefer suite **Results** for numbers on *this* harness and hardware.
- “Best format” always means **best under your constraints** (team, trust boundary, retention, latency budget, multi-language needs).
