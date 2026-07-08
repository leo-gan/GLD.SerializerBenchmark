# Serialization 101

A starting point for **anyone** who wants to understand data serialization—students, data scientists, backend engineers, and systems architects. You do not need prior expertise. By the end of this theory track you should be able to:

1. Explain what serialization is and why it exists.
2. Read a format’s history as a response to real constraints (not a list of brand names).
3. Choose a format *for a workload* using the right lens (data work vs services).
4. Connect concepts to **measured** libraries in this multi-language benchmark suite.

Theory alone does not decide production choices. Use this course to build vocabulary and judgment, then validate with [Benchmarks](../analysis/index.md) and language **Results**.

---

## What is serialization?

**Serialization** turns an in-memory data structure (objects, records, graphs) into a **linear sequence of bytes** that can be stored, cached, or sent across a network. **Deserialization** rebuilds a usable structure from those bytes—often in another process, machine, or language.

Memory is a web of pointers and types. The wire and the disk only understand bytes. Every format is a **contract** between a writer and a reader about how that collapse and rebuild work.

---

## Three lenses

The same formats appear under three perspectives on purpose. Each document answers a different question:

| Lens | Primary question | Best if you care about… |
|------|------------------|-------------------------|
| **[Historical](historical_perspective.md)** | *Why do these formats exist?* | Eras, people, constraints, paradigm shifts |
| **[Data science](data_science_perspective.md)** | *What should I use for data & ML work?* | Lakes, pipelines, notebooks, models, columnar I/O |
| **[Engineering](engineer_perspective.md)** | *What should I ship in services & systems?* | APIs, RPC, performance, security, evolution |

**Suggested order for a first pass**

1. Skim the **shared trade-offs** below (10 minutes).
2. Read the **[historical perspective](historical_perspective.md)** once (big picture).
3. Deep-dive the lens that matches your work (**[data science](data_science_perspective.md)** or **[engineering](engineer_perspective.md)**).
4. Open [Serialization categories](../analysis/serialization_categories.md) and a language **Overview** / **Results** page for libraries you might actually use.
5. When you need *mechanisms*, work the **[Serialization 201](deep-dives/index.md)** track:
    1. [Memory layout](deep-dives/memory-layout.md)
    2. [Encode/decode cost](deep-dives/encode-decode-cost.md)
    3. [Self-describing vs schema](deep-dives/self-describing-vs-schema-dependent.md)
    4. [Schema evolution](deep-dives/schema-evolution.md)
    5. [Dynamic vs IDL binary](deep-dives/dynamic-vs-idl-binary.md)
    6. [Zero-copy](deep-dives/zero-copy.md)
    7. [Compression vs format](deep-dives/compression-is-not-a-format.md)

You can reverse steps 2 and 3 if you already have a concrete problem (“I need Parquet for analytics” or “I need an internal RPC format”). Jump to a single 201 article when you already know the question.

When mechanisms are solid and you need **production multi-constraint judgment**, continue to [Serialization 301](301/index.md).

---

## Core trade-offs

These axes appear in every lens. Learn the *names*; details live in the perspective docs.

### Text vs binary

| | Text (JSON, XML, YAML, …) | Binary (MessagePack, Protobuf, Parquet, …) |
|--|---------------------------|-----------------------------------------------|
| **Strength** | Human-readable; easy to debug and log | Compact; often much faster to encode/decode |
| **Cost** | Larger payloads; string parsing | Opaque without tools; harder ad-hoc inspection |

### Schema vs schemaless

| | Schemaless (JSON, MessagePack, …) | Schema-driven (Protobuf, Avro, FlatBuffers, …) |
|--|-----------------------------------|--------------------------------------------------|
| **Strength** | Flexible; ship data without an IDL step | Compact wire form; codegen; clearer evolution rules |
| **Cost** | Validation and compatibility are *your* job | Up-front schema design and tooling |

### Row-oriented vs columnar

| | Row (JSON objects, Protobuf messages, Avro records) | Columnar (Parquet, ORC, Arrow tables) |
|--|-----------------------------------------------------|----------------------------------------|
| **Strength** | Natural for whole records (APIs, RPC, OLTP-style access) | Scan few columns over huge tables with far less I/O |
| **Cost** | Poor for wide analytical queries | Wrong default for “fetch one document by id” |

### Self-describing vs schema-dependent

- **Self-describing-ish:** field names or type tags travel with the data (JSON, MessagePack, CBOR). Easier to inspect; more metadata on the wire.
- **Schema-dependent:** wire data is nearly meaningless without a shared schema (classic Protobuf, raw Avro). Smaller and faster when both ends agree.

### Portable vs language-native

- **Portable:** designed for multi-language interchange (JSON, Protobuf, MessagePack, …).
- **Language-native:** tied to one runtime (`pickle`, Java serialization, …). Convenient inside a trust boundary; dangerous or unusable across languages and untrusted inputs.

---

## Scope and honesty

- This theory track is a **map**, not an encyclopedia of every library.
- Performance claims in prose are **illustrative**. Prefer suite **Results** for numbers on *this* harness and hardware.
- “Best format” always means **best under your constraints** (team, trust boundary, retention, latency budget, polyglot needs).
