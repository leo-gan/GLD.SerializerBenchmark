# Serialization 401: Implementing Contemporary Serializers

> This course walks through Protocol Buffers binary encoding on the wire, then follows how Python, Rust, and C runtimes turn those bytes into language values. A small subset lab ties the theory to code you write yourself. It is aimed at people who build or deeply integrate codecs—not only people who choose formats from a menu.

## Who this is for

You should take this elective if you need to **implement, debug, or deeply integrate** serializers. It sits after [Serialization 201](../201/index.md) and is deliberately more hands-on than the production-judgment track. It does **not** replace [Serialization 301](../301/index.md): 301 is about multi-constraint product choices under real pressure; 401 is about wire rules and runtime paths.

You do not need to have written a codec from scratch already. You do need intermediate reading comfort in at least one of Python, Rust, or C, and a working memory of schema-dependent binary ideas from 201.

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [101](../101/index.md) and [201](../201/index.md) (schema identity, encode cost, evolution, dynamic vs IDL binary) |
| **Soft** | [301](../301/index.md) is recommended (trust boundaries, polyglot estates, honest measurement) |
| **Skills** | Intermediate reading level in at least one of Python, Rust, or C |

## Learning outcomes

By the end of this course you should be able to:

1. **Encode and decode** core Protocol Buffers wire structures on paper and with tables: tags (keys that name a field), varints (variable-length integers), length-delimited fields, nested messages, simple repeated fields, and skipping unknown fields.  
2. **Trace** encode and decode paths in Python (`google.protobuf`), Rust (`prost`), and C (`protobuf-c`), including **buffer ownership** (who allocates the bytes, who frees them, and how long a buffer must stay valid).  
3. **Contrast** the classic C runtime (protobuf-c) with the embedded-oriented design of **nanopb** (a C library that prefers static size budgets over free-form heap trees).  
4. **Build** a mini subset encoder/decoder and **validate** it against golden byte sequences and at least one official parser.  
5. **State** deliberate omissions honestly—this lab is a teaching subset, not a full production Protocol Buffers implementation.

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../101/index.md) | Foundations |
| [201](../201/index.md) | Mechanisms |
| [301](../301/index.md) | Production judgment (core advanced track) |
| **401 (this course)** | Implementer elective — wire format, language paths, and a thin subset lab |

This course teaches **wire encoding, runtime paths, and a thin subset lab**. It is not a full reimplementation of Protocol Buffers, and it is not a multi-constraint product-choice guide (that is 301).

## Modules

| Article | You should be able to… |
|---------|------------------------|
| [Protobuf wire format step-by-step](protobuf-wire-format.md) | Read and emit tags, varints, length-delimited (LEN) fields, nested messages, unpacked and packed repeated fields; skip unknowns safely |
| [Lab: mini encoder/decoder](lab-mini-protobuf-encoder.md) | Build a MiniUser subset codec; pass goldens G1–G5, bounds tests, and an official-parser check |
| [Python: google.protobuf path](protobuf-python.md) | Trace codegen → backend → `SerializeToString` / `ParseFromString` and who owns the bytes |
| [Rust: prost path](protobuf-rust-prost.md) | Trace `encoded_len` / `encode_raw` / `merge_field` and monomorphized (per-type specialized) codegen |
| [C: protobuf-c path](protobuf-c-protobuf-c.md) | Trace descriptor-driven pack/unpack and heap free discipline |
| [C: nanopb vs protobuf-c](protobuf-c-nanopb-compare.md) | Choose a heap-friendly C engine versus a static-budget C engine for a deployment |
| [Same bytes, three runtimes](protobuf-cross-language-fidelity.md) | Design interop matrix tests; separate bit-identical encodings from logical fidelity |

**Suggested path** (this matches the self-check below; the side navigation lists the same pages):

1. [Wire format](protobuf-wire-format.md)  
2. [Lab](lab-mini-protobuf-encoder.md) *(start as soon as the wire article is readable)*  
3. [Python](protobuf-python.md) → [Rust](protobuf-rust-prost.md) → [C protobuf-c](protobuf-c-protobuf-c.md)  
4. [nanopb compare](protobuf-c-nanopb-compare.md)  
5. [Cross-language fidelity](protobuf-cross-language-fidelity.md)  

The flagship schema in this benchmark suite is `schemas/v2/protobuf/benchmark_v2.proto`. Teaching pages intentionally use a much smaller message called **MiniUser**. MiniUser is not the suite schema; it exists so you can study hex dumps without drowning in fields.

## Lab notebooks (Python / Colab)

| Notebook | Use with |
|----------|----------|
| [Wire format playground](../notebooks/401/wire_format_playground.ipynb) | [Wire format](protobuf-wire-format.md) |
| [MiniUser encoder lab](../notebooks/401/lab_mini_protobuf_encoder.ipynb) | [Lab article](lab-mini-protobuf-encoder.md) |

Index and install notes live in the [notebooks README](../notebooks/README.md).  
If you want the same golden hex sequences G1–G5 in another language, see the multi-language homework companions: [companions/go](../notebooks/companions/go/) · [companions/rust](../notebooks/companions/rust/).

## Three engines at a glance

The **wire format** (the layout of tags and payloads on the byte stream) is shared. The **codec engineering**—how each library walks the schema, allocates buffers, and reports errors—differs a lot:

| | **Python** (`google.protobuf`) | **Rust** (`prost`) | **C** (`protobuf-c`) | **C** (nanopb) |
|--|--------------------------------|--------------------|----------------------|----------------|
| Schema at encode time | Runtime descriptors plus a backend (upb or pure Python) | Monomorphized per-type code (specialized at compile time for each message type) | Runtime descriptor tables | Field list plus static maximum sizes |
| Output ownership | New immutable `bytes` object | Caller-owned `Vec<u8>` | Caller-allocated buffer | Static buffer or stream budget |
| Decode ownership | Garbage-collected Message object | Owned Rust struct | Heap message that you must free with `free_unpacked` | Preallocated static struct |
| Typical failure | Parse error raised as a Python exception | `DecodeError` | `NULL` return, or a leak if you skip free | Encode/decode fails when data exceeds a configured max |

Details appear in the language-path articles and in [nanopb compare](protobuf-c-nanopb-compare.md).

## Honesty rules

The program-wide rules still apply: there are no universal winners; implementation quality beats brand name; suite **Results** pages own measured numbers.  
**401-specific honesty:**

1. **Wire truth is shared; runtimes differ.** Python, Rust, and C can all speak the same binary layout and still own buffers differently.  
2. **The subset lab labels its omissions.** Packed repeated fields, zigzag signed integers, maps, oneofs, and full production hardening are out of scope on purpose.  
3. **Suite harnesses illustrate integration.** They are not the reference design for how you should structure production Protocol Buffers.  
4. **Results are optional cost context.** Speed tables are not the focus of this course.  
5. **Hostile input is a 301 topic.** For operational controls on untrusted payloads, see [301 untrusted input](../301/untrusted-input.md). Codec-side bounds (truncated varints, overlong lengths) still belong in every decoder.  
6. **Language tours are parallel, not ranked.** This course does not crown “Rust wins.”

## Assessment (self-check)

1. Complete the lab golden vectors **G1–G5** (including the empty G2), unknown-field skip, bounds failures, and at least one official-parser cross-check.  
2. Explain pack/unpack **ownership** in one of Python, Rust, or C: who allocates, who frees, and what must stay valid during the call.  
3. State when **nanopb** is preferable to **protobuf-c**, and when the reverse is true—see [nanopb compare](protobuf-c-nanopb-compare.md).  
4. Design a three-language encode/decode **matrix test** and say when bit-identity (`memcmp` of encodings) is required versus when logical equality is enough—see [cross-language fidelity](protobuf-cross-language-fidelity.md).

## Where to go next

- [Serialization 201](../201/index.md) if schema-dependent concepts feel rusty.  
- [Serialization 301](../301/index.md) for multi-constraint product choices.  
- Shared suite schema in this repository: `schemas/v2/protobuf/benchmark_v2.proto`.
