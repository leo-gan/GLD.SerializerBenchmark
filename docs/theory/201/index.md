# Serialization 201

In this track you will learn **how serialization mechanisms work**—not only what the formats are called, but why they behave differently. These short essays sit between [Serialization 101](../101/index.md) and its three lenses on one side, and the later courses on the other: **301** for production judgment and **401** for people who implement codecs. When you care about measured numbers, you will also want the suite [categories](../../analysis/serialization_categories.md) page and the language **Results** pages.

Theory alone does not decide what you should ship. Use these pages to build clear mental models of the mechanisms, then check those models against real libraries. When you must choose under several production constraints at once, continue into the advanced courses as they become available.

---

## How to use this track

1. Skim [Serialization 101](../101/index.md) so the basic definitions and trade-off axes feel familiar.
2. Optionally read one lens that matches your work: [Historical](../101/historical_perspective.md), [Data science](../101/data_science_perspective.md), or [Engineering](../101/engineer_perspective.md).
3. Work through the articles below when you need a clearer *how* or *why* for a mechanism.
4. Open [Serialization categories](../../analysis/serialization_categories.md) and a language **Results** page for numbers measured on *this* benchmark runner.

**Honesty rules (same as Serialization 101).** There are no universal winners. Implementation quality often matters more than the brand name of a format. The shape of the payload—whether data is flat, nested, sparse, or dense—can change costs a great deal. Compare within one paradigm and one language when you can. Numbers that appear in prose are only illustrations; the suite **Results** pages own the truth for this benchmark runner.

---

## Suggested order (MVP path)

The table below gives a suggested order for a first pass through Serialization 201. Each row states what you should be able to explain after reading that article.

| Step | Article | You should be able to… |
|------|---------|------------------------|
| 1 | [Memory layout](memory-layout.md) | Explain why dumping raw process memory is not a portable interchange format |
| 2 | [Encode/decode cost](encode-decode-cost.md) | Name the real cost centers (parsing structure, converting numbers, allocating, copying)—instead of saying only that “JSON is slow” |
| 3 | [Self-describing vs schema](self-describing-vs-schema-dependent.md) | Say whether field identity lives in the payload itself or in a shared contract outside the message |
| 4 | [Schema evolution](schema-evolution.md) | Plan additive changes that keep older readers and writers working during a rollout |
| 5 | [Dynamic vs IDL binary](dynamic-vs-idl-binary.md) | Choose a MessagePack/CBOR-class encoding versus a Protocol Buffers–class encoding for a given workload (IDL = interface description language, a formal shared description of messages and field types) |
| 6 | [Zero-copy](zero-copy.md) | Explain what “no deserialize” usually means in marketing language—and what that design still costs |
| 7 | [Compression vs format](compression-is-not-a-format.md) | Separate gzip-style compression on the wire from density that comes from the format itself |

---

## By module

### Representation

These articles explain how values become bytes, and where the time and memory go when you encode or decode them.

- [Memory layout](memory-layout.md)
- [Encode/decode cost](encode-decode-cost.md)

### Contracts & change

These articles explain where the meaning of a field lives, and how systems stay compatible when that meaning changes over time.

- [Self-describing vs schema](self-describing-vs-schema-dependent.md)
- [Schema evolution](schema-evolution.md)

### Families in practice

These articles compare common binary families and specialized layout designs you will meet in real systems.

- [Dynamic vs IDL binary](dynamic-vs-idl-binary.md)
- [Zero-copy](zero-copy.md)

### Systems concerns

This article separates two mechanisms that people often conflate when they talk about “small payloads.”

- [Compression vs format](compression-is-not-a-format.md)

---

## Lab notebooks (Python / Colab)

Several articles have an accompanying notebook you can run locally or in Colab. The notebooks let you experiment with the same ideas in code.

| Notebook | Article |
|----------|---------|
| [Encode/decode cost](../notebooks/201/encode_decode_cost.ipynb) | [Encode/decode cost](encode-decode-cost.md) |
| [Self-describing vs schema](../notebooks/201/self_describing_vs_schema.ipynb) | [Self-describing vs schema](self-describing-vs-schema-dependent.md) |
| [Schema evolution](../notebooks/201/schema_evolution.ipynb) | [Schema evolution](schema-evolution.md) |
| [Dynamic vs IDL binary](../notebooks/201/dynamic_vs_idl_binary.ipynb) | [Dynamic vs IDL binary](dynamic-vs-idl-binary.md) |
| [Compression vs format](../notebooks/201/compression_vs_format.ipynb) | [Compression vs format](compression-is-not-a-format.md) |

Install notes live in the [notebooks README](../notebooks/README.md).

## Where to go next

- **Core path:** [Serialization 301](../301/index.md) — production judgment when several constraints pull at once.
- **Implementer elective:** [Serialization 401](../401/index.md) — wire formats, language-specific paths, and a hands-on lab.
- Related reference pages: [Serialization categories](../../analysis/serialization_categories.md), [Engineering](../101/engineer_perspective.md), [Data science](../101/data_science_perspective.md), and [Benchmarks](../../analysis/index.md).
