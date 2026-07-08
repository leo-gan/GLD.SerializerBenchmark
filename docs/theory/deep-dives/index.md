# Serialization 201

Short, problem-driven essays on **how serialization mechanisms work**. They sit between the [101 home](../index.md) / three lenses and later courses (**301** production judgment, **401** implementers) plus suite [categories](../../analysis/serialization_categories.md) + language **Results**.

Theory alone does not decide production choices. Use these pages to build mechanism-level models, then validate with measured libraries and—when choosing under multi-constraint production pressure—continue to advanced courses as they ship.

---

## How to use this track

1. Skim [Serialization 101](../index.md) (definitions and trade-off axes).
2. Optionally read one lens: [Historical](../historical_perspective.md), [Data science](../data_science_perspective.md), or [Engineering](../engineer_perspective.md).
3. Work the articles below when you need *how* or *why*.
4. Open [Serialization categories](../../analysis/serialization_categories.md) and a language **Results** page for numbers on *this* harness.

**Honesty rules (same as Serialization 101):** no universal winners; implementation beats brand name; payload shape matters; compare within paradigm and language; prose numbers are illustrative—**Results** own suite truth.

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

## After Serialization 201

| Next | Link |
|------|------|
| Production judgment (core next, when published) | Serialization **301** — choose under constraints |
| Implement codecs (senior elective, when published) | Serialization **401** — wire + language paths + lab |
| Suite families & decision sketch | [Serialization categories](../../analysis/serialization_categories.md) |
| Services lens | [Engineering perspective](../engineer_perspective.md) |
| Data & ML lens | [Data science perspective](../data_science_perspective.md) |
| Methodology & results hub | [Benchmarks](../../analysis/index.md) |
