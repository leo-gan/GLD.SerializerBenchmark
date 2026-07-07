# Deep dives

Short, problem-driven essays on **how serialization mechanisms work** and **how to choose under constraints**. They sit between the [101 home](../index.md) / three lenses and the suite [categories](../../analysis/serialization_categories.md) + language **Results**.

Theory alone does not decide production choices. Use these pages to build mechanism-level judgment, then validate with measured libraries.

---

## How to use this track

1. Skim [Serialization 101](../index.md) (definitions and trade-off axes).
2. Optionally read one lens: [Historical](../historical_perspective.md), [Data science](../data_science_perspective.md), or [Engineering](../engineer_perspective.md).
3. Work the deep dives below when you need *how* or *why*.
4. Open [Serialization categories](../../analysis/serialization_categories.md) and a language **Results** page for numbers on *this* harness.

**Honesty rules (same as the rest of 101):** no universal winners; implementation beats brand name; payload shape matters; compare within paradigm and language; prose numbers are illustrative—**Results** own suite truth.

---

## Suggested order (MVP path)

| Step | Article | You should be able to… |
|------|---------|------------------------|
| 1 | [Memory layout](memory-layout.md) | Explain why a raw memory dump is not a portable format |
| 2 | [Encode/decode cost](encode-decode-cost.md) | Name the real cost centers (parse, numbers, alloc, copy)—not an unqualified claim that JSON is slow |
| 3 | [Self-describing vs schema](self-describing-vs-schema-dependent.md) | Say who carries field identity: payload or shared contract |
| 4 | [Schema evolution](schema-evolution.md) | Plan additive change without breaking old readers/writers |
| 5 | [Dynamic vs IDL binary](dynamic-vs-idl-binary.md) | Choose MessagePack/CBOR-class vs Protobuf-class for a workload |
| 6 | [Zero-copy](zero-copy.md) | Explain what “no deserialize” means—and what it still costs |
| 7 | [Compression vs format](compression-is-not-a-format.md) | Separate gzip-on-the-wire from format-aware density |

---

## By module

### Representation

- [Memory layout](memory-layout.md)
- [Encode/decode cost](encode-decode-cost.md)

### Contracts & change

- [Self-describing vs schema](self-describing-vs-schema-dependent.md)
- [Schema evolution](schema-evolution.md)

### Families in practice

- [Dynamic vs IDL binary](dynamic-vs-idl-binary.md)
- [Zero-copy](zero-copy.md)

### Systems concerns

- [Compression vs format](compression-is-not-a-format.md)

---

## After the dives

| Next | Link |
|------|------|
| Suite families & decision sketch | [Serialization categories](../../analysis/serialization_categories.md) |
| Services lens | [Engineering perspective](../engineer_perspective.md) |
| Data & ML lens | [Data science perspective](../data_science_perspective.md) |
| Methodology & results hub | [Benchmarks](../../analysis/index.md) |
