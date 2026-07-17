# Serialization 401: Implementing Contemporary Serializers

> Protobuf wire encoding and language runtime paths (Python, Rust, C), plus a thin subset lab—for serializer developers and deep integrators.

## Who this is for

People who **build or deeply integrate** codecs—not only choose formats. This is a **senior elective** after [Serialization 201](../201/index.md). It does **not** replace [Serialization 301](../301/index.md) (production judgment).

## Prerequisites

| Type | Requirement |
|------|-------------|
| **Hard** | [101](../101/index.md) + [201](../201/index.md) (schema identity, encode cost, evolution, dynamic vs IDL) |
| **Soft** | [301](../301/index.md) recommended (trust, polyglot, honest measurement) |
| **Skills** | Intermediate reading level in at least one of Python, Rust, C |

## Learning outcomes

By the end of this course you should be able to:

1. **Encode and decode** (on paper / with tables) core Protobuf wire structures: tags, varints, length-delimited, nested, simple repeated, skip unknowns.  
2. **Trace** encode/decode paths in Python (`google.protobuf`), Rust (`prost`), and C (`protobuf-c`), including buffer ownership.  
3. **Contrast** classic C runtime (protobuf-c) vs embedded nanopb design axes.  
4. **Construct** a mini subset codec and **validate** against golden bytes or an official parser.  
5. **State** deliberate omissions (subset honesty).

## How this course fits the program

| Course | Role |
|--------|------|
| [101](../101/index.md) | Foundations |
| [201](../201/index.md) | Mechanisms |
| [301](../301/index.md) | Production judgment (core advanced) |
| **401 (this course)** | Implementer elective — wire + paths + lab |

This course teaches **wire encoding, runtime paths, and a thin subset lab**—not a full Protobuf reimplementation, not multi-constraint product choice (that is 301).

## Modules

| Article | You should be able to… |
|---------|------------------------|
| [Protobuf wire format step-by-step](protobuf-wire-format.md) | Read/emit tags, varints, LEN, nested, unpacked/packed repeated; skip unknowns |
| [Lab: mini encoder/decoder](lab-mini-protobuf-encoder.md) | Build a MiniUser subset codec; pass goldens + bounds + official parse |
| [Python: google.protobuf path](protobuf-python.md) | Trace codegen → backend → SerializeToString / ParseFromString and ownership |
| [Rust: prost path](protobuf-rust-prost.md) | Trace `encoded_len` / `encode_raw` / `merge_field` and monomorphized codegen |
| [C: protobuf-c path](protobuf-c-protobuf-c.md) | Trace descriptor pack/unpack and heap free discipline |
| [C: nanopb vs protobuf-c](protobuf-c-nanopb-compare.md) | Choose heap-friendly vs static-budget C engines for a deployment |
| [Same bytes, three runtimes](protobuf-cross-language-fidelity.md) | Design interop matrix tests; separate bit-identity from logical fidelity |

**Suggested path** (matches self-check; side nav lists the same pages):

1. [Wire format](protobuf-wire-format.md)  
2. [Lab](lab-mini-protobuf-encoder.md) *(start as soon as wire is readable)*  
3. [Python](protobuf-python.md) → [Rust](protobuf-rust-prost.md) → [C protobuf-c](protobuf-c-protobuf-c.md)  
4. [nanopb compare](protobuf-c-nanopb-compare.md)  
5. [Cross-language fidelity](protobuf-cross-language-fidelity.md)  

Flagship schema in the suite: `schemas/v2/protobuf/benchmark_v2.proto`. Teaching pages use a smaller **MiniUser** message (not the suite schema).

## Lab notebooks (Python / Colab)

| Notebook | Use with |
|----------|----------|
| [Wire format playground](../notebooks/401/wire_format_playground.ipynb) | [Wire format](protobuf-wire-format.md) |
| [MiniUser encoder lab](../notebooks/401/lab_mini_protobuf_encoder.ipynb) | [Lab article](lab-mini-protobuf-encoder.md) |

Index and install notes: [notebooks README](../notebooks/README.md).

## Three engines at a glance

Same wire format; different engineering of the codec:

| | **Python** (`google.protobuf`) | **Rust** (`prost`) | **C** (`protobuf-c`) | **C** (nanopb) |
|--|--------------------------------|--------------------|----------------------|----------------|
| Schema at encode time | Runtime descriptors + backend (upb / pure Python) | Monomorphized per-type code | Runtime descriptor tables | Field list + static max sizes |
| Output ownership | New immutable `bytes` | Caller-owned `Vec<u8>` | Caller-allocated buffer | Static / stream budget |
| Decode ownership | GC-managed Message | Owned Rust struct | Heap message → `free_unpacked` | Preallocated static struct |
| Typical failure | Parse error / Python exception | `DecodeError` | `NULL` / leak if free skipped | Fail if data exceeds max |

Details: language path articles and [nanopb compare](protobuf-c-nanopb-compare.md).

## Honesty rules

Program rules (no universal winners; implementation beats brand; suite Results own numbers).  
**401-specific:**

1. Wire truth is shared; runtimes differ.  
2. Subset lab labels omissions.  
3. Suite harnesses illustrate integration—they are not the reference design for Protobuf.  
4. Results are optional cost context—not the focus of this course.  
5. Hostile input: [301 untrusted input](../301/untrusted-input.md).  
6. Parallel language tours—not “Rust wins.”

## Assessment (self-check)

1. Complete the lab golden vectors G1–G5 (and G2 empty), unknown-field skip, bounds failures, and at least one official-parser cross-check.  
2. Explain pack/unpack ownership in one of Python, Rust, or C.  
3. State when nanopb is preferable to protobuf-c (and the reverse)—see [nanopb compare](protobuf-c-nanopb-compare.md).  
4. Design a 3-language encode/decode matrix test and say when `memcmp` of encodings is required—see [cross-language fidelity](protobuf-cross-language-fidelity.md).

## Where to go next

- [Serialization 201](../201/index.md) if schema-dependent concepts are rusty.  
- [Serialization 301](../301/index.md) for multi-constraint product choices.  
- Shared schema: repository `schemas/v2/protobuf/benchmark_v2.proto`.
